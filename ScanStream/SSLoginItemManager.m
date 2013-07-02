//
//  SSLoginItemManager.m
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 6/14/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
//

#import "SSLoginItemManager.h"


@implementation SSLoginItemManager {
    LSSharedFileListRef _loginItemList;
    NSURL *_applicationURL;
}

- (id)init
{
    self = [super init];
    if (self) {
        _applicationURL = [NSBundle mainBundle].bundleURL;
        _loginItemList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
        if (_loginItemList) {
            LSSharedFileListAddObserver(_loginItemList,
                                        CFRunLoopGetCurrent(),
                                        kCFRunLoopDefaultMode,
                                        listChangedCallback,
                                        (__bridge void *)self);
            [self _loginItemListChanged];
        }
        else {
            NSLog(@"Error creating login item list");
        }
    }
    return self;
}

- (void)dealloc
{
    if (_loginItemList) {
        LSSharedFileListRemoveObserver(_loginItemList,
                                       CFRunLoopGetCurrent(),
                                       kCFRunLoopDefaultMode,
                                       listChangedCallback,
                                       (__bridge void *)self);
        CFRelease(_loginItemList);
    }
}

void listChangedCallback(LSSharedFileListRef inList, void *context)
{
    [(__bridge SSLoginItemManager *)context _loginItemListChanged];
}

- (LSSharedFileListItemRef)_searchForApplicationInList
{
    NSArray *items = (__bridge_transfer NSArray *)LSSharedFileListCopySnapshot(_loginItemList, NULL);
    for (id item in items) {
        CFURLRef itemURL = NULL;
        if (LSSharedFileListItemResolve((__bridge LSSharedFileListItemRef)item,
                                        kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
                                        &itemURL,
                                        NULL) != noErr) {
            NSLog(@"Error resolving list item");
            continue;
        }
        
        if ([_applicationURL isEqual:(__bridge_transfer NSURL *)itemURL]) {
            return (__bridge_retained LSSharedFileListItemRef)item;
        }
    }
    return NULL;
}

- (void)_loginItemListChanged
{
    BOOL appInList = ((__bridge_transfer id)[self _searchForApplicationInList] != NULL);
    
    [self willChangeValueForKey:@"openApplicationAtLogin"];
    _openApplicationAtLogin = appInList;
    [self didChangeValueForKey:@"openApplicationAtLogin"];
}

- (void)setOpenApplicationAtLogin:(BOOL)shouldOpen
{
    if (!_loginItemList) return;
    
    LSSharedFileListItemRef appItem = [self _searchForApplicationInList];
    
    if (appItem && !shouldOpen) {
        if (LSSharedFileListItemRemove(_loginItemList, appItem) != noErr) {
            NSLog(@"Error removing list item");
        }
        CFRelease(appItem);
    }
    else if (!appItem && shouldOpen) {
        if (!LSSharedFileListInsertItemURL(_loginItemList,
                                           kLSSharedFileListItemBeforeFirst,
                                           NULL, NULL,
                                           (__bridge CFURLRef)_applicationURL,
                                           NULL, NULL)) {
            NSLog(@"Error inserting list item");
        }
    }
    
    [self willChangeValueForKey:@"openApplicationAtLogin"];
    _openApplicationAtLogin = shouldOpen;
    [self didChangeValueForKey:@"openApplicationAtLogin"];
}


@end
