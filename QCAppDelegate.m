//
//  QCAppDelegate.m
//  QuickCursor
//
//  Created by Jesse Grosjean on 9/1/09.
//  Copyright 2009 Hog Bay Software. All rights reserved.
//

#import "QCAppDelegate.h"
#import "PTHotKeyCenter.h"
#import "PTHotKey.h"
#import "QCUIElement.h"
#import "ODBEditor.h"

NSString * const TYPE_EDIT = @"edit";
NSString * const TYPE_INSERT = @"insert";

@implementation QCAppDelegate

+ (BOOL)universalAccessNeedsToBeTurnedOn {
	if (!AXAPIEnabled()) {
		NSString *message = NSLocalizedString(@"QuickCursor requires that you launch the Universal Access preferences pane and turn on \"Enable access for assistive devices\".", nil);
        NSUInteger result = NSRunAlertPanel(message, @"", NSLocalizedString(@"OK", nil), NSLocalizedString(@"Quit QuickCursor", nil), NSLocalizedString(@"Cancel", nil));
        
        switch (result) {
            case NSAlertDefaultReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
                
            case NSAlertAlternateReturn:
                [NSApp terminate:self];
				break;
		}
		return YES;
	} else {
		return NO;
	}
}

/* 
 * We can't just identify the user default by the bundleID anymore, because
 * we need to track two pieces of information in the stored shortcut: the type
 * of action (edit vs insert) and the bundleID (identifies the application).
 */
+ (NSString *)makeUserDefaultString:(NSDictionary *)representedObject {
    NSString *repObjectType = [representedObject objectForKey:@"type"];
    NSString *repObjectBundleID = [representedObject objectForKey:@"bundleID"];
    
    // Example:  @"edit org.myeditor.MyEditor"  or  @"insert org.myeditor.MyEditor"
    return [NSString stringWithFormat:@"%@ %@", repObjectType, repObjectBundleID];
}

- (void)dealloc {
    if (editSRDelegate) {
        [editSRDelegate release];
    }
    if (insertSRDelegate) {
        [insertSRDelegate release];
    }
    [super dealloc];
}

/*
 * Loops through QuickCursor-Info.plist, grabs all of the possible bundle names,
 * then finds installed bundles by those names.  For each found name, two menu items
 * are created - one for "Edit" and one for "Insert".
 *
 * Returns NSDictionary with key "edit" holding NSMenuItems for edit shortcuts,
 * and key "Insert" holding NSMenuItems for insert shortcuts.
 */
- (NSMutableArray *)validatedEditorMenuItems:(SEL)action {
	static NSArray *cachedMenuItems = nil;
	
	if (!cachedMenuItems) {
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSMutableArray *menuItems = [NSMutableArray array];
		
		for (NSString *eachBundleID in [[NSBundle mainBundle] objectForInfoDictionaryKey:@"QCEditInChoices"]) {
			NSString *bundlePath = [workspace absolutePathForAppBundleWithIdentifier:eachBundleID];
			
			if (bundlePath) {
				NSString *bundleName = [[NSBundle bundleWithPath:bundlePath] objectForInfoDictionaryKey:@"CFBundleName"]; // seems to be nil in some cases.
				if (!bundleName) {
					bundleName = [[bundlePath lastPathComponent] stringByDeletingPathExtension];
				}
				
				if ([eachBundleID isEqualToString:@"org.gnu.Aquamacs"]) {
					bundleName = [bundleName stringByAppendingString:@" 2.2+"];
				}
				
				NSMenuItem *eachMenuItem = [[[NSMenuItem alloc] initWithTitle:bundleName action:NULL keyEquivalent:@""] autorelease];
				[eachMenuItem setRepresentedObject:eachBundleID];
				[eachMenuItem setIndentationLevel:1];
				NSImage *icon = [workspace iconForFile:bundlePath];
				[icon setSize:NSMakeSize(16, 16)];
				[eachMenuItem setImage:icon];
				[menuItems addObject:eachMenuItem];
			}
		}
		
		[menuItems sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES] autorelease]]];
		
		cachedMenuItems = [menuItems retain];
	}

    // We build one big set of menu items.  Two types are represented: "edit" and "insert" items.
    // We can tell the difference by looking at [[each representedObject] stringForKey:@"type"]
	NSMutableArray *results = [NSMutableArray array];
	
	for (NSMenuItem *each in cachedMenuItems) {
    
        // For each cached item, we will make one "Edit" and one "Insert" item.
        
        // The current representedObject is the string bundleID, like @"org.gnu.Aquamacs"
        NSString *oldRepObject = (NSString *)[each representedObject];

        // Creating the "Edit" item
        NSMenuItem *editCopy = [[each copy] autorelease];

        // The new represented object is a dictionary with:
        //    @"type" => @"edit",
        //    @"bundleID" => @"org.gnu.Aquamacs"
        NSArray *editDictObjects = [NSArray arrayWithObjects:TYPE_EDIT, oldRepObject, nil];
        NSArray *editDictKeys = [NSArray arrayWithObjects:@"type", @"bundleID", nil];
        [editCopy setRepresentedObject:[NSDictionary dictionaryWithObjects:editDictObjects forKeys:editDictKeys]];
        
        // Finish up the "Edit" item
        [editCopy setTarget:self];
        [editCopy setAction:action];
        [results addObject:editCopy];

        // Do the same thing to create the "Insert" item
        NSMenuItem *insertCopy = [[each copy] autorelease];

        NSArray *insertDictObjects = [NSArray arrayWithObjects:TYPE_INSERT, oldRepObject, nil];
        NSArray *insertDictKeys = [NSArray arrayWithObjects:@"type", @"bundleID", nil];
        [insertCopy setRepresentedObject:[NSDictionary dictionaryWithObjects:insertDictObjects forKeys:insertDictKeys]];

        [insertCopy setTarget:self];
        [insertCopy setAction:action];
        [results addObject:insertCopy];
	}
    
	return results;
}

