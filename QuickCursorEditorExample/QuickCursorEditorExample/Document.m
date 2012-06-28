//
//  Document.m
//  QuickCursorEditorExample
//
//  Created by Jesse Grosjean on 6/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Document.h"
#import "ODBEditorSuite.h"


@implementation Document

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)close {
	if (fromExternal == YES) {
		[self sendClosedEventToExternalDocument];
	}
	[super close];
}

- (void)dealloc {
    [externalDisplayName release];
	[externalSender release];
	[externalToken release];
	[loadingText release];
	[super dealloc];
}

- (NSString *)windowNibName {
	return @"Document";
}

- (void)awakeFromNib {
	if (loadingText) {
		NSTextStorage *textStorage = [textView textStorage];
		[textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:loadingText];
		[loadingText release];
		loadingText = nil;
	}
}

@synthesize textView;

+ (BOOL)autosavesInPlace {
    return YES;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	if (text) {
		if (textView) {
			NSTextStorage *textStorage = [textView textStorage];
			[textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:text];
		} else {
			[loadingText autorelease];
			loadingText = [text retain];
		}
		return YES;
	} else {
		return NO;		
	}
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)outError {
	NSString *textContent = [self.textView.textStorage string];
	
	if ([textContent writeToURL:absoluteURL atomically:YES encoding:NSUTF8StringEncoding error:outError]) {
		if (saveOperation != NSAutosaveOperation && saveOperation != NSSaveToOperation) {
            if (fromExternal) {
                [self sendModifiedEventToExternalWithDocument:saveOperation == NSSaveAsOperation];
            }
        }
		return YES;
	}
	
	return NO;
}

- (void)sendModifiedEventToExternalWithDocument:(BOOL)fromSaveAs {
	NSURL *url = [self fileURL];
    NSData *data = [[url absoluteString] dataUsingEncoding:NSUTF8StringEncoding];	
	OSType signature = [externalSender typeCodeValue];
	NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor descriptorWithDescriptorType:typeApplSignature bytes:&signature length:sizeof(OSType)];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kODBEditorSuite eventID:kAEModifiedFile targetDescriptor:descriptor returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
	[event setParamDescriptor:[NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:data] forKeyword:keyDirectObject];
    
	if (externalToken) {
		[event setParamDescriptor:externalToken forKeyword:keySenderToken];
	}
	if (fromSaveAs) {
		[descriptor setParamDescriptor:[NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:data] forKeyword:keyNewLocation];
		fromExternal = NO;
	}
	
	AppleEvent *eventPointer = (AEDesc *)[event aeDesc];
	
	if (eventPointer) {
		OSStatus errorStatus = AESendMessage(eventPointer, NULL, kAENoReply, kAEDefaultTimeout);
		if (errorStatus != noErr) {
			NSBeep();
		}
	}
}

- (void)sendClosedEventToExternalDocument {
	NSURL *url = [self fileURL];
    NSData *data = [[url absoluteString] dataUsingEncoding:NSUTF8StringEncoding];
	OSType signature = [externalSender typeCodeValue];
	NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor descriptorWithDescriptorType:typeApplSignature bytes:&signature length:sizeof(OSType)];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kODBEditorSuite eventID:kAEClosedFile targetDescriptor:descriptor returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
	[event setParamDescriptor:[NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:data] forKeyword:keyDirectObject];
	if (externalToken) {
		[event setParamDescriptor:externalToken forKeyword:keySenderToken];
	}
	
	AppleEvent *eventPointer = (AEDesc *)[event aeDesc];
	
	if (eventPointer) {
		OSStatus errorStatus = AESendMessage(eventPointer, NULL, kAENoReply, kAEDefaultTimeout);
		if (errorStatus != noErr) {
			NSBeep();
		}
	}
}

@end
