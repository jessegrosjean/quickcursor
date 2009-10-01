//
//  NSLoginItems.m
//
//  Created by BrotherBard on 4/18/09.
//  Copyright 2009 BrotherBard <nkinsinger at earthlink dot net>. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright notice, this
//       list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright notice,
//       this list of conditions and the following disclaimer in the documentation 
//       and/or other materials provided with the distribution.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "BBAppSessionLoginState.h"

// Private
@interface BBAppSessionLoginState()

- (LSSharedFileListItemRef)itemRefForApp;
- (void)updateLoginItemState;

@end



@implementation BBAppSessionLoginState

@synthesize isAppInSessionLoginList;


- (void)setIsAppInSessionLoginList:(BOOL)isInList {
	if (isAppInSessionLoginList != isInList) {
		isAppInSessionLoginList = isInList;
		if (isInList) {
			[self addAppToSessionLoginList];
		} else {
			[self removeAppFromSessionLoginList];
		}
	}
}

// When something changes I get six calls to this method. The first two have the same seed and 
// the last four do too. I'm not sure if it is something wierd on my computer, but I compare the
// seed to the previous one to stop updating the login state too often.
static void SharedFileListChanged(LSSharedFileListRef list, void *context)
{
    static UInt32 previousSeed = 0;
    
    // there are other types of lists, so make sure we are just looking at the Session Login list
    LSSharedFileListRef sessionLoginList = (LSSharedFileListRef)context;
    
    if (list == sessionLoginList) {
        UInt32 seed = LSSharedFileListGetSeedValue(list);
        if (seed > previousSeed) {
            [[BBAppSessionLoginState sharedController] updateLoginItemState];
            previousSeed = seed;
        }
    }
}


+ (id)sharedController
{
    static BBAppSessionLoginState *sharedController = nil;
    if (!sharedController)
        sharedController = [[self alloc] init];
    
    return sharedController;
}


- (id)init
{
    self = [super init];
    if(!self) return nil;
    
    _sessionLoginItemsList = LSSharedFileListCreate(kCFAllocatorDefault,               // inAllocator
													kLSSharedFileListSessionLoginItems, // inListType
													NULL);                              // listOptions
    if(!_sessionLoginItemsList) {
        [self release];
        return nil;
    } 
    
    LSSharedFileListAddObserver(_sessionLoginItemsList,                 // inList
                                [[NSRunLoop mainRunLoop] getCFRunLoop], // inRunloop
                                kCFRunLoopDefaultMode,                  // inRunloopMode
                                SharedFileListChanged,                  // callback
                                _sessionLoginItemsList);                // context
    
    _appPath = [[NSBundle mainBundle] bundlePath];
    [self updateLoginItemState];
    
    return self;
}


- (void)dealloc
{
    if (_sessionLoginItemsList) {
        LSSharedFileListRemoveObserver(_sessionLoginItemsList,                 // inList
                                       [[NSRunLoop mainRunLoop] getCFRunLoop], // inRunloop
                                       kCFRunLoopDefaultMode,                  // inRunloopMode
                                       SharedFileListChanged,                  // callback
                                       _sessionLoginItemsList);                // context
        
        CFRelease(_sessionLoginItemsList);
    }
    
    [super dealloc];
}


- (LSSharedFileListItemRef)itemRefForApp
{
    UInt32 seed;
    NSArray *items = [(NSArray *)LSSharedFileListCopySnapshot(_sessionLoginItemsList, &seed) autorelease];
    
    for (id item in items) {
        LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
        
        NSURL *theURL;
        LSSharedFileListItemResolve(itemRef,                            // inItem
                                    kLSSharedFileListNoUserInteraction, // inFlags
                                    (CFURLRef*)&theURL,                 // outURL
                                    NULL);                              // outFSRef
        [theURL autorelease];
        
        if ([_appPath isEqualToString:[theURL path]])
            return itemRef;
    }
    
    return NULL;
}


- (void)updateLoginItemState
{
    BOOL currentState = [self itemRefForApp] ? YES : NO;
    if (self.isAppInSessionLoginList != currentState)
    	isAppInSessionLoginList = currentState;
}


- (void)toggleAppSessionLoginListState
{
    if (isAppInSessionLoginList)
        [self removeAppFromSessionLoginList];
    else
        [self addAppToSessionLoginList];
}


- (void)setAppSessionLoginListState:(BOOL)state
{
    if (state)
        [self addAppToSessionLoginList];
    else
        [self removeAppFromSessionLoginList];
}


- (void)removeAppFromSessionLoginList
{
    LSSharedFileListItemRef itemRef = [self itemRefForApp];
    
    if (itemRef) {
        OSStatus error = LSSharedFileListItemRemove(_sessionLoginItemsList, itemRef);
        if (error != noErr)
            NSLog(@"Failed to remove App from Session Login Items");
    }
    
    [self updateLoginItemState];
}


- (void)addAppToSessionLoginList
{
    LSSharedFileListItemRef itemRef = [self itemRefForApp];
    
    if (!itemRef) {
        // I believe the default is to not Hide the app, but I'm not really sure because the 
        // kLSSharedFileListItemHidden property is not read corretly by LSSharedFileListItemCopyProperty.
        // I'm just setting it here to have a default value.
        NSDictionary* propertiesToSet = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                                    forKey:(id)kLSSharedFileListItemHidden];
        NSURL *url = [NSURL fileURLWithPath:_appPath];
        NSLog(@"%@", url);
        
        itemRef = LSSharedFileListInsertItemURL(_sessionLoginItemsList,           // inList
                                                kLSSharedFileListItemLast,        // insertAfterThisItem
                                                NULL,                             // inDisplayName - NULL = will use app name
                                                NULL,                             // inIconRef     - NULL = will use app icon
                                                (CFURLRef)url,                    // inURL
                                                (CFDictionaryRef)propertiesToSet, // inPropertiesToSet
                                                NULL);                            // inPropertiesToClear
        
        if (itemRef)
            CFRelease(itemRef);
        else
            NSLog(@"Failed to add App to Session Login Items");
    }
    
    [self updateLoginItemState];
}

@end