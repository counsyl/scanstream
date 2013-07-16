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
static NSString *const SSServerPortDefaultsKey = @"SSServerPort";
static NSString *const SSPreferredScanResolutionDefaultsKey = @"SSPreferredScanResolution";


@interface SSAppDelegate () <IKDeviceBrowserViewDelegate>
@end


@implementation SSAppDelegate {
    RoutingHTTPServer *_httpServer;
    NSMutableDictionary *_temporaryCodes;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_serverStatusText.cell setBackgroundStyle:NSBackgroundStyleRaised];
    [_scanStatusText.cell setBackgroundStyle:NSBackgroundStyleRaised];
    [_loginCheckbox.cell setBackgroundStyle:NSBackgroundStyleRaised];
    
    _window.title = [NSString stringWithFormat:@"%@ %@ (%@)",
                     _window.title,
                     [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                     [[NSBundle mainBundle] objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey]];
    
    [self _setupServer];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)_setupServer
{
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
        
        [self _respondTo:response withJSON:@{ @"ready": @(_scanManager.readyToScan) }];
    }];
    
    [_httpServer get:@"/scan" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self _allowForRequest:request response:response];
        
        SSLog(@"Got scan request: %@", request);
        
        if (!_scanManager.readyToScan) {
            response.statusCode = 503;
            [self _respondTo:response withJSON:@{ @"error": @"Scanner is not ready." }];
            return;
        }
        
        // Configure scanner options.
        dispatch_sync(dispatch_get_main_queue(), ^{
            _scanManager.scanner.documentUTI = (__bridge NSString *)kUTTypeJPEG;
            
            // Secretly, all functional units support -setDocumentType:.
            [(id)_scanManager.scanner.selectedFunctionalUnit setDocumentType:ICScannerDocumentTypeUSLetter];
            
            // Choose the lowest supported resolution equal to or greater than the preferred resolution,
            // or if there are none, the highest supported resolution.
            NSIndexSet *supportedResolutions = _scanManager.scanner.selectedFunctionalUnit.supportedResolutions;
            if ([supportedResolutions count] <= 0) {
                SSLog(@"No supported resolutions found.");
                return;
            }
            
            NSUInteger preferredResolution = ([[NSUserDefaults standardUserDefaults]
                                               integerForKey:SSPreferredScanResolutionDefaultsKey]
                                              ?: supportedResolutions.firstIndex);
            NSIndexSet *possibleResolutions = [supportedResolutions indexesPassingTest:^(NSUInteger idx, BOOL *stop) {
                return (BOOL)(idx >= preferredResolution);
            }];
            
            NSUInteger bestResolution = ([possibleResolutions count] > 0
                                         ? possibleResolutions.firstIndex
                                         : supportedResolutions.lastIndex);
            
            SSLog(@"Scanning with resolution %lu.", (unsigned long)bestResolution);
            _scanManager.scanner.selectedFunctionalUnit.resolution = bestResolution;
        });
        
        // Scan the documents.
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
        
        NSURL *fileURL = [_temporaryCodes objectForKey:code];
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
    _httpServer.port = [[NSUserDefaults standardUserDefaults] integerForKey:SSServerPortDefaultsKey] ?: 8080;
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
        return;
    }
    [response respondWithData:resData];
}

- (void)_allowForRequest:(RouteRequest *)request response:(RouteResponse *)response
{
    [response setHeader:@"Allow" value:@"GET,OPTIONS"];
    
    NSString *host = [[NSURL URLWithString:[request header:@"Origin"]] host];
    if (host && ([host isEqualToString:@"localhost"] ||
                 [host rangeOfString:@"(\\A|\\.)counsyl\\.com\\z"
                             options:NSRegularExpressionSearch].location != NSNotFound)) {
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
        [_temporaryCodes setObject:url forKey:code];
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
    va_list args;
    va_start(args, format);
    NSLogv(format, args);
    va_end(args);
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
        CFRelease(transform);
        return nil;
    }
    if (!SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFDataRef)inData, &error)) {
        SSLog(@"Error setting transform input: %@", error);
        CFRelease(transform);
        return nil;
    }
    NSData *outData = (__bridge_transfer NSData *)SecTransformExecute(transform, &error);
    CFRelease(transform);
    return [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding];
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
