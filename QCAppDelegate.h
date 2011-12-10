//
//  QCAppDelegate.h
//  QuickCursor
//
//  Created by Jesse Grosjean on 9/1/09.
//  Copyright 2009 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>
#import "QCSRDelegate.h"
#import "PTKeyCombo.h"

@class PTHotKey;
@class QCSRDelegate;

extern NSString * const TYPE_EDIT;
extern NSString * const TYPE_INSERT;

@interface QCAppDelegate : NSObject {
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSButton *openAtLogin;

    /* Keyboard shortcut popups and controls */
    IBOutlet NSPopUpButton *editInPopUpButton;
    IBOutlet NSPopUpButton *insertInPopUpButton;
	IBOutlet SRRecorderControl *editShortcutRecorder;
    IBOutlet SRRecorderControl *insertShortcutRecorder;
    
	NSStatusItem *quickCursorStatusItem;
	NSMutableSet *quickCursorSessionQCUIElements;
	NSMutableArray *registeredHotKeys;
    
    QCSRDelegate *editSRDelegate;
    QCSRDelegate *insertSRDelegate;
}

+ (BOOL)universalAccessNeedsToBeTurnedOn;
+ (NSString *)makeUserDefaultString:(NSDictionary *)representedObject;
- (void)updateHotKeys:(NSString *)userDefaultString addingKeyCombo:(PTKeyCombo *)newKeyCombo usingRecorder:(SRRecorderControl *)addingWithRecorder;

//@property(assign) BOOL enableLoginItem;

#pragma mark Actions

- (IBAction)showHelp:(id)sender;	
- (IBAction)showAbout:(id)sender;	
- (IBAction)showPreferences:(id)sender;
- (IBAction)beginQuickCursorAction:(id)sender;	

/* Generic function for any shortcut popup button */
- (IBAction)popUpButtonClicked:(id)sender;

@end