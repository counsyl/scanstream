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


@interface SSAppDelegate () <IKDeviceBrowserViewDelegate>
@end


@implementation SSAppDelegate {
    RoutingHTTPServer *_httpServer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_logTextView setString:@""];
    
    [_topSplitView setHoldingPriority:0.5*(NSLayoutPriorityDefaultLow + NSLayoutPriorityDragThatCannotResizeWindow)
                    forSubviewAtIndex:0];
    [_mainSplitView setHoldingPriority:0.5*(NSLayoutPriorityDefaultLow + NSLayoutPriorityDragThatCannotResizeWindow)
                     forSubviewAtIndex:0];
        
    _httpServer = [RoutingHTTPServer new];
    _httpServer.port = 8080;//49152 + arc4random_uniform(65535 - 49152 + 1);
    
    [_httpServer get:@"/scan"
           withBlock:^(RouteRequest *request, RouteResponse *response) {
               dispatch_async(dispatch_get_main_queue(), ^{
                   SSLog(@"Got request: %@", request);
               });
               
               NSString *host = [[NSURL URLWithString:[request header:@"Origin"]] host];
               if ([host isEqualToString:@"localhost"]) {
                   [response setHeader:@"Access-Control-Allow-Origin"
                                 value:[request header:@"Origin"]];
               }
               
               if (!_scanManager.readyToScan) {
                   response.statusCode = 503;
                   [response respondWithString:@"Scanner is not ready"];
                   return;
               }
               
               // Scan documents.
               [_scanManager scanSync:^(BOOL success, NSError *error, NSArray *scannedURLs) {
                   if (!success) {
                       response.statusCode = 500;
                       [response respondWithString:error.localizedDescription];
                       return;
                   }
                   
                   [response respondWithFile:[scannedURLs[0] path]];
                   
                   // Delete scanned files.
                   for (NSURL *fileURL in scannedURLs) {
                       NSError *error = nil;
                       if (![[NSFileManager defaultManager] removeItemAtURL:fileURL
                                                                      error:&error]) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                               SSLog(@"Error deleting scanned file: %@", error);
                           });
                       }
                   }
               }];
           }];
    
    NSError *__autoreleasing error = nil;
    if (![_httpServer start:&error]) {
        SSLog(@"Error starting server: %@", error);
    }
}

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


- (IBAction)startScan:(id)sender
{
    [_scanManager scan:^(BOOL success, NSError *error, NSArray *scannedURLs) {
        NSLog(@"Scanned: %d, %@, %@", success, error, scannedURLs);
    }];
}


#pragma mark
#pragma mark Utility methods

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


@end