/* When updating keys from an addition, pass in userDefaultString and the key combo, and
 * this method will also make sure that there are no duplicates. */
- (void)updateHotKeys:(NSString *)userDefaultString addingKeyCombo:(PTKeyCombo *)newKeyCombo usingRecorder:(SRRecorderControl *)addingWithRecorder {
	PTHotKeyCenter *hotKeyCenter = [PTHotKeyCenter sharedCenter];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	for (PTHotKey *each in registeredHotKeys) {
		[hotKeyCenter unregisterHotKey:each];
	}
	
	[registeredHotKeys removeAllObjects];
    
	for (NSMenuItem *each in [self validatedEditorMenuItems:NULL]) {                
        NSString *curUserDefaultString = [QCAppDelegate makeUserDefaultString:[each representedObject]];
        
		id eachKeyComboPlist = [userDefaults objectForKey:curUserDefaultString];
		if (eachKeyComboPlist) {            
			PTKeyCombo *curKeyCombo = [[[PTKeyCombo alloc] initWithPlistRepresentation:eachKeyComboPlist] autorelease];
            
            // If we found an existing key combo with the same one we're about to add,
            // and it's not for this program, then we skip it because it just got overwritten
            // by the addition.
            if (newKeyCombo) {
                if ([newKeyCombo isEqual:curKeyCombo]) {
                    if (![curUserDefaultString isEqualToString:userDefaultString]) {
                        [userDefaults removeObjectForKey:curUserDefaultString];
                        
                        SRRecorderControl *otherRecorder;
                        if (addingWithRecorder == editShortcutRecorder) {
                            otherRecorder = insertShortcutRecorder;
                        } else {
                            otherRecorder = editShortcutRecorder;
                        }
                        
                        NSString *addingComboString = [addingWithRecorder keyComboString];
                        NSString *otherComboString = [otherRecorder keyComboString];

                        // If the combo we're changing is actually displayed right now on the other control
                        // in the preferences dialog, then we clear it out right now
                        if ([addingComboString isEqualToString:otherComboString]) {
                            [otherRecorder setKeyCombo:SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags)];
                        }
                        
                        continue;
                    }
                }
            }
            
			PTHotKey *hotKey = [[[PTHotKey alloc] initWithIdentifier:curUserDefaultString keyCombo:curKeyCombo] autorelease];
			[hotKey setTarget:self];            
			[hotKey setAction:@selector(beginQuickCursorAction:)];
			[hotKeyCenter registerHotKey:hotKey];
			[registeredHotKeys addObject:hotKey];
		}
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem {
	if ([anItem action] == @selector(beginQuickCursorAction:)) {
        NSString *userDefaultString = [QCAppDelegate makeUserDefaultString:[anItem representedObject]];
        
		id keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey:userDefaultString];
		BOOL clear = YES;
		
		if (keyComboPlist) {
			PTKeyCombo *keyComboObject = [[[PTKeyCombo alloc] initWithPlistRepresentation:keyComboPlist] autorelease];
			if ([keyComboObject keyCode] != -1) {
				[anItem setKeyEquivalent:[SRStringForKeyCode([keyComboObject keyCode]) lowercaseString]];
				[anItem setKeyEquivalentModifierMask:SRCarbonToCocoaFlags([keyComboObject modifiers])];
				clear = NO;
			}
		}
		
		if (clear) {
			[anItem setKeyEquivalent:@""];
			[anItem setKeyEquivalentModifierMask:0];
		}
	}
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {	
	//NSMenu *m = [NSApp mainMenu];
	
	
	quickCursorSessionQCUIElements = [[NSMutableSet alloc] init];
	registeredHotKeys = [[NSMutableArray alloc] init];
	
	[QCAppDelegate universalAccessNeedsToBeTurnedOn];

    quickCursorStatusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	NSImage *image = [NSImage imageNamed:@"StatusItemIcon.png"];
	[image setTemplate:YES];
	[quickCursorStatusItem setImage:image];
    [quickCursorStatusItem setHighlightMode:YES];
		
	NSMenu *quickCursorMenu = [[[NSMenu alloc] init] autorelease];
	
    NSMutableArray *validatedItems = [self validatedEditorMenuItems:@selector(beginQuickCursorAction:)];
    
    NSMutableArray *editItems = [NSMutableArray array];
    NSMutableArray *insertItems = [NSMutableArray array];

    // Build separate Insert and Edit items for the menus...
    for (NSMenuItem *each in validatedItems) {
        NSString *type = [[each representedObject] objectForKey:@"type"];
        if ([type isEqualToString:TYPE_EDIT]) {
            [editItems addObject:each];
        } else {
            [insertItems addObject:each];
        }
    }
    
    // Add "Edit" and "Insert" to menu bar
	if ([validatedItems count] > 0) {
        [quickCursorMenu addItemWithTitle:NSLocalizedString(@"Edit In...", nil) action:NULL keyEquivalent:@""];
        
		for (NSMenuItem *each in editItems) {
			[quickCursorMenu addItem:each];
		}
        
        [quickCursorMenu addItemWithTitle:NSLocalizedString(@"Insert In...", nil) action:NULL keyEquivalent:@""];
        
        for (NSMenuItem *each in insertItems) {
            [quickCursorMenu addItem:each];
        }
        
	} else {
		[quickCursorMenu addItemWithTitle:NSLocalizedString(@"No Supported Text Editors Found", nil) action:nil keyEquivalent:@""];
		[[[quickCursorMenu itemArray] lastObject] setIndentationLevel:1];
	}
	
	[quickCursorMenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *helpMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Help", nil) action:@selector(showHelp:) keyEquivalent:@""] autorelease];
	[helpMenuItem setTarget:self];
	[quickCursorMenu addItem:helpMenuItem];
	
	NSMenuItem *aboutMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"About", nil) action:@selector(showAbout:) keyEquivalent:@""] autorelease];
	[aboutMenuItem setTarget:self];
	[quickCursorMenu addItem:aboutMenuItem];
	
	NSMenuItem *preferencesMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Preferences...", nil) action:@selector(showPreferences:) keyEquivalent:@","] autorelease];
	[preferencesMenuItem setTarget:self];
	[quickCursorMenu addItem:preferencesMenuItem];
		
	[quickCursorMenu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *quitMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"] autorelease];
	[quitMenuItem setTarget:NSApp];
	[quickCursorMenu addItem:quitMenuItem];
	
	[quickCursorStatusItem setMenu:quickCursorMenu];
	
	[self updateHotKeys:NULL addingKeyCombo:NULL usingRecorder:NULL];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if (![userDefaults boolForKey:@"SuppressWelcomeDefaultKey"]) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Welcome to QuickCursor", nil)
										 defaultButton:NSLocalizedString(@"OK", nil)
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"QuickCursor runs in the OS X menu bar. To use and configure QuickCursor click its menu bar icon.", nil)];
		[alert setShowsSuppressionButton:YES];
		[alert runModal];
		if ([[alert suppressionButton] state] == NSOnState) {
			[userDefaults setBool:YES forKey:@"SuppressWelcomeDefaultKey"];
		}
	}
}

#pragma mark Actions

/*
 
 Mac App Store doesn't like us using this. And will be disallowed by sanboxing soon anyway. SMLoginItemSetEnabled
 might be an alternative method that will work, but I don't really understand it.
 
- (BOOL)enableLoginItem {
	NSString *bundleName = [[[NSBundle mainBundle] bundlePath] lastPathComponent];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	BOOL result = NO;
	
	// 1. Remove everything.
	CFURLRef thePath;
	UInt32 seedValue;
	NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
	for (id item in loginItemsArray) {		
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr) {
			if ([[(NSURL *)thePath path] hasSuffix:bundleName])
				result = YES;
		}
	}	
	[loginItemsArray release];
	
	CFRelease(loginItems);	
	
	return result;
}

- (void)setEnableLoginItem:(BOOL)aBOOL {
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	CFURLRef bundlePathURL = (CFURLRef)[NSURL fileURLWithPath:bundlePath];
	NSString *bundleName = [bundlePath lastPathComponent];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);

	// 1. Remove everything.
	CFURLRef thePath;
	UInt32 seedValue;
	NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
	for (id item in loginItemsArray) {		
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr) {
			if ([[(NSURL *)thePath path] hasSuffix:bundleName])
				LSSharedFileListItemRemove(loginItems, itemRef); // Deleting the item
		}
	}	
	[loginItemsArray release];
	
	// 2. Add back if needed.
	if (aBOOL) {
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, bundlePathURL, NULL, NULL);		
		if (item) {
			CFRelease(item);
		}
	}
	
	CFRelease(loginItems);
}
*/

- (IBAction)showAbout:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:sender];
}

- (void)setupPrefsForShortcuts:(NSPopUpButton *)popUpButton shortcutRecorder:(SRRecorderControl *)shortcutRecorder {
    if ([popUpButton numberOfItems] == 0) {
		[shortcutRecorder setCanCaptureGlobalHotKeys:YES];

        // Straight up pointer equality is fine here, since these are pointing to the same place
        BOOL isEditType = (popUpButton == editInPopUpButton);
                
        if (isEditType) {
            if (!editSRDelegate) {
                editSRDelegate = [[QCSRDelegate alloc] initWithOwnerAndBtn:self popUpButton:editInPopUpButton];
            }
            [shortcutRecorder setDelegate:editSRDelegate];
        }
        else {
            if (!insertSRDelegate) {
                insertSRDelegate = [[QCSRDelegate alloc] initWithOwnerAndBtn:self popUpButton:insertInPopUpButton];
            }
            [shortcutRecorder setDelegate:insertSRDelegate];
        }
        
        NSMutableArray *validatedItems = [self validatedEditorMenuItems:NULL];
        NSString *onlyUseType = isEditType ? TYPE_EDIT : TYPE_INSERT;
                
		for (NSMenuItem *each in validatedItems) {
            NSString *type = [[each representedObject] objectForKey:@"type"];
            if ([type isEqualToString:onlyUseType]) {
                [[popUpButton menu] addItem:each];
            }
		}
		
        [self popUpButtonClicked:popUpButton];
		
		if ([popUpButton numberOfItems] == 0) {
			[popUpButton setEnabled:NO];
			[shortcutRecorder setEnabled:NO];
		}
	}
}

- (IBAction)showPreferences:(id)sender {
    [self setupPrefsForShortcuts:editInPopUpButton shortcutRecorder:editShortcutRecorder];
    [self setupPrefsForShortcuts:insertInPopUpButton shortcutRecorder:insertShortcutRecorder];
	
	[NSApp activateIgnoringOtherApps:YES];
	[preferencesWindow center];
	[preferencesWindow makeKeyAndOrderFront:sender];
}

- (IBAction)showHelp:(id)sender {
	[[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"QuickCursor User's Guide" ofType:@"pdf"]];
}

/* 
 * Generic function to process pop-up button clicks (selects the application shortcut)
 * Can process both 'Edit' and 'Insert' shortcut clicks.
 */
- (IBAction)popUpButtonClicked:(id)sender {
    if (![sender isKindOfClass:[NSPopUpButton class]]) {
        return;
    }

    // Since we know the object type, cast it
    NSPopUpButton *popupSender = (NSPopUpButton *)sender;

    // Figure out which shortcut is being set right now
    NSString *uiID = [popupSender identifier];
    SRRecorderControl *recorder;
    recorder = ([uiID isEqualToString:TYPE_EDIT]) ? editShortcutRecorder : insertShortcutRecorder;
        
    id clicked = [QCAppDelegate makeUserDefaultString:[[popupSender selectedItem] representedObject]];
	if (clicked) {
		id keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey:clicked];
		if (keyComboPlist) {
			KeyCombo keyCombo;
			PTKeyCombo *keyComboObject = [[[PTKeyCombo alloc] initWithPlistRepresentation:keyComboPlist] autorelease];
			keyCombo.code = [keyComboObject keyCode];
			keyCombo.flags = [recorder carbonToCocoaFlags:[keyComboObject modifiers]];
			[recorder setKeyCombo:keyCombo];
		} else {
			[recorder setKeyCombo:SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags)];		
		}
	}
}

- (IBAction)beginQuickCursorAction:(id)sender {
	if ([QCAppDelegate universalAccessNeedsToBeTurnedOn]) {
		return;
	}
	
	NSString *repObjStr = nil;
	
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		repObjStr = [sender representedObject];
	} else {
		repObjStr = [sender identifier];
	}
    
    NSArray *repObjComponents = [repObjStr componentsSeparatedByString:@" "];
    if ([repObjComponents count] != 2) {
        return;
    }
    
    NSString *type = (NSString *)[repObjComponents objectAtIndex:0];
    NSString *bundleID = (NSString *)[repObjComponents objectAtIndex:1];
	
	QCUIElement *focusedElement = [QCUIElement focusedElement];
	QCUIElement *sourceApplicationElement = [focusedElement application];	
	NSString *processName = [sourceApplicationElement processName];
    NSString *editString;
    
    if ([type isEqualToString:TYPE_EDIT]) {
        editString = [sourceApplicationElement readString];
        
        if (!editString) {
            [[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not copy text from %@", nil), processName]
                             defaultButton:NSLocalizedString(@"OK", nil)
                           alternateButton:nil
                               otherButton:nil
                 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"QuickCursor could not copy text from %@. Please make sure that a text area has focus and try again.", nil), processName]] runModal];
            
            return;
        }
    } else {
        editString = @"";
    }
    		
    NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys:sourceApplicationElement, @"sourceApplicationElement", bundleID, @"editorBundleID", editString, @"originalString", processName, @"processName", nil];
    NSString *windowTitle = focusedElement.window.title;
    NSString *correctedWindowTitle = [windowTitle stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    NSString *editorCustomPath = [NSString stringWithFormat:@"%@ - %@", processName, correctedWindowTitle];	
    [[ODBEditor sharedODBEditor] setEditorBundleIdentifier:bundleID];
    [[ODBEditor sharedODBEditor] editString:editString options:[NSDictionary dictionaryWithObject:editorCustomPath forKey:ODBEditorCustomPathKey] forClient:self context:context];
}

#pragma mark ODBEditor Callbacks

- (void)odbEditor:(ODBEditor *)editor didModifyFile:(NSString *)path newFileLocation:(NSString *)newPath  context:(NSDictionary *)context {
	// never seems to be called.
}

- (void)odbEditor:(ODBEditor *)editor didClosefile:(NSString *)path context:(NSDictionary *)context; {
	// never seems to be called.
}

- (void)odbEditor:(ODBEditor *)editor didModifyFileForString:(NSString *)newString context:(NSDictionary *)context; {
	// HACK TextMate doesn't sedn a didCloseFile event when a file is closed as the result of the application shutdown process.
	// But it does send a didModifyFile event, so here I'm catching that event and if the application is no longer running then I paste
	// text back into source app... This test still has issues (user saves in textmate, then quite app after save), so commenting out for now. Darn TextMate!
	/*NSString *editorBundleID = [context valueForKey:@"editorBundleID"];
	if ([editorBundleID isEqualToString:@"com.macromates.textmate"]) {
		NSRunningApplication *runingEditorApplication = [[NSRunningApplication runningApplicationsWithBundleIdentifier:editorBundleID] lastObject];
		if (runingEditorApplication) {
			NSLog(@"%@ is still running", editorBundleID);
		} else {
			NSLog(@"%@ is not still running", editorBundleID);
		}
	}*/
}

- (void)odbEditor:(ODBEditor *)editor didCloseFileForString:(NSString *)newString context:(NSDictionary *)context; {
	QCUIElement *sourceApplicationElement = [context valueForKey:@"sourceApplicationElement"];
	NSString *originalString = [context valueForKey:@"originalString"];
	NSString *processName = [context valueForKey:@"processName"];
	
	if (![originalString isEqualToString:newString]) {
		if (![sourceApplicationElement writeString:newString]) {
			NSBeep();
			[NSApp activateIgnoringOtherApps:YES];
			[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not paste text back into %@", nil), processName]
							 defaultButton:NSLocalizedString(@"OK", nil)
						   alternateButton:nil
							   otherButton:nil
				 informativeTextWithFormat:NSLocalizedString(@"Your edited text has been saved to the clipboard and can be pasted into another application.", nil)] runModal];
		}
	} else {
		[sourceApplicationElement activateProcess];
	}
}

@end
