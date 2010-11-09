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
        if (AXValueGetType(theOldValue) == kAXValueCGPointType) { // CGPoint
            CGPoint point;
            theNewValue = AXValueCreate(kAXValueCGPointType, (const void *)&point);
            if (theNewValue) {
                AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease(theNewValue);
            }
        } else if (AXValueGetType(theOldValue) == kAXValueCGSizeType) {	// CGSize
            CGSize size;
            theNewValue = AXValueCreate( kAXValueCGSizeType, (const void *)&size );
            if (theNewValue) {
                AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease( theNewValue );
            }
        } else if (AXValueGetType(theOldValue) == kAXValueCGRectType) {	// CGRect
            CGRect rect;
            theNewValue = AXValueCreate( kAXValueCGRectType, (const void *)&rect );
            if (theNewValue) {
                AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease( theNewValue );
            }
        } else if (AXValueGetType(theOldValue) == kAXValueCFRangeType) {	// CFRange
            CFRange range;
            theNewValue = AXValueCreate( kAXValueCFRangeType, (const void *)&range );
            if (theNewValue) {
                AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, theNewValue );
                CFRelease( theNewValue );
            }
        } else if ([(id)theOldValue isKindOfClass:[NSString class]]) { // NSString
            AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, newValue);
        } else if ([(id)theOldValue isKindOfClass:[NSValue class]]) { // NSValue
            AXUIElementSetAttributeValue(uiElementRef, (CFStringRef)attributeName, [NSNumber numberWithLong:[newValue intValue]] );
        }
		
		CFRelease(theOldValue);
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

/*
 How to send key type directly.
 
CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
CGEventRef pasteCommandDown = CGEventCreateKeyboardEvent(source, (CGKeyCode)9, YES);
CGEventSetFlags(pasteCommandDown, kCGEventFlagMaskCommand);
CGEventRef pasteCommandUp = CGEventCreateKeyboardEvent(source, (CGKeyCode)9, NO);

CGEventPost(kCGAnnotatedSessionEventTap, pasteCommandDown);
CGEventPost(kCGAnnotatedSessionEventTap, pasteCommandUp);

CFRelease(pasteCommandUp);
CFRelease(pasteCommandDown);
CFRelease(source);
*/

- (void)restoreSavedString:(NSString *)aSavedString {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pboard setString:aSavedString forType:NSStringPboardType];
}

- (NSString *)readString {
	NSArray *menuBarItems = [[self menuBar] children];
	QCUIElement *editMenu = [[[menuBarItems objectAtIndex:3] children] lastObject];

	// Select All
	for (QCUIElement *eachMenuItem in editMenu.children) {
		NSString *shortcut = [eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdCharAttribute];
		if ([shortcut isEqualToString:@"A"]) {
			if ([[eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdModifiersAttribute] isEqual:@"0"]) {
				if (!AXUIElementPerformAction(eachMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
					return nil;
				}
			}
		}
	}

	// Copy
	for (QCUIElement *eachMenuItem in editMenu.children) {
		NSString *shortcut = [eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdCharAttribute];
		
		if ([shortcut isEqualToString:@"C"]) {
			if ([[eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdModifiersAttribute] isEqual:@"0"]) {
				NSPasteboard *pboard = [NSPasteboard generalPasteboard];
				NSString *savedString = [pboard stringForType:NSStringPboardType];
				NSString *copiedString = nil;
				
				if (AXUIElementPerformAction(eachMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
					if (AXUIElementPerformAction(eachMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
						copiedString = [pboard stringForType:NSStringPboardType];
					}
				}
				
				[self performSelector:@selector(restoreSavedString:) withObject:savedString afterDelay:1];
				
				return copiedString;
			}
		}
	}
	
	return nil;
}

- (BOOL)writeString:(NSString *)pasteString {
	NSArray *menuBarItems = [[self menuBar] children];
	QCUIElement *editMenu = [[[menuBarItems objectAtIndex:3] children] lastObject];
	
	if (![self activateProcess]) {
		return NO;
	}
	
	// Select All
	for (QCUIElement *eachMenuItem in editMenu.children) {
		NSString *shortcut = [eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdCharAttribute];
		if ([shortcut isEqualToString:@"A"]) {
			if ([[eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdModifiersAttribute] isEqual:@"0"]) {
				if (!AXUIElementPerformAction(eachMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
					return NO;
				}
			}
		}
	}
	
	// Paste
	for (QCUIElement *eachMenuItem in editMenu.children) {
		NSString *shortcut = [eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdCharAttribute];
		
		if ([shortcut isEqualToString:@"V"]) {
			if ([[eachMenuItem valueForAttribute:(NSString *)kAXMenuItemCmdModifiersAttribute] isEqual:@"0"]) {
				NSPasteboard *pboard = [NSPasteboard generalPasteboard];
				NSString *savedString = [pboard stringForType:NSStringPboardType];
				BOOL result = NO;
				
				[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
				[pboard setString:pasteString forType:NSStringPboardType];
				
				if (AXUIElementPerformAction(eachMenuItem->uiElementRef, kAXPressAction) == kAXErrorSuccess) {
					result = YES;
				}
				
				[self performSelector:@selector(restoreSavedString:) withObject:savedString afterDelay:1];
				
				return result;
			}
		}
	}
	
	return NO;
}

@end
