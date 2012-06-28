//
//  DocumentController.m
//  QuickCursorEditorExample
//
//  Created by Jesse Grosjean on 6/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DocumentController.h"
#import "ODBEditorSuite.h"
#import "Document.h"

@interface Document (DocumentControllerPrivate)
- (void)setExternalDisplayName:(NSString *)aString externalSender:(NSAppleEventDescriptor *)aSender externalToken:(NSAppleEventDescriptor *)aToken;
@end

@implementation Document (DocumentControllerPrivate)

- (void)setExternalDisplayName:(NSString *)aString externalSender:(NSAppleEventDescriptor *)aSender externalToken:(NSAppleEventDescriptor *)aToken {
    fromExternal = YES;
    externalDisplayName = [aString retain];
    externalSender = [aSender retain];
    externalToken = [aToken retain];
}

@end

@implementation DocumentController

- (void)openDocumentWithContentsOfURL:(NSURL *)url display:(BOOL)displayDocument completionHandler:(void (^)(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error))completionHandler {
    NSAppleEventDescriptor *currentAppleEvent = [[[[NSAppleEventManager sharedAppleEventManager] currentAppleEvent] copy] autorelease];
    NSAppleEventDescriptor *externalSender = nil;
    NSAppleEventDescriptor *externalToken = nil;
    NSString *externalDisplayName = nil;
    __block BOOL fromExternal = NO;
    
    if ([currentAppleEvent paramDescriptorForKeyword:keyFileSender]) {
        fromExternal = YES;
    }
	
    NSAppleEventDescriptor *keyAEPropDataDescriptor = nil;
    BOOL isKeyAEPropData = NO;
	
    if (!fromExternal && [currentAppleEvent paramDescriptorForKeyword:keyAEPropData]) {
        keyAEPropDataDescriptor = [currentAppleEvent paramDescriptorForKeyword:keyAEPropData];
        isKeyAEPropData = YES;
        
        if ([keyAEPropDataDescriptor paramDescriptorForKeyword:keyFileSender]) {
            fromExternal = YES;
        }
    }
    
    if (fromExternal) {
        if (!isKeyAEPropData) {
            externalDisplayName = [[currentAppleEvent paramDescriptorForKeyword:keyFileCustomPath] stringValue];
        } else {
            externalDisplayName = [[keyAEPropDataDescriptor paramDescriptorForKeyword:keyFileCustomPath] stringValue];
        }
        
        if (!isKeyAEPropData) {
            externalSender = [currentAppleEvent paramDescriptorForKeyword:keyFileSender];
        } else {
            externalSender = [keyAEPropDataDescriptor paramDescriptorForKeyword:keyFileSender];
        }
        
        if (!isKeyAEPropData) {
            externalToken = [currentAppleEvent paramDescriptorForKeyword:keyFileSenderToken];
        } else {
            externalToken = [currentAppleEvent paramDescriptorForKeyword:keyFileSenderToken];
        }
    }    
    
    if (fromExternal) {
        [NSObject cancelPreviousPerformRequestsWithTarget:[NSApp delegate] selector:@selector(openUntitledFileIfNotCancled) object:nil];
    }
	
    [super openDocumentWithContentsOfURL:url display:displayDocument completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
        if (fromExternal) {
            [(id)document setExternalDisplayName:externalDisplayName externalSender:externalSender externalToken:externalToken];
        }
        completionHandler(document, documentWasAlreadyOpen, error);
    }];
}

@end