//
//  QCUserInterfaceController.m
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/28/07.
//  Copyright 2007 Hog Bay Software. All rights reserved.
//

#import "QCUserInterfaceController.h"
#import "QCUIElement.h"
#import "ODBEditor.h"


@implementation QCUserInterfaceController

#pragma mark Class Methods

+ (id)sharedInstance {
    static id sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

#pragma mark Init

- (id)init {
	if (self = [super init]) {
		quickCursorSessionQCUIElements = [[NSMutableSet alloc] init];
	}
	return self;
}

#pragma mark QuickCursor Edits

- (void)beginQuickCursorEdit:(id)sender {	
	QCUIElement *focusedElement = [QCUIElement focusedElement];

	id value = focusedElement.value;
	
	if ([value isKindOfClass:[NSString class]]) {
		NSDictionary *context = [NSDictionary dictionaryWithObject:focusedElement forKey:@"uiElement"];
		NSString *processName = [focusedElement processName];
		NSString *windowTitle = focusedElement.window.title;
		NSString *editorCustomPath = [NSString stringWithFormat:@"%@ – %@", processName, windowTitle];		
		[[ODBEditor sharedODBEditor] setEditorBundleIdentifier:[sender representedObject]];
		[[ODBEditor sharedODBEditor] editString:value options:[NSDictionary dictionaryWithObject:editorCustomPath forKey:ODBEditorCustomPathKey] forClient:self context:context];
	} else {
		[[NSAlert alertWithMessageText:BLocalizedString(@"Could not edit text", nil)
						 defaultButton:BLocalizedString(@"OK", nil)
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:BLocalizedString(@"QuickCursor could not find any text to edit. Make sure that a text view has keyboard focus, and then try again.", nil)] runModal];
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

#pragma mark Lifecycle Callbacks

- (void)applicationDidFinishLaunching {
    if (!AXAPIEnabled()) {
		NSString *message = BLocalizedString(@"QuickCursor requires that the Accessibility API be enabled. Would you like to launch System Preferences so that you can turn on \"Enable access for assistive devices\".", nil);
        NSUInteger result = NSRunAlertPanel(message, @"", BLocalizedString(@"OK", nil), BLocalizedString(@"Quit QuickCursor", nil), BLocalizedString(@"Cancel", nil));
        
        switch (result) {
            case NSAlertDefaultReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
                
            case NSAlertAlternateReturn:
                [NSApp terminate:self];
                return;
        }
    }

    quickCursorStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [quickCursorStatusItem setTitle:BLocalizedString(@"Q",@"")];
	[quickCursorStatusItem setTarget:self];
    [quickCursorStatusItem setHighlightMode:YES];

	NSMenu *quickCursorMenu = [[NSMenu alloc] init];
	
	NSMenuItem *aboutMenuItem = [[NSMenuItem alloc] initWithTitle:BLocalizedString(@"About", nil) action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
	[aboutMenuItem setTarget:NSApp];
	[quickCursorMenu addItem:aboutMenuItem];

	[quickCursorMenu addItem:[NSMenuItem separatorItem]];

	[quickCursorMenu addItemWithTitle:BLocalizedString(@"Edit in...", nil) action:NULL keyEquivalent:@""];
	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	BExtensionPoint *extensionPoint = [[BExtensionRegistry sharedInstance] extensionPointFor:@"com.hogbaysoftware.quickcursor.QCUserInterface.editor"];
	NSMutableArray *editInMenuItems = [NSMutableArray array];
	
	for (BConfigurationElement *each in [extensionPoint configurationElementsNamed:@"editor"]) {
		NSString *bundleID = [each attributeForKey:@"bundle"];
		NSString *bundlePath = [workspace absolutePathForAppBundleWithIdentifier:bundleID];
		
		if (bundlePath) {
			NSMenuItem *eachMenuItem = [[NSMenuItem alloc] initWithTitle:[[NSBundle bundleWithPath:bundlePath] objectForInfoDictionaryKey:@"CFBundleName"] action:@selector(beginQuickCursorEdit:) keyEquivalent:@""];
			[eachMenuItem setTarget:self];
			[eachMenuItem setRepresentedObject:bundleID];
			[eachMenuItem setIndentationLevel:1];
			[eachMenuItem setImage:[workspace iconForFile:bundlePath]];
			[eachMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask | NSCommandKeyMask | NSControlKeyMask];
			[editInMenuItems addObject:eachMenuItem];
		} else {
			BLogInfo([NSString stringWithFormat:@"failed to find edit in application for bundle id %@", bundleID]);
		}
	}

	[editInMenuItems sortUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES]]];
	
	for (NSMenuItem *each in editInMenuItems) {
		[quickCursorMenu addItem:each];
	}
	
	[quickCursorMenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:BLocalizedString(@"Quit QuickCursor", nil) action:@selector(terminate:) keyEquivalent:@""];
	[quitMenuItem setTarget:NSApp];
	[quickCursorMenu addItem:quitMenuItem];

	[quickCursorStatusItem setMenu:quickCursorMenu];
}

@end
