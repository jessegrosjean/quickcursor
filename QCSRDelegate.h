//
//  QCSRDelegate.h
//  QuickCursor
//
//  Created by Ryan Graciano on 12/8/11.
//  Copyright (c) 2011. All rights reserved.
//
//  One shortcut recorder control is used by each Edit and Insert.
//  This class serves as a delegate for the SRRecorderControl
//  and remembers which type of action (edit/ins) it's delegating.

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>
#import "QCAppDelegate.h"

@class QCAppDelegate;

@interface QCSRDelegate : NSObject {
    NSPopUpButton *targetBtn;
    QCAppDelegate *owner;
}

- (id)initWithOwnerAndBtn:(id)newOwner popUpButton:(NSPopUpButton *)popUpButton;

@end
