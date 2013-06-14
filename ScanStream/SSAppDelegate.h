//
//  SSAppDelegate.h
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 6/11/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>


@class SSScanManager;


@interface SSAppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate, NSTextViewDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet IKDeviceBrowserView *deviceBrowserView;
@property (unsafe_unretained) IBOutlet NSTextView *logTextView;
@property (weak) IBOutlet NSSplitView *topSplitView;
@property (weak) IBOutlet NSSplitView *mainSplitView;
@property (weak) IBOutlet NSImageView *serverStatusImage;
@property (weak) IBOutlet NSSegmentedControl *scanTypeControl;
@property (weak) IBOutlet NSSegmentedControl *scanResolutionControl;

@property (strong) IBOutlet SSScanManager *scanManager;
@property (weak) IBOutlet NSTextField *serverStatusText;
@property (weak) IBOutlet NSTextField *serverPortField;

- (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (IBAction)restartServer:(id)sender;

@end
