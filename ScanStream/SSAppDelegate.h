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


@interface SSAppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet IKDeviceBrowserView *deviceBrowserView;
@property (unsafe_unretained) IBOutlet NSTextView *logTextView;
@property (weak) IBOutlet NSSplitView *topSplitView;
@property (weak) IBOutlet NSSplitView *mainSplitView;
@property (strong) IBOutlet SSScanManager *scanManager;

- (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end
