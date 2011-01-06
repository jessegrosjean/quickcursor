//
//  QCUIElement.m
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/28/07.
//  Copyright 2007 Hog Bay Software. All rights reserved.
//

#import "QCUIElement.h"


@implementation QCUIElement

#pragma mark Class Methods

+ (QCUIElement *)systemWideElement {
	static QCUIElement* systemWideQCUIElement = nil;
	if (!systemWideQCUIElement) {
		systemWideQCUIElement = [[QCUIElement alloc] initWithAXUIElementRef:AXUIElementCreateSystemWide()];
	}
	return systemWideQCUIElement;
}

+ (QCUIElement *)focusedElement {
	return [[self systemWideElement] valueForAttribute:(NSString *)kAXFocusedUIElementAttribute];
}

#pragma mark Init

- (id)initWithAXUIElementRef:(AXUIElementRef)aUIElementRef {
	if (self = [super init]) {
		uiElementRef = CFRetain(aUIElementRef);
	}
	return self;
}

- (void)dealloc {
	CFRelease(uiElementRef);
	[super dealloc];
}

#pragma mark Attributes

- (pid_t)processID {
	pid_t theAppPID = 0;
	if (AXUIElementGetPid(uiElementRef, &theAppPID) == kAXErrorSuccess) {
		return theAppPID;
	}
	return -1;
}

- (NSString *)processName {
	pid_t theAppPID = 0;
	ProcessSerialNumber theAppPSN = {0,0};
	NSString * theAppName = NULL;
	
	if (AXUIElementGetPid(uiElementRef, &theAppPID) == kAXErrorSuccess
		&& GetProcessForPID(theAppPID, &theAppPSN) == noErr
		&& CopyProcessName(&theAppPSN, (CFStringRef *)&theAppName) == noErr) {
		return theAppName;
	}
	
	return nil;
}

- (QCUIElement *)application {
	QCUIElement *uiElement = self;
	while (uiElement && ![[uiElement role] isEqualToString:(NSString *)kAXApplicationRole]) {
		uiElement = uiElement.parent;
	}
	return uiElement;
}

- (QCUIElement *)menuBar {
	return [[self application] valueForAttribute:(NSString *)kAXMenuBarAttribute];
}

- (QCUIElement *)topLevelUIElement {
	return [self valueForAttribute:(NSString *)kAXTopLevelUIElementAttribute];
}

- (QCUIElement *)window {
	return [self valueForAttribute:(NSString *)kAXWindowAttribute];
}

- (QCUIElement *)parent {
	return [self valueForAttribute:(NSString *)kAXParentAttribute];
}

- (NSArray *)children {
	return [self valueForAttribute:(NSString *)kAXChildrenAttribute];
}

- (NSString *)title {
	return [self valueForAttribute:(NSString *)kAXTitleAttribute];
}

- (NSString *)role {
	return [self valueForAttribute:(NSString *)kAXRoleAttribute];
}

- (BOOL)enabled {
	return [[self valueForAttribute:(NSString *)kAXEnabledAttribute] boolValue];
}

- (BOOL)isEditableTextArea {
	CFTypeRef focusedAttribute;
	AXError error = AXUIElementCopyAttributeValue(uiElementRef, kAXFocusedAttribute, &focusedAttribute);
	if (error != kAXErrorSuccess) {
		return NO;
	}
	if (!CFBooleanGetValue(focusedAttribute)) return NO;
	NSString *role = [self role];
	return [role isEqualToString:(NSString *)kAXTextAreaRole] || [role isEqualToString:(NSString *)kAXTextFieldRole] || [role isEqualToString:@"AXWebArea"];
}

- (id)value {
	return [self valueForAttribute:(NSString *)kAXValueAttribute];
}

- (BOOL)setValue:(id)value {
	return [self setValue:value forAttribute:(NSString *)kAXValueAttribute];
}

- (NSArray *)attributeNames {
	NSArray* attributeNames;
	AXUIElementCopyAttributeNames(uiElementRef, (CFArrayRef *)&attributeNames);
	return [(id)attributeNames autorelease];
}

