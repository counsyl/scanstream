//
//  SSScanManager.h
//  ScanStream
//
//  Copyright (c) 2013 Counsyl, Inc. Released under the MIT license.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>


extern NSString *const SSScanManagerErrorDomain;

// Scanned URLs are listed in the order they were scanned.
// (Probably. ICScannerDevice doesn't actually guarantee this.)
typedef void (^SSScanManagerCallback)(BOOL success, NSError *error, NSArray *scannedURLs);


@interface SSScanManager : NSObject

// The currently active scanner.
@property (strong, nonatomic) ICScannerDevice *scanner;

// The document feeder, or nil if the scanner does not support a document feeder.
@property (readonly) ICScannerFunctionalUnitDocumentFeeder *documentFeeder;

@property (readonly) BOOL readyToScan; // Whether the scanner is ready.
@property (readonly) BOOL scanInProgress; // Whether a scan is currently in progress.
- (void)scan:(SSScanManagerCallback)callback; // Asynchronous scan.
- (void)scanSync:(SSScanManagerCallback)callback; // Synchronous scan.

@end
