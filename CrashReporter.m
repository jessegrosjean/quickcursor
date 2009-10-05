//
//  CrashReporter.m
//  Documents
//
//  Created by Jesse Grosjean on 9/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CrashReporter.h"


@implementation CrashReporter

#pragma mark class methods

+ (id)sharedInstance {
    static id sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

#pragma dealloc

- (id)init {
    if (self = [super initWithWindowNibName:@"CrashReporterWindow"]) {
		crashReport = [[NSMutableDictionary dictionary] retain];
    }
    return self;
}

- (void)dealloc {
	[crashReport release];
    [super dealloc];
}

#pragma awake from nib like methods

- (void)awakeFromNib {
	[statusMessageTextField setStringValue:@""];
	[[self window] setLevel:NSFloatingWindowLevel];
}

#pragma mark accessors

- (NSString *)latestCrashPath {
	NSString *name = [[NSProcessInfo processInfo] processName];
	NSString *crashLogPrefix = [NSString stringWithFormat: @"%@_", name];
	NSString *crashLogSuffix = @".crash";
	NSString *crashReporterFolder = [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:crashReporterFolder];
	NSDate *currentDate = nil;
	NSString *foundName = nil;
	NSDate *foundDate = nil;
	
	for (NSString *currentName in enumerator) {		
		if ([currentName hasPrefix:crashLogPrefix] && [currentName hasSuffix:crashLogSuffix]) {
			currentDate = [[enumerator fileAttributes] fileModificationDate];
			if (foundName) {
				if ([currentDate isGreaterThan:foundDate]) {
					foundName = currentName;
					foundDate = currentDate;
				}
			} else {
				foundName = currentName;
				foundDate = currentDate;
			}
		}
	}
	
	if (!foundName) {
		return nil;
	} else {
		return [crashReporterFolder stringByAppendingPathComponent:foundName];
	}
}

- (void)setStatusMessage:(NSString *)message {
    if ([message length]) {
		[statusProgressIndicator startAnimation:nil];
    } else {
		[statusProgressIndicator stopAnimation:nil];
    }
    
    [statusMessageTextField setStringValue:message];
    [statusMessageTextField display];
}

#pragma mark actions

- (IBAction)check:(id)sender {
	@try {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *latestCrashPath = [self latestCrashPath];
		NSDictionary *lastCrashFileAttributes = [fileManager fileAttributesAtPath:latestCrashPath traverseLink:YES];
		
		if (lastCrashFileAttributes) {
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSDate *lastCheckDate = [defaults objectForKey:CrashReporterLastCheckDateDefaultsKey];
			NSDate *lastCrashDate = [lastCrashFileAttributes fileModificationDate];
			
			if (lastCheckDate == nil || [lastCheckDate isLessThan:lastCrashDate]) {
				[defaults setObject:lastCrashDate forKey:CrashReporterLastCheckDateDefaultsKey];
				[defaults synchronize];
				
				NSWindow *window = [self window];
				NSString *processName = [[NSProcessInfo processInfo] processName];
				NSMutableString *crashLogs = [NSMutableString string];
				
				[statusProgressIndicator setUsesThreadedAnimation:YES];
				
				[window setTitle:[NSString stringWithFormat:[window title], processName]];
				[titleTextField setStringValue:[NSString stringWithFormat:[titleTextField stringValue], processName]];
				
				[window center];
				[window orderFront:self];
				
				NSString *crashLog = [NSString stringWithContentsOfFile:latestCrashPath encoding:NSUTF8StringEncoding error:NULL];
				if ([crashLog length] > 0) {
					[crashLogs appendString:crashLog];
				}
				
				[[problemDetailsTextView textStorage] replaceCharactersInRange:NSMakeRange(0, 0) withString:crashLogs];
				
				[crashReport setObject:crashLogs forKey:@"log"];
				[crashReport setObject:@"jesse@hogbaysoftware.com" forKey:@"email"];
			}
		}
	} @catch (NSException * e) {
		NSLog(@"Exception while checking for crash reports %@", [e description]);
	}
}

- (IBAction)sendReport:(id)sender {
	NSString *crashReportURLString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CrashReporterPostToURL"];
	
	if (!crashReportURLString) {
		NSRunAlertPanel(NSLocalizedString(@"Unable to send crash report", nil),
						NSLocalizedString(@"No value has been set for the CrashReporterPostToURL key in the applications Info.plist. Please contact the applictions developer.", nil),
						NSLocalizedString(@"OK", nil), 
						nil,
						nil);
		return;
	}
		
    [crashReport setObject:[[problemCommentsTextView textStorage] string] forKey:@"description"];
    
    NSMutableString *reportString = [[[NSMutableString alloc] init] autorelease];
    NSEnumerator *enumerator = [[crashReport allKeys] objectEnumerator];
    NSString *key;
	
    while(key = [enumerator nextObject]) {
		if ([reportString length] != 0) [reportString appendString:@"&"];
		[reportString appendFormat:@"%@=%@", key, [[crashReport objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSData *data = nil;
	
    while(!data) {
		NSError *error;
		NSURLResponse *reply;
		NSURL *crashReportURL = [NSURL URLWithString:crashReportURLString];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:crashReportURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:120];
		[request addValue:[[NSProcessInfo processInfo] processName] forHTTPHeaderField:[NSString stringWithFormat:@"%@-Bug-Report", [[NSProcessInfo processInfo] processName]]];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[reportString dataUsingEncoding:NSUTF8StringEncoding]];
		
		[self setStatusMessage:NSLocalizedString(@"Sending Report...", nil)];

		data = [NSURLConnection sendSynchronousRequest:request returningResponse:&reply error:&error];
		
		[self setStatusMessage:@""];
		
		if (!data) {
			if (NSRunAlertPanel(NSLocalizedString(@"Unable to send crash report", nil),
								error != nil ? [error localizedDescription] : @"",
								NSLocalizedString(@"Try Again", nil), 
								NSLocalizedString(@"Cancel", nil),
								nil) == NSAlertAlternateReturn) {
				break;
			}
		} else {
			NSRunAlertPanel(NSLocalizedString(@"Thank You", nil),
							NSLocalizedString(@"The crash report has been sent.", nil),
							NSLocalizedString(@"OK", nil), 
							nil,
							nil);
		}
    }
	
	[self close];
}

- (IBAction)ignore:(id)sender {
	[self close];
}

@end

NSString *CrashReporterLastCheckDateDefaultsKey = @"CrashReporterLastCheckDateDefaultsKey";