- (id)valueForAttribute:(NSString *)attributeName {
	id result = nil;
	CFTypeRef theValue;
		
	AXError error = AXUIElementCopyAttributeValue(uiElementRef, (CFStringRef)attributeName, &theValue);
		
	if (error != kAXErrorSuccess) {
		return nil;
	}	
	
	if (AXValueGetType(theValue) == kAXValueCGPointType) {
		NSLog(@"unimplemented, should not be used by QuickCursor");
	} else if (AXValueGetType(theValue) == kAXValueCGSizeType) {
		NSLog(@"unimplemented, should not be used by QuickCursor");
	} else if (AXValueGetType(theValue) == kAXValueCGRectType) {
		NSLog(@"unimplemented, should not be used by QuickCursor");
	} else if (AXValueGetType(theValue) == kAXValueCFRangeType) {
		NSLog(@"unimplemented, should not be used by QuickCursor");
	} else if (CFGetTypeID(theValue) == CFBooleanGetTypeID()) {
		result = [NSNumber numberWithBool:theValue == kCFBooleanTrue];
	} else if (CFGetTypeID(theValue) == AXUIElementGetTypeID()) {
		result = [[[QCUIElement alloc] initWithAXUIElementRef:theValue] autorelease];
	} else if (CFGetTypeID(theValue) == CFArrayGetTypeID()) {
		CFIndex count = CFArrayGetCount(theValue);
		NSMutableArray *children = [NSMutableArray arrayWithCapacity:count];
		for (CFIndex i = 0; i < count; i++) {
			[children addObject:[[[QCUIElement alloc] initWithAXUIElementRef:CFArrayGetValueAtIndex(theValue, i)] autorelease]];
		}
		result = children;
	} else {
		result = [[[(id)theValue description] copy] autorelease];
	}
	
	CFRelease(theValue);
	
	return result;

/*	
	if (theValue) {
        if (AXValueGetType(theValue) != kAXValueIllegalType) {
			NSLog(@"unimplemented, should not be used by QuickCursor");
		} else if (CFGetTypeID(theValue) == CFArrayGetTypeID()) {
			NSLog(@"unimplemented, should not be used by QuickCursor");
		} else if (CFGetTypeID(theValue) == AXUIElementGetTypeID()) {
			return [[QCUIElement alloc] initWithAXUIElementRef:theValue];
		} else {
			return [(id)theValue description];
		}
	}
*/	
}

- (BOOL)setValue:(id)newValue forAttribute:(NSString *)attributeName {
	Boolean settableFlag = false;
	
	AXUIElementIsAttributeSettable(uiElementRef, (CFStringRef)attributeName, &settableFlag);
	
	if (!settableFlag) {
		NSLog(@"%@ is not a writeable attribute", attributeName, nil);
		return NO;
	}
	
	CFTypeRef theOldValue = NULL;
	CFTypeRef theNewValue = NULL;

	AXError error = AXUIElementCopyAttributeValue(uiElementRef, (CFStringRef)attributeName, &theOldValue);
	
	if (error != kAXErrorSuccess) {
		NSLog(@"error in AXUIElementCopyAttributeValue for attribute %@", attributeName);
		return NO;
	}
	
	if (theOldValue) {
        /*if (AXValueGetType(theOldValue) == kAXValueCGPointType) { // CGPoint
            CGPoint point;
            theNewValue = AXValueCreate(kAXValueCGPointType, (const void *)&point);
            if (theNewValue) {
                error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease(theNewValue);
            }
        } else if (AXValueGetType(theOldValue) == kAXValueCGSizeType) {	// CGSize
            CGSize size;
            theNewValue = AXValueCreate( kAXValueCGSizeType, (const void *)&size );
            if (theNewValue) {
                error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease( theNewValue );
            }
        } else if (AXValueGetType(theOldValue) == kAXValueCGRectType) {	// CGRect
            CGRect rect;
            theNewValue = AXValueCreate( kAXValueCGRectType, (const void *)&rect );
            if (theNewValue) {
                error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease( theNewValue );
            }
        } else if (AXValueGetType(theOldValue) == kAXValueCFRangeType) {	// CFRange
            CFRange range;
            theNewValue = AXValueCreate( kAXValueCFRangeType, (const void *)&range );
            if (theNewValue) {
                error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease( theNewValue );
            }
		} else*/ if (CFGetTypeID(theOldValue) == CFBooleanGetTypeID()) {
			if ([newValue boolValue]) {
				theNewValue = kCFBooleanTrue;
			} else {
				theNewValue = kCFBooleanFalse;
			}
			error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue);
		} else if ([(id)theOldValue isKindOfClass:[NSString class]]) { // NSString
            error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, newValue);
        } else if ([(id)theOldValue isKindOfClass:[NSValue class]]) { // NSValue
            error = AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, [NSNumber numberWithLong:[newValue intValue]] );
        }
		
		CFRelease(theOldValue);
	}
	
	if (error != kAXErrorSuccess) {
		NSLog(@"error in AXUIElementSetAttributeValue for attribute %@", attributeName);
		return NO;
	}
	
	return YES;
}

