//
//  NSLoginItems.h
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

#import <Cocoa/Cocoa.h>


// This singleton class handles the state of the running app in the users login items list (called
// Session Login items by the LSSharedFileList API).

// It sets up an observer of the Session Login List and keeps track if the user changes the state
// in System Preferences or any other outside app. The property isAppInSessionLoginList will be updated 
// when that happens.

// isAppInSessionLoginList is only meant to represent the state, so do not set it yourself. 
// Use the four instance methods for that. When changing the state, the state is re-read from LSSharedFileList 
// so isAppInSessionLoginList should never not represent the current state.

// Since there is no way to recover or re-apply a state change there are no returned errors. If it doesn't
// work then isAppInSessionLoginList will not be updated.

// NOTE: The LSSharedFileList API is only documented in the header file at:
// file://localhost/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Headers/LSSharedFileList.h



@interface BBAppSessionLoginState : NSObject
{
    LSSharedFileListRef _sessionLoginItemsList;
    NSString           *_appPath;
    
    BOOL                isAppInSessionLoginList;
}
// this is the latest state of whether the app is in the login list
// observe it for KVC changes, setting it will have no effect, use the methods below
@property (assign) BOOL isAppInSessionLoginList;


// designated init/access of singleton
+ (id)sharedController;


- (void)toggleAppSessionLoginListState;
- (void)setAppSessionLoginListState:(BOOL)state;

- (void)removeAppFromSessionLoginList;
- (void)addAppToSessionLoginList;

@end