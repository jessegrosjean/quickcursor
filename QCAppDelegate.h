//
//  QCAppDelegate.h
//  QuickCursor
//
//  Created by Jesse Grosjean on 9/1/09.
//  Copyright 2009 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>


@class PTHotKey;

@interface QCAppDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSPopUpButton *editInPopUpButton;
	IBOutlet SRRecorderControl *shortcutRecorder;
	
	NSStatusItem *quickCursorStatusItem;
	NSMutableSet *quickCursorSessionQCUIElements;
	NSMutableArray *registeredHotKeys;
}

#pragma mark Actions

@property (assign) BOOL loginOnStartup;

- (IBAction)showAbout:(id)sender;	
- (IBAction)showPreferences:(id)sender;
- (IBAction)editInPopUpButtonClicked:(id)sender;
- (IBAction)beginQuickCursorEdit:(id)sender;	

@end