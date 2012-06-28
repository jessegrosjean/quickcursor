//
//  ApplicationDelegate.m
//  QuickCursorEditorExample
//
//  Created by Jesse Grosjean on 6/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ApplicationDelegate.h"
#import "DocumentController.h"


@implementation ApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [DocumentController sharedDocumentController];
}

static NSUInteger openUntitledFileIfNotCancledCount = 0;

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    openUntitledFileIfNotCancledCount = 0;
    [self performSelector:@selector(openUntitledFileIfNotCancled) withObject:nil afterDelay:0]; // Delay for ODB Editor case
    return NO;
}

- (void)openUntitledFileIfNotCancled {
    if (openUntitledFileIfNotCancledCount < 2) {
        // Big ugly hack... otherwise on startup (in QuickCursor case) we end up opening an empy document.
		// So instead wait a bit (2 cycles of performSelector) for ODB to cancel us... if no cancel then open untitled document.
        [self performSelector:@selector(openUntitledFileIfNotCancled) withObject:nil afterDelay:0];
        openUntitledFileIfNotCancledCount++;
        return;
    }
    [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
}

@end
