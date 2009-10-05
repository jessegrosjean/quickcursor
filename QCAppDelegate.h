//
//  QCAppDelegate.h
//  QuickCursor
//
//  Created by Jesse Grosjean on 9/1/09.
//  Copyright 2009 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <ShortcutRecorder/ShortcutRecorder.h>


@class PTHotKey;

@interface QCAppDelegate : NSObject {
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSPopUpButton *editInPopUpButton;
	IBOutlet SRRecorderControl *shortcutRecorder;
	IBOutlet NSButton *openAtLogin;
	
	NSStatusItem *quickCursorStatusItem;
	NSMutableSet *quickCursorSessionQCUIElements;
	NSMutableArray *registeredHotKeys;
}

@property(assign) BOOL enableLoginItem;

#pragma mark Actions

- (IBAction)showAbout:(id)sender;	
- (IBAction)showPreferences:(id)sender;
- (IBAction)editInPopUpButtonClicked:(id)sender;
- (IBAction)beginQuickCursorEdit:(id)sender;	

@end