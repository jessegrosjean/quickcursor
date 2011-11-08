//
//  NSPasteboard_Extensions.m
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSPasteboard_Extensions.h"

@implementation NSPasteboard (Extensions)

- (NSDictionary *)savePasteboardContents {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *each in [self types]) {
        NSData *data = [self dataForType:each];
        if (data) {
            [result setObject:data forKey:each]; 
        }
    }
    
    return result;
}

- (void)restorePasteboardContents:(NSDictionary *)dict {
    [self clearContents];
    for (NSString *each in [dict keyEnumerator]) {
        [self setData:[dict objectForKey:each] forType:each];
    }
}

@end
