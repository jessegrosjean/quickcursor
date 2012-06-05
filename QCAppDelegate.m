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


- (NSArray *)validatedEditorMenuItems:(SEL)action {
	if (!cachedMenuItems) {
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSMutableArray *menuItems = [NSMutableArray array];
        
        NSMutableArray *editInChoices = [NSMutableArray arrayWithArray:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"QCEditInChoices"]];
        for (NSDictionary *customEditors in [[NSUserDefaults standardUserDefaults] objectForKey:@"CustomEditors"]) {
            NSString *bundleID = [customEditors objectForKey:@"BundleID"];
            if (bundleID && ![editInChoices containsObject:bundleID]) {
                [editInChoices addObject:bundleID];
            }
        }
        
		for (NSString *eachBundleID in editInChoices) {
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

	NSMutableArray *results = [NSMutableArray array];
	
	for (NSMenuItem *each in cachedMenuItems) {
		NSMenuItem *eachCopy = [[each copy] autorelease];
		[eachCopy setTarget:self];
		[eachCopy setAction:action];
		[results addObject:eachCopy];
	}
	
	return results;
}

- (void)updateHotKeys {
	PTHotKeyCenter *hotKeyCenter = [PTHotKeyCenter sharedCenter];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	for (PTHotKey *each in registeredHotKeys) {
		[hotKeyCenter unregisterHotKey:each];
	}
	
	[registeredHotKeys removeAllObjects];
	
	for (NSMenuItem *each in [self validatedEditorMenuItems:NULL]) {
		id eachKeyComboPlist = [userDefaults objectForKey:[each representedObject]];
		if (eachKeyComboPlist) {
			PTKeyCombo *keyCombo = [[[PTKeyCombo alloc] initWithPlistRepresentation:eachKeyComboPlist] autorelease];
			PTHotKey *hotKey = [[[PTHotKey alloc] initWithIdentifier:[each representedObject] keyCombo:keyCombo] autorelease];
			[hotKey setTarget:self];
			[hotKey setAction:@selector(beginQuickCursorEdit:)];
			[hotKeyCenter registerHotKey:hotKey];
			[registeredHotKeys addObject:hotKey];
		}
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem {
	if ([anItem action] == @selector(beginQuickCursorEdit:)) {
		id keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey:[anItem representedObject]];
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
		
	[quickCursorMenu addItemWithTitle:NSLocalizedString(@"Edit In...", nil) action:NULL keyEquivalent:@""];
	
	NSArray *supportedAppsMenuItems = [self validatedEditorMenuItems:@selector(beginQuickCursorEdit:)];
	if ([supportedAppsMenuItems count] > 0) {
		for (NSMenuItem *each in supportedAppsMenuItems) {
			[quickCursorMenu addItem:each];
		}
	} else {
		[quickCursorMenu addItemWithTitle:NSLocalizedString(@"No Supported Text Editors Found", nil) action:nil keyEquivalent:@""];
		[[[quickCursorMenu itemArray] lastObject] setIndentationLevel:1];
	}
	
	[quickCursorMenu addItem:[NSMenuItem separatorItem]];
	
    NSMenuItem *insertAtCursorMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Insert at cursor", nil) action:nil keyEquivalent:@""] autorelease];
    [insertAtCursorMenuItem bind:@"value" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"SmartEdit" options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"NSContinuouslyUpdatesValue"]];
    [quickCursorMenu addItem:insertAtCursorMenuItem];    
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
	
	[self updateHotKeys];
	
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

- (IBAction)showPreferences:(id)sender {
	if ([editInPopUpButton numberOfItems] == 0) {
		[shortcutRecorder setCanCaptureGlobalHotKeys:YES];
		[shortcutRecorder setDelegate:self];

		for (NSMenuItem *each in [self validatedEditorMenuItems:NULL]) {
			[[editInPopUpButton menu] addItem:each];
		}
		
		[self editInPopUpButtonClicked:nil];
		
		if ([editInPopUpButton numberOfItems] == 0) {
			[editInPopUpButton setEnabled:NO];
			[shortcutRecorder setEnabled:NO];
		}
	}
	
	[NSApp activateIgnoringOtherApps:YES];
	[preferencesWindow center];
	[preferencesWindow makeKeyAndOrderFront:sender];
}

- (IBAction)showHelp:(id)sender {
	[[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"QuickCursor User's Guide" ofType:@"pdf"]];
}

- (IBAction)editInPopUpButtonClicked:(id)sender {
	id clicked = [[editInPopUpButton selectedItem] representedObject];
	if (clicked) {
		id keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey:clicked];
		if (keyComboPlist) {
			KeyCombo keyCombo;
			PTKeyCombo *keyComboObject = [[[PTKeyCombo alloc] initWithPlistRepresentation:keyComboPlist] autorelease];
			keyCombo.code = [keyComboObject keyCode];
			keyCombo.flags = [shortcutRecorder carbonToCocoaFlags:[keyComboObject modifiers]];
			[shortcutRecorder setKeyCombo:keyCombo];
		} else {
			[shortcutRecorder setKeyCombo:SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags)];		
		}
	}
}

- (void)beginQuickCursorEditByBundleID:(NSString *)bundleID {
    QCUIElement *focusedElement = [QCUIElement focusedElement];
	QCUIElement *sourceApplicationElement = [focusedElement application];
	NSString *editString = [sourceApplicationElement readString];
	NSString *processName = [sourceApplicationElement processName];
	
	if (editString) {		
		NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys:sourceApplicationElement, @"sourceApplicationElement", bundleID, @"editorBundleID", editString, @"originalString", processName, @"processName", nil];
		NSString *windowTitle = focusedElement.window.title;
		NSString *correctedWindowTitle = [windowTitle stringByReplacingOccurrencesOfString:@"/" withString:@":"];
		NSString *editorCustomPath = [NSString stringWithFormat:@"%@ - %@", processName, correctedWindowTitle];	
		[[ODBEditor sharedODBEditor] setEditorBundleIdentifier:bundleID];
		[[ODBEditor sharedODBEditor] editString:editString options:[NSDictionary dictionaryWithObject:editorCustomPath forKey:ODBEditorCustomPathKey] forClient:self context:context];
	} else {
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not copy text from %@", nil), processName]
						 defaultButton:NSLocalizedString(@"OK", nil)
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"QuickCursor could not copy text from %@. Please make sure that a text area has focus and try again.", nil), processName]] runModal];
	}
}

- (IBAction)beginQuickCursorEdit:(id)sender {
	if ([QCAppDelegate universalAccessNeedsToBeTurnedOn]) {
		return;
	}
	
	NSString *bundleID = nil;
	
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		bundleID = [sender representedObject];
	} else {
		bundleID = [sender identifier];
	}
    
    [self performSelector:@selector(beginQuickCursorEditByBundleID:) withObject:bundleID afterDelay:0.1];
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

#pragma mark shortcutRecorder Delegate

- (BOOL)shortcutRecorder:(SRRecorderControl *)aRecorder isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason {
	return NO;
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {
	signed short code = newKeyCombo.code;
	unsigned int flags = [aRecorder cocoaToCarbonFlags:newKeyCombo.flags];
	PTKeyCombo *keyCombo = [[[PTKeyCombo alloc] initWithKeyCode:code modifiers:flags] autorelease];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject:[keyCombo plistRepresentation] forKey:[[editInPopUpButton selectedItem] representedObject]];
	[self updateHotKeys];
	[userDefaults synchronize];
}

@end