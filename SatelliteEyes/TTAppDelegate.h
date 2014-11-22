//
//  TTAppDelegate.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TTMapManager;
@class TTStatusItemController;
@class TTPreferencesWindowController;
@class TTAboutWindowController;

@interface TTAppDelegate : NSObject <NSApplicationDelegate> {
    TTStatusItemController *statusItemController;
    TTPreferencesWindowController *preferencesWindowController;
    TTAboutWindowController *aboutWindowController;
}

@property IBOutlet TTPreferencesWindowController *preferencesWindowController;
@property IBOutlet TTAboutWindowController *aboutWindowController;
@property (nonatomic, strong, readonly) TTMapManager *mapManager;

- (void)menuActionExit:(id)sender;
- (void)forceMapUpdate:(id)sender;
- (void)openMapInBrowser:(id)sender;
- (void)checkForUpdates:(id)sender;
- (void)showPreferences:(id)sender;
- (void)showAbout:(id)sender;
- (void)setUserDefaults;
- (NSURL *)visibleMapBrowserURL;

@end
