//
//  SSAppDelegate.m
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 6/11/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
//

#import "SSAppDelegate.h"
#import "RoutingHTTPServer.h"
#import "SSScanManager.h"


#define TEMPORARY_CODE_LENGTH 32

enum {
    kDocumentTypeTagPDF = 0,
    kDocumentTypeTagJPEG = 1
};


@interface SSAppDelegate () <IKDeviceBrowserViewDelegate>
@end


@implementation SSAppDelegate {
    RoutingHTTPServer *_httpServer;
    NSMutableDictionary *_temporaryCodes;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_logTextView setString:@""];
    [_topSplitView setHoldingPriority:0.5*(NSLayoutPriorityDefaultLow + NSLayoutPriorityDragThatCannotResizeWindow)
                    forSubviewAtIndex:0];
    [_mainSplitView setHoldingPriority:0.5*(NSLayoutPriorityDefaultLow + NSLayoutPriorityDragThatCannotResizeWindow)
                     forSubviewAtIndex:0];
    
    // Set up the HTTP server.
    
    _httpServer = [RoutingHTTPServer new];
    
    _temporaryCodes = [NSMutableDictionary dictionary];
    
    [_httpServer handleMethod:@"options" withPath:@"*" block:^(RouteRequest *request, RouteResponse *response) {
        [self _allowForRequest:request response:response];
        
        SSLog(@"Got options request: %@", request);
    }];
    
    [_httpServer get:@"/ping" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self _allowForRequest:request response:response];
        
        SSLog(@"Got ping request: %@", request);
        
        [response respondWithString:@"pong"];
    }];
    
    [_httpServer get:@"/scan" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self _allowForRequest:request response:response];
        
        SSLog(@"Got scan request: %@", request);
        
        if (!_scanManager.readyToScan) {
            response.statusCode = 503;
            [response respondWithString:@"Scanner is not ready"];
            return;
        }
        
        // Scan the documents.
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            switch (_scanTypeControl.selectedTag) {
                case kDocumentTypeTagJPEG:
                    _scanManager.scanner.documentUTI = (__bridge NSString *)kUTTypeJPEG;
                    break;
                case kDocumentTypeTagPDF:
                default:
                    _scanManager.scanner.documentUTI = (__bridge NSString *)kUTTypePDF;
                    break;
            }
        });
        [_scanManager scanSync:^(BOOL success, NSError *error, NSArray *scannedURLs) {
            if (!success) {
                response.statusCode = 500;
                [self _respondTo:response withJSON:@{ @"error": error.localizedDescription }];
                return;
            }
            
            // Generate temporary URLs to fetch the files.
            NSArray *codes = [self _generateTemporaryCodesForFiles:scannedURLs];
            [self _respondTo:response withJSON:@{ @"files": codes }];
        }];
    }];
    
    [_httpServer get:@"/download/:code" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self _allowForRequest:request response:response];
        
        NSString *code = [request param:@"code"];
        SSLog(@"Got request for file %@", code);
        
        NSURL *fileURL = _temporaryCodes[code];
        if (!fileURL) {
            response.statusCode = 404;
            return;
        }
        
        // -respondWithFile: doesn't work because we want to delete the file immediately.
        NSError *error = nil;
        NSString *fileData = [self _base64StringWithContentsOfURL:fileURL];
        if (!fileData) {
            SSLog(@"Error getting file data: %@", error);
            response.statusCode = 404;
            return;
        }
        [self _respondTo:response withJSON:@{
            @"data": fileData,
            @"type": [self _MIMETypeForURL:fileURL] ?: @"application/octet-stream"
         }];
        
        // Delete the scanned file.
        [_temporaryCodes removeObjectForKey:code];
        if (![[NSFileManager defaultManager] removeItemAtURL:fileURL
                                                       error:&error]) {
            SSLog(@"Error deleting scanned file: %@", error);
        }
    }];
    
    [self restartServer:nil];
}

- (IBAction)restartServer:(id)sender
{
    NSError *error = nil;
    
    [_httpServer stop];
    _httpServer.port = strtoul([[_serverPortField stringValue] UTF8String], NULL, 10);//49152 + arc4random_uniform(65535 - 49152 + 1);
    if (_httpServer.port == 0) _httpServer.port = 8080;
    if ([_httpServer start:&error]) {
        [_serverStatusText setStringValue:@"Server running."];
        [_serverStatusImage setImage:[NSImage imageNamed:@"on"]];
    }
    else {
        SSLog(@"Error starting server: %@", error);
        [_serverStatusText setStringValue:error.localizedDescription ?: @"Error starting server."];
        [_serverStatusImage setImage:[NSImage imageNamed:@"off"]];
    }
}


#pragma mark
#pragma mark Split view delegate methods

-  (BOOL)splitView:(NSSplitView *)splitView
canCollapseSubview:(NSView *)subview
{
    return [_logTextView isDescendantOf:subview];
}
-              (BOOL)splitView:(NSSplitView *)splitView
         shouldCollapseSubview:(NSView *)subview
forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
    return [_logTextView isDescendantOf:subview];
}


#pragma mark
#pragma mark Browser view delegate methods

- (void)deviceBrowserView:(IKDeviceBrowserView *)deviceBrowserView selectionDidChange:(ICDevice *)device
{
    SSLog(@"Browser selected device “%@”", device.name);
    
    if (!device) return;
    
    if (!(device.type & ICDeviceTypeMaskScanner && [device isKindOfClass:[ICScannerDevice class]])) {
        SSLog(@"Unexpected device type! %@", device);
        return;
    }
    
    _scanManager.scanner = (ICScannerDevice *)device;
}


#pragma mark
#pragma mark Utility methods

- (void)_respondTo:(RouteResponse *)response withJSON:(id)object
{
    NSError *error = nil;
    NSData *resData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    if (!resData) {
        SSLog(@"JSON error: %@", error);
    }
    [response respondWithData:resData];
}

- (void)_allowForRequest:(RouteRequest *)request response:(RouteResponse *)response
{
    [response setHeader:@"Allow" value:@"GET,OPTIONS"];
    
    NSString *host = [[NSURL URLWithString:[request header:@"Origin"]] host];
    if ([host isEqualToString:@"localhost"] || [host rangeOfString:@"(\\A|\\.)counsyl\\.com\\z"
                                                           options:NSRegularExpressionSearch].location != NSNotFound) {
        [response setHeader:@"Access-Control-Allow-Origin"
                      value:[request header:@"Origin"]];
    }
    
    NSString *requestHeaders = [request header:@"Access-Control-Request-Headers"];
    if (requestHeaders) {
        [response setHeader:@"Access-Control-Allow-Headers"
                      value:requestHeaders];
    }
}

- (NSArray *)_generateTemporaryCodesForFiles:(NSArray *)fileURLs
{
    NSMutableArray *tempCodes = [NSMutableArray array];
    
    for (NSURL *url in fileURLs) {
        NSString *code = [self _generateCode];
        _temporaryCodes[code] = url;
        [tempCodes addObject:code];
    }
    
    return tempCodes;
}

- (NSString *)_generateCode
{
    static char alphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    char code[TEMPORARY_CODE_LENGTH+1] = {0};
    
    for (int i = 0; i < TEMPORARY_CODE_LENGTH; i++) {
        code[i] = alphabet[arc4random_uniform(sizeof(alphabet)-1)];
    }
    
    return [NSString stringWithUTF8String:code];
}

- (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
    static NSDateFormatter *formatter;
    static NSDictionary * _stampAttributes;
    static NSDictionary *_messageAttributes;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"[yyyy-MM-dd HH:mm:ss.SSS] ";
        formatter.formatterBehavior = NSDateFormatterBehavior10_4;
        
        _messageAttributes = @{ NSFontAttributeName : [NSFont userFixedPitchFontOfSize:0] };
        _stampAttributes   = @{ NSFontAttributeName :
                                    [[NSFontManager sharedFontManager] convertFont:[NSFont userFixedPitchFontOfSize:0]
                                                                       toHaveTrait:NSBoldFontMask]
                                };
    });
    
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *stamp = [formatter stringFromDate:[NSDate date]];
    
    [[_logTextView textStorage] appendAttributedString:
     [[NSAttributedString alloc] initWithString:stamp
                                     attributes:_stampAttributes]];
    
    [[_logTextView textStorage] appendAttributedString:
     [[NSAttributedString alloc] initWithString:[message stringByAppendingString:@"\n"]
                                     attributes:_messageAttributes]];
    
    [_logTextView scrollToEndOfDocument:self];
}

- (NSString *)_base64StringWithContentsOfURL:(NSURL *)url
{
    CFErrorRef error;
    SecTransformRef transform = SecEncodeTransformCreate(kSecBase64Encoding, &error);
    if (!transform) {
        SSLog(@"Error creating base64 transform: %@", error);
        return nil;
    }
    NSData *inData = [NSData dataWithContentsOfURL:url];
    if (!inData) {
        SSLog(@"Error reading data from URL %@", url);
        return nil;
    }
    if (!SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFDataRef)inData, &error)) {
        SSLog(@"Error setting transform input: %@", error);
        return nil;
    }
    NSData *outData = (__bridge_transfer NSData *)SecTransformExecute(transform, &error);
    return [NSString stringWithUTF8String:[outData bytes]];
}

- (NSString *)_MIMETypeForURL:(NSURL *)fileURL
{
    NSString *contentType = nil;
    NSString *__autoreleasing fileTypeIdentifier = nil;
    NSError *__autoreleasing error = nil;
    if ([fileURL getResourceValue:&fileTypeIdentifier
                           forKey:NSURLTypeIdentifierKey
                            error:&error]) {
        contentType = ((__bridge_transfer NSString *)
                       UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)fileTypeIdentifier,
                                                       kUTTagClassMIMEType));
    }
    else {
        NSLog(@"Error getting type of file at %@: %@", fileURL, error);
    }
    
    return contentType;
}


@end
