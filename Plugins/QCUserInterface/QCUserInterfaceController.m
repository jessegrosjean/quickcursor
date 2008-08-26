//
//  QCUserInterfaceController.m
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
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
		[[ODBEditor sharedODBEditor] editString:value options:[NSDictionary dictionaryWithObject:editorCustomPath forKey:ODBEditorCustomPathKey] forClient:self context:context];
	} else {
		NSBeep();
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
	
	NSStatusBar *systemStatusBar = [NSStatusBar systemStatusBar];
    quickCursorStatusItem = [systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    [quickCursorStatusItem setTitle:BLocalizedString(@"Q",@"")];
	[quickCursorStatusItem setTarget:self];
	[quickCursorStatusItem setAction:@selector(beginQuickCursorEdit:)];
    [quickCursorStatusItem setHighlightMode:YES];
//    [quickCursorStatusItem setMenu:[[[BUserInterfaceController sharedInstance] menuControllerForMenuExtensionPoint:@"com.hogbaysoftware.quickcursor.menus.statusMenu"] menu]];
}

@end
