//
//  SSAppDelegate.m
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 6/11/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
//

#import "SSAppDelegate.h"


@interface SSAppDelegate () <IKDeviceBrowserViewDelegate, ICScannerDeviceDelegate>
@end


@implementation SSAppDelegate {
    ICScannerDevice *_scanner;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_logTextView setString:@""];
    
    [_topSplitView setHoldingPriority:0.5*(NSLayoutPriorityDefaultLow + NSLayoutPriorityDragThatCannotResizeWindow)
                    forSubviewAtIndex:0];
}


#pragma mark
#pragma mark Browser view delegate methods

- (void)deviceBrowserView: (IKDeviceBrowserView *)deviceBrowserView selectionDidChange:(ICDevice *)device
{
    [self log:@"Browser selected device “%@”", device.name];
    
    [_scanner cancelScan];
    [_scanner requestCloseSession];
    
    // Configure the scanner for scanning
    _scanner = (ICScannerDevice *)device;
    _scanner.transferMode = ICScannerTransferModeFileBased;
    _scanner.documentUTI = (__bridge NSString *)kUTTypePDF;
//    _scanner.downloadsDirectory = [self _tempDownloadDirectory];
    _scanner.delegate = self;
    [_scanner requestOpenSession];
}


#pragma mark
#pragma mark Device delegate methods

- (void)didRemoveDevice:(ICDevice *)device
{
    [self log:@"Device removed!"];
}

- (void)device:(ICDevice*)device didEncounterError:(NSError*)error
{
    [self log:@"Device encountered error: %@", error];
}

- (void)device:(ICDevice *)device didOpenSessionWithError:(NSError *)error
{
    if (error) {
        [self log:@"Error opening session: %@", error];
        return;
    }
    
    [self log:@"Opened session."];
    [_scanner requestSelectFunctionalUnit:ICScannerFunctionalUnitTypeDocumentFeeder];
}

- (void)scannerDevice:(ICScannerDevice*)scanner didSelectFunctionalUnit:(ICScannerFunctionalUnit*)functionalUnit error:(NSError*)error
{
    [self log:@"Selected functional unit: %@", functionalUnit];
    if ([functionalUnit isKindOfClass:[ICScannerFunctionalUnitDocumentFeeder class]]) {
        ICScannerFunctionalUnitDocumentFeeder *feeder = (ICScannerFunctionalUnitDocumentFeeder *)functionalUnit;
//        feeder.bitDepth = 1;
        feeder.pixelDataType = ICScannerPixelDataTypeBW;
        feeder.duplexScanningEnabled = YES;
        [feeder addObserver:self
                 forKeyPath:@"scanProgressPercentDone"
                    options:NSKeyValueObservingOptionInitial
                    context:(__bridge_retained void *)feeder];
    }
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self log:@"Progress: %f", ((__bridge ICScannerFunctionalUnitDocumentFeeder *)context).scanProgressPercentDone];
}

- (IBAction)startScan:(id)sender
{
    [_scanner requestScan];
}

- (void)deviceDidBecomeReady:(ICDevice *)device
{
    [self log:@"Ready to scan!"];
    //    [(ICScannerDevice *)device requestSelectFunctionalUnit:ICScannerFunctionalUnitTypeDocumentFeeder];
}
- (void)device:(ICDevice *)device didReceiveCustomNotification:(NSDictionary *)notification data:(NSData *)data
{
    [self log:@"Notification: %@ - %@", notification, data];
}
- (void)device:(ICDevice *)device didReceiveButtonPress:(NSString*)buttonType
{
    [self log:@"Button pressed: %@", buttonType];
}
- (void)scannerDeviceDidBecomeAvailable:(ICScannerDevice*)scanner
{
    [self log:@"Scanner available"];
}

- (void)scannerDevice:(ICScannerDevice *)scanner didScanToURL:(NSURL*)url
{
    [self log:@"Scanned to %@", url];
    [[NSWorkspace sharedWorkspace] selectFile:[url path] inFileViewerRootedAtPath:nil];
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
