//
//  QCUserInterfaceController.h
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/28/07.
//  Copyright 2007 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Blocks/Blocks.h>


@class QCUIElement;

@interface QCUserInterfaceController : NSObject {
	NSStatusItem *quickCursorStatusItem;
	NSMutableSet *quickCursorSessionQCUIElements;
}

#pragma mark Class Methods

+ (id)sharedInstance;

#pragma mark QuickCursor Edits

- (void)beginQuickCursorEdit:(id)sender;

@end
