//
//  TestTests.m
//  «PROJECTNAME»
//
//  Created by «FULLUSERNAME» on «DATE».
//  Copyright «ORGANIZATIONNAME» «YEAR» . All rights reserved.
//

#import "TestTests.h"


@implementation TestTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testBlocksWorkingAndBLifecycleLoaded {
	STAssertTrue([[[BExtensionRegistry sharedInstance] pluginFor:@"com.blocks.BLifecycle"] isLoaded], nil);
}

@end
