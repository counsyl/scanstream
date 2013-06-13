//
//  SSScanManager.m
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 6/11/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
//

#import "SSScanManager.h"
#import <Quartz/Quartz.h>


NSString *const SSScanManagerErrorDomain = @"SSScanManagerErrorDomain";


@interface SSScanManager () <ICScannerDeviceDelegate>
@property (weak) ICScannerFunctionalUnitDocumentFeeder *documentFeeder;
@property BOOL readyToScan;
@property BOOL scanInProgress;
@end


@implementation SSScanManager {
    SSScanManagerCallback _callbackBlock;
    NSMutableArray *_scannedURLs;
    ICScannerFunctionalUnit *_functionalUnit;
}

- (void)scan:(SSScanManagerCallback)callback
{
    if (_scanInProgress) {
        callback(NO,
                 [NSError errorWithDomain:SSScanManagerErrorDomain
                                     code:0
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Scan already in progress." }],
                 nil);
        return;
    }
    if (!_scanner) {
        callback(NO,
                 [NSError errorWithDomain:SSScanManagerErrorDomain
                                     code:0
                                 userInfo:@{ NSLocalizedDescriptionKey: @"No scanner configured." }],
                 nil);
        return;
    }
    if (!_readyToScan) {
        callback(NO,
                 [NSError errorWithDomain:SSScanManagerErrorDomain
                                     code:0
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Scanner is not ready." }],
                 nil);
        return;
    }
    
    _callbackBlock = [callback copy];
    _scannedURLs = [NSMutableArray array];
    
    [_scanner requestScan];
    self.scanInProgress = YES;
}

- (void)scanSync:(SSScanManagerCallback)callback
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    [self scan:^(BOOL success, NSError *error, NSArray *scannedURLs) {
        callback(success, error, scannedURLs);
        dispatch_semaphore_signal(sem);
    }];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)scannerDevice:(ICScannerDevice *)scanner didScanToURL:(NSURL *)url
{
    SSLog(@"Scanned page to %@", url);
    [_scannedURLs addObject:url];
}

- (void)scannerDevice:(ICScannerDevice *)scanner didCompleteScanWithError:(NSError *)error
{
    SSLog(@"Scan complete! %@", error);
    
    self.scanInProgress = NO;
    
    if (error) {
        _callbackBlock(NO, error, nil);
    }
    else {
        _callbackBlock(YES, nil, _scannedURLs);
    }
    
    _callbackBlock = nil;
    _scannedURLs = nil;
}

- (void)setScanner:(ICScannerDevice *)scanner
{
    // Deactivate previous scanner
    _scanner.delegate = nil;
    [_scanner cancelScan];
    [_scanner requestCloseSession];
    
    self.readyToScan = NO;
    self.scanInProgress = NO;
    
    _scanner = scanner;
    _scanner.transferMode = ICScannerTransferModeFileBased;
    _scanner.documentUTI = (__bridge NSString *)kUTTypeJPEG;
//    _scanner.downloadsDirectory = [self _tempDownloadDirectory];
    _scanner.delegate = self;
    [_scanner requestOpenSession];
}


#pragma mark
#pragma mark Device delegate methods

- (void)scannerDeviceDidBecomeAvailable:(ICScannerDevice *)scanner
{
    SSLog(@"Device became available");
    
    if (!_scanner.hasOpenSession) {
        // Probably some other application was using the scanner.
        [_scanner requestOpenSession];
    }
}

- (void)device:(ICDevice *)device didOpenSessionWithError:(NSError *)error
{
    if (error) {
        // Probably some other application is using the scanner.
        SSLog(@"Error opening session: %@", error);
        return;
    }
    
    SSLog(@"Opened session, requesting flatbed");
    
    [_scanner requestSelectFunctionalUnit:ICScannerFunctionalUnitTypeFlatbed];
}

-   (void)scannerDevice:(ICScannerDevice *)scanner
didSelectFunctionalUnit:(ICScannerFunctionalUnit *)functionalUnit
                  error:(NSError *)error
{
    SSLog(@"Selected functional unit: %@", functionalUnit);
    
    _functionalUnit = functionalUnit;
    
    if (!_functionalUnit) {
        return;
    }
    
    // It seems errors are produced when calling -requestSelectFunctionalUnit: no matter what.
//    if (error) {
//        SSLog(@"Error selecting functional unit: %@", error);
//        return;
//    }
    
    if (functionalUnit.type == ICScannerFunctionalUnitTypeDocumentFeeder
        && [functionalUnit isKindOfClass:[ICScannerFunctionalUnitDocumentFeeder class]]) {
        // Publish the document feeder.
        self.documentFeeder = (ICScannerFunctionalUnitDocumentFeeder *)functionalUnit;
        
        if (_documentFeeder.supportsDuplexScanning)
            _documentFeeder.duplexScanningEnabled = YES;
        
        if ([_documentFeeder.supportedDocumentTypes containsIndex:ICScannerDocumentTypeUSLetter])
            _documentFeeder.documentType = ICScannerDocumentTypeUSLetter;
    }
    else {
        SSLog(@"Unexpected functional unit type! %@", functionalUnit);
    }
    
    _functionalUnit.pixelDataType = ICScannerPixelDataTypeRGB;
    _functionalUnit.bitDepth = [_functionalUnit.supportedBitDepths lastIndex];
//    _functionalUnit.
}

- (void)deviceDidBecomeReady:(ICDevice *)device
{
    SSLog(@"Ready to scan!");
    
    self.readyToScan = YES;
}


//- (void)device:(ICDevice *)device didReceiveCustomNotification:(NSDictionary *)notification data:(NSData *)data
//{
//    SSLog(@"Notification: %@ - %@", notification, data);
//}
//
//- (void)device:(ICDevice *)device didReceiveButtonPress:(NSString*)buttonType
//{
//    SSLog(@"Button pressed: %@", buttonType);
//}

- (void)didRemoveDevice:(ICDevice *)device
{
    SSLog(@"Device removed");
    
    self.scanner = nil;
}

- (void)device:(ICDevice *)device didEncounterError:(NSError*)error
{
    SSLog(@"Device encountered error: %@", error);
}

- (void)dealloc
{
    self.scanner = nil;
}

@end
