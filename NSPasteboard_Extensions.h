//
//  NSPasteboard_Extensions.h
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSPasteboard (Extensions)

- (NSDictionary *)savePasteboardContents;
- (void)restorePasteboardContents:(NSDictionary *)dict;

@end
