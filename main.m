//
//  main.m
//  QuickCursor
//
//  Created by Jesse Grosjean on 11/11/10.
//  Copyright 2010 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "check.h"

int main(int argc, char *argv[])
{
	if (firstCheck() && secondCheck(nil)) {
		return NSApplicationMain(argc,  (const char **) argv);
	}
}
