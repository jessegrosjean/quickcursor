//
//  main.m
//  «PROJECTNAME»
//
//  Created by «FULLUSERNAME» on «DATE».
//  Copyright «ORGANIZATIONNAME» «YEAR» . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Blocks/Blocks.h>


int main(int argc, char *argv[]) {
	[[BExtensionRegistry sharedInstance] loadMainExtension];
    return NSApplicationMain(argc,  (const char **) argv);
}