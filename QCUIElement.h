//
//  QCUIElement.h
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/28/07.
//  Copyright 2007 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface QCUIElement : NSObject {
    AXUIElementRef uiElementRef;
}

#pragma mark Class Methods

+ (QCUIElement *)systemWideElement;
+ (QCUIElement *)focusedElement;

#pragma mark Init

- (id)initWithAXUIElementRef:(AXUIElementRef)aUIElementRef;

#pragma mark Attributes

@property(readonly) pid_t processID; 
@property(readonly) NSString *processName; 
@property(readonly) QCUIElement *application;
@property(readonly) QCUIElement *menuBar;
@property(readonly) QCUIElement *topLevelUIElement;
@property(readonly) QCUIElement *window;
@property(readonly) QCUIElement *parent;
@property(readonly) NSArray *children;
@property(readonly) NSString *title; 
@property(readonly) NSString *role;

- (id)value;
- (BOOL)setValue:(id)value;
@property(readonly) NSArray *attributeNames;
- (id)valueForAttribute:(NSString *)attributeName;
- (BOOL)setValue:(id)newValue forAttribute:(NSString *)attributeName;

#pragma mark Actions

- (BOOL)activateProcess;
- (NSString *)readString;
- (BOOL)writeString:(NSString *)pasteString;

@end
