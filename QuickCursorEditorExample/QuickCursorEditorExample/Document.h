//
//  Document.h
//  QuickCursorEditorExample
//
//  Created by Jesse Grosjean on 6/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Document : NSDocument {
	NSString *loadingText;
    BOOL fromExternal;
	NSString *externalDisplayName;
	NSAppleEventDescriptor *externalSender;
	NSAppleEventDescriptor *externalToken;
}

@property (nonatomic, assign) IBOutlet NSTextView *textView;

@end
