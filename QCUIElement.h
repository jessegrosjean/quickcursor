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

@property(readonly) NSString *processName; 
@property(readonly) QCUIElement *application;
@property(readonly) QCUIElement *topLevelUIElement;
@property(readonly) QCUIElement *window;
@property(readonly) QCUIElement *parent;
@property(readonly) NSString *title; 
@property(readonly) NSString *role;
@property(retain) id value;

@property(readonly) NSArray *attributeNames;
- (id)valueForAttribute:(NSString *)attributeName;
- (BOOL)setValue:(id)newValue forAttribute:(NSString *)attributeName;
	
@end