#pragma mark Process

- (BOOL)activateProcess {
	pid_t theAppPID = 0;
	ProcessSerialNumber theAppPSN = {0,0};
	
	if (AXUIElementGetPid(uiElementRef, &theAppPID) == kAXErrorSuccess && GetProcessForPID(theAppPID, &theAppPSN) == noErr && SetFrontProcess(&theAppPSN) == noErr) {
		return YES;
	}
	
	return NO;
}

- (QCUIElement *)menuItemWithShortCut:(NSString *)shortCut modifiers:(NSString *)modifiers searchingIn:(QCUIElement *)aMenu {
	if ([shortCut isEqualToString:[aMenu valueForAttribute:(NSString *)kAXMenuItemCmdCharAttribute]]) {
		if ([[aMenu valueForAttribute:(NSString *)kAXMenuItemCmdModifiersAttribute] isEqual:modifiers]) {
			return aMenu;
		}
	}
	
	for (QCUIElement *eachMenuItem in aMenu.children) {
		QCUIElement *eachSearched = [self menuItemWithShortCut:shortCut modifiers:modifiers searchingIn:eachMenuItem];
		if (eachSearched) {
			return eachSearched;
		}
	}
	
	return nil;
}

- (QCUIElement *)menuItemWithShortCut:(NSString *)shortCut modifiers:(NSString *)modifiers {
	QCUIElement *menuBar = [self menuBar];
	NSArray *menuBarItems = [menuBar children];
	QCUIElement *editMenu = [[[menuBarItems objectAtIndex:3] children] lastObject];
	QCUIElement *found = [self menuItemWithShortCut:shortCut modifiers:modifiers searchingIn:editMenu];
	
	if (!found) {
		found = [self menuItemWithShortCut:shortCut modifiers:modifiers searchingIn:menuBar];		
	}
	
	return found;
}

- (BOOL)performSelectAll {
	QCUIElement *selectAllMenuItem = [self menuItemWithShortCut:@"A" modifiers:@"0"];
	if ([selectAllMenuItem enabled]) {
		return AXUIElementPerformAction(selectAllMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess;
	} else {
		return NO;
	}
}

- (NSString *)performCopy:(BOOL)trySelectAllIfFail {
	QCUIElement *copyMenuItem = [self menuItemWithShortCut:@"C" modifiers:@"0"]; // seems neccesary to either refresh or wait for enabled status to update.
	
	if (copyMenuItem) {
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		NSUInteger changeCount = [pboard changeCount];
		NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
		
		if (AXUIElementPerformAction(copyMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
			while ([pboard changeCount] == changeCount) {
				if (([NSDate timeIntervalSinceReferenceDate] - startTime) > 0.3) {
					if (trySelectAllIfFail) {
						[self performSelectAll];
						return [self performCopy:NO];
					} else {
						return @"";
					}
				}
				usleep(100000);
			}
			return [pboard stringForType:NSPasteboardTypeString];
		}
		
		return @"";
	} else {
		return nil;
	}
}

- (NSString *)readString {	
	QCUIElement *copyMenuItem = [self menuItemWithShortCut:@"C" modifiers:@"0"];

	if (copyMenuItem) {
		if (![copyMenuItem enabled]) {
			if (![self performSelectAll]) {
				return NO;
			}
		}
		
		return [self performCopy:YES];
	}
		
	return nil;
}

- (BOOL)writeString:(NSString *)pasteString {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	
	[pboard clearContents];
	[pboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
	[pboard setString:pasteString forType:NSPasteboardTypeString];
	
	if (![self activateProcess]) {
		return NO;
	}

	QCUIElement *pasteMenuItem = [self menuItemWithShortCut:@"V" modifiers:@"0"];
	
	if ([pasteMenuItem enabled]) {
		if (AXUIElementPerformAction(pasteMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
			return YES;
		}
	}
	
	return NO;
}

@end
