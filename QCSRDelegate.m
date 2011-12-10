//
//  QCSRDelegate.m
//  QuickCursor
//
//  Created by Ryan Graciano on 12/8/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "QCSRDelegate.h"
#import "PTHotKey.h"
#import "QCAppDelegate.h"

@implementation QCSRDelegate

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {
    signed short code = newKeyCombo.code;
	unsigned int flags = [aRecorder cocoaToCarbonFlags:newKeyCombo.flags];
	PTKeyCombo *keyCombo = [[[PTKeyCombo alloc] initWithKeyCode:code modifiers:flags] autorelease];

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *userDefaultString = [QCAppDelegate makeUserDefaultString:[[targetBtn selectedItem] representedObject]];
	[userDefaults setObject:[keyCombo plistRepresentation] forKey:userDefaultString];
    
	[owner updateHotKeys:userDefaultString addingKeyCombo:keyCombo usingRecorder:aRecorder];
	[userDefaults synchronize];
}

- (id)initWithOwnerAndBtn:(id)newOwner popUpButton:(NSPopUpButton *)popUpButton {
    self = [super init];
    
    if (self) {
        owner = newOwner;
        [owner retain];
        
        targetBtn = popUpButton;
        [targetBtn retain];
    }
    return self;
}

- (void)dealloc {
    [owner release];
    [targetBtn release];
    [super dealloc];
}

@end
