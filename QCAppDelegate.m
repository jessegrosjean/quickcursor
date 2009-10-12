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
#import "CrashReporter.h"


@implementation QCAppDelegate

+ (void)initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 [NSNumber numberWithBool:YES], QCSwitchBackWhenFinishedEditing,
															 nil]];
}

- (NSArray *)validatedEditorMenuItems:(SEL)action {
	static NSArray *cachedMenuItems = nil;
	
	if (!cachedMenuItems) {
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSMutableArray *menuItems = [NSMutableArray array];
		
		for (NSString *eachBundleID in [[NSBundle mainBundle] objectForInfoDictionaryKey:@"QCEditInChoices"]) {
			NSString *bundlePath = [workspace absolutePathForAppBundleWithIdentifier:eachBundleID];
			
			if (bundlePath) {
				NSMenuItem *eachMenuItem = [[[NSMenuItem alloc] initWithTitle:[[NSBundle bundleWithPath:bundlePath] objectForInfoDictionaryKey:@"CFBundleName"] action:NULL keyEquivalent:@""] autorelease];
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
				NSString *keyEquivalent = SRCharacterForKeyCodeAndCarbonFlags([keyComboObject keyCode], [keyComboObject modifiers]);
				
				if (keyEquivalent != nil) {
					[anItem setKeyEquivalent:[keyEquivalent lowercaseString]];
					[anItem setKeyEquivalentModifierMask:[shortcutRecorder carbonToCocoaFlags:[keyComboObject modifiers]]];
					clear = NO;
				}			
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
	[[CrashReporter sharedInstance] check:nil];
	
	quickCursorSessionQCUIElements = [[NSMutableSet alloc] init];
	registeredHotKeys = [[NSMutableArray alloc] init];

    if (!AXAPIEnabled()) {
		NSString *message = NSLocalizedString(@"QuickCursor requires that the Accessibility API be enabled. Would you like to launch System Preferences so that you can turn on \"Enable access for assistive devices\".", nil);
        NSUInteger result = NSRunAlertPanel(message, @"", NSLocalizedString(@"OK", nil), NSLocalizedString(@"Quit QuickCursor", nil), NSLocalizedString(@"Cancel", nil));
        
        switch (result) {
            case NSAlertDefaultReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
                
            case NSAlertAlternateReturn:
                [NSApp terminate:self];
                return;
        }
    }

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
		[quickCursorMenu addItemWithTitle:NSLocalizedString(@"No Supported Apps Found", nil) action:nil keyEquivalent:@""];
		[[[quickCursorMenu itemArray] lastObject] setIndentationLevel:1];
	}
	
	[quickCursorMenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *aboutMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"About", nil) action:@selector(showAbout:) keyEquivalent:@""] autorelease];
	[aboutMenuItem setTarget:self];
	[quickCursorMenu addItem:aboutMenuItem];
	
	NSMenuItem *preferencesMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Preferences...", nil) action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
	[preferencesMenuItem setTarget:self];
	[quickCursorMenu addItem:preferencesMenuItem];

	NSMenuItem *checkForUpdatesMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check For Updates...", nil) action:@selector(checkForUpdates:) keyEquivalent:@""] autorelease];
	[checkForUpdatesMenuItem setTarget:self];
	[quickCursorMenu addItem:checkForUpdatesMenuItem];
	
//	NSMenuItem *helpMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"QuickCursor Help", nil) action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
//	[helpMenuItem setTarget:self];
//	[quickCursorMenu addItem:helpMenuItem];

	[quickCursorMenu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *quitMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@""] autorelease];
	[quitMenuItem setTarget:NSApp];
	[quickCursorMenu addItem:quitMenuItem];
	
	[quickCursorStatusItem setMenu:quickCursorMenu];
	[self updateHotKeys];
}

#pragma mark Actions

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

- (IBAction)checkForUpdates:(id)sender {
	[[SUUpdater sharedUpdater] checkForUpdates:sender];
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

- (IBAction)beginQuickCursorEdit:(id)sender {
	NSString *bundleID = nil;
	
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		bundleID = [sender representedObject];
	} else {
		bundleID = [sender identifier];
	}
	
	QCUIElement *focusedElement = [QCUIElement focusedElement];
	
	id value = focusedElement.value;
	
	if ([value isKindOfClass:[NSString class]]) {
		NSDictionary *context = [NSDictionary dictionaryWithObject:focusedElement forKey:@"uiElement"];
		NSString *processName = [focusedElement processName];
		NSString *windowTitle = focusedElement.window.title;
		NSString *editorCustomPath = [NSString stringWithFormat:@"%@ — %@", processName, windowTitle];		
		[[ODBEditor sharedODBEditor] setEditorBundleIdentifier:bundleID];
		[[ODBEditor sharedODBEditor] editString:value options:[NSDictionary dictionaryWithObject:editorCustomPath forKey:ODBEditorCustomPathKey] forClient:self context:context];
	} else {
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Could not edit text", nil)
						 defaultButton:NSLocalizedString(@"OK", nil)
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"QuickCursor could not find any text to edit. Make sure that a text view has keyboard focus, and then try again.", nil)] runModal];
	}
}

#pragma mark ODBEditor Callbacks

- (void)odbEditor:(ODBEditor *)editor didModifyFile:(NSString *)path newFileLocation:(NSString *)newPath  context:(NSDictionary *)context {
	// never seems to be called.
}

- (void)odbEditor:(ODBEditor *)editor didClosefile:(NSString *)path context:(NSDictionary *)context; {
	// never seems to be called.
}

- (void)odbEditor:(ODBEditor *)editor didModifyFileForString:(NSString *)newString context:(NSDictionary *)context; {
	QCUIElement *uiElement = [context valueForKey:@"uiElement"];
	uiElement.value = newString;
}

- (void)odbEditor:(ODBEditor *)editor didCloseFileForString:(NSString *)newString context:(NSDictionary *)context; {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:QCSwitchBackWhenFinishedEditing]) {
		[[context valueForKey:@"uiElement"] activateProcess];
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

NSString *QCSwitchBackWhenFinishedEditing = @"QCSwitchBackWhenFinishedEditing";