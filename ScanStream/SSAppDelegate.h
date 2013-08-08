//
//  SSAppDelegate.h
//  ScanStream
//
//  Copyright (c) 2013 Counsyl, Inc. Released under the MIT license.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>


@class SSScanManager;


@interface SSAppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate, NSTextViewDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet IKDeviceBrowserView *deviceBrowserView;
@property (weak) IBOutlet NSImageView *serverStatusImage;

@property (strong) IBOutlet SSScanManager *scanManager;
@property (weak) IBOutlet NSTextField *serverStatusText;
@property (weak) IBOutlet NSTextField *scanStatusText;
@property (weak) IBOutlet NSButton *loginCheckbox;

- (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (IBAction)restartServer:(id)sender;

@end
