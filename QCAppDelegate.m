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
#import "BBAppSessionLoginState.h"

@implementation QCAppDelegate

+ (void)initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
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
			PTHotKey *hotKey = [[PTHotKey alloc] initWithIdentifier:[each representedObject] keyCombo:keyCombo];
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
		BOOL clear = NO;
		
		if (keyComboPlist) {
			PTKeyCombo *keyComboObject = [[[PTKeyCombo alloc] initWithPlistRepresentation:keyComboPlist] autorelease];
			//NSString *keyEquivalent = SRStringForKeyCode([keyComboObject keyCode]);
			NSString *keyEquivalent = SRCharacterForKeyCodeAndCarbonFlags([keyComboObject keyCode], [keyComboObject modifiers]);
			
			if (keyEquivalent) {
				[anItem setKeyEquivalent:[keyEquivalent lowercaseString]];
				[anItem setKeyEquivalentModifierMask:[shortcutRecorder carbonToCocoaFlags:[keyComboObject modifiers]]];
			} else {
				clear = YES;
			}
			
		} else {
			clear = YES;
		}
		
		if (clear) {
			[anItem setKeyEquivalent:@""];
			[anItem setKeyEquivalentModifierMask:0];
		}
	}
	return YES;
}

- (BBAppSessionLoginState *)appSessionLoginState {
	return [BBAppSessionLoginState sharedController];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
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
	NSImage *image = [NSImage imageNamed:@"StatusItemIcon"];
	[image setTemplate:YES];
	[quickCursorStatusItem setImage:image];
    [quickCursorStatusItem setHighlightMode:YES];
		
	NSMenu *quickCursorMenu = [[[NSMenu alloc] init] autorelease];
		
	[quickCursorMenu addItemWithTitle:NSLocalizedString(@"Edit In...", nil) action:NULL keyEquivalent:@""];
	
	for (NSMenuItem *each in [self validatedEditorMenuItems:@selector(beginQuickCursorEdit:)]) {
		[quickCursorMenu addItem:each];
	}
	
	[quickCursorMenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *aboutMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"About", nil) action:@selector(showAbout:) keyEquivalent:@""] autorelease];
	[aboutMenuItem setTarget:self];
	[quickCursorMenu addItem:aboutMenuItem];
	
	NSMenuItem *preferencesMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Preferences...", nil) action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
	[preferencesMenuItem setTarget:self];
	[quickCursorMenu addItem:preferencesMenuItem];
	
	NSMenuItem *helpMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"QuickCursor Help", nil) action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
	[helpMenuItem setTarget:self];
	[quickCursorMenu addItem:helpMenuItem];

	[quickCursorMenu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *quitMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@""] autorelease];
	[quitMenuItem setTarget:NSApp];
	[quickCursorMenu addItem:quitMenuItem];
	
	[quickCursorStatusItem setMenu:quickCursorMenu];
	[self updateHotKeys];
}


#pragma mark Actions

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
	}
	
	[NSApp activateIgnoringOtherApps:YES];
	[preferencesWindow center];
	[preferencesWindow makeKeyAndOrderFront:sender];
}

- (IBAction)editInPopUpButtonClicked:(id)sender {
	id keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey:[[editInPopUpButton selectedItem] representedObject]];
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
		NSString *editorCustomPath = [NSString stringWithFormat:@"%@ – %@", processName, windowTitle];		
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
}

- (void)odbEditor:(ODBEditor *)editor didClosefile:(NSString *)path context:(NSDictionary *)context; {
}

- (void)odbEditor:(ODBEditor *)editor didModifyFileForString:(NSString *)newString context:(NSDictionary *)context; {
	QCUIElement *uiElement = [context valueForKey:@"uiElement"];
	uiElement.value = newString;
}

- (void)odbEditor:(ODBEditor *)editor didCloseFileForString:(NSString *)newString context:(NSDictionary *)context; {
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