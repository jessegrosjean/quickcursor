//
//  CrashReporter.h
//  Documents
//
//  Created by Jesse Grosjean on 9/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CrashReporter : NSWindowController {
    IBOutlet NSTextField *titleTextField;
    IBOutlet NSTextField *statusMessageTextField;
    IBOutlet NSTextView *problemCommentsTextView;
    IBOutlet NSTextView *problemDetailsTextView;
    IBOutlet NSButton *sendReportButton;
    IBOutlet NSProgressIndicator *statusProgressIndicator;
	
	NSMutableDictionary *crashReport;
}

#pragma mark class methods

+ (id)sharedInstance;

#pragma mark actions

- (IBAction)check:(id)sender;
- (IBAction)sendReport:(id)sender;
- (IBAction)ignore:(id)sender;

@end

extern NSString *CrashReporterLastCheckDateDefaultsKey;
