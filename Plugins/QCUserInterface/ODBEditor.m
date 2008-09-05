//
//  ODBEditor.m
//  B-Quartic

// http://gusmueller.com/odb/

/**
    
    Nov 30- Updates from Eric Blair:
        removed entries from the _filesBeingEdited dictionary when the odb connection is closed.
        added support for handling Save As messages and differentiate between editing a file and editing a string.
 
    Nov 30- Updates from Gus Mueller:
        Added stringByResolvingSymlinksInPath around the file paths passed around, because it seems if you write to
        /tmp/, sometimes you'll get back /private/tmp as a param

*/


#import "NSAppleEventDescriptor-Extensions.h"
#import "ODBEditor.h"
#import "ODBEditorSuite.h"
#import <Carbon/Carbon.h>

NSString * const ODBEditorCustomPathKey		= @"ODBEditorCustomPath";
NSString * const ODBEditorNonRetainedClient = @"ODBEditorNonRetainedClient";
NSString * const ODBEditorClientContext		= @"ODBEditorClientContext";
NSString * const ODBEditorFileName			= @"ODBEditorFileName";
NSString * const ODBEditorIsEditingString	= @"ODBEditorIsEditingString";

@interface ODBEditor(Private)

- (BOOL)_launchExternalEditor;
- (NSString *)_tempFileForEditingString:(NSString *)string;
- (BOOL)_editFile:(NSString *)path isEditingString:(BOOL)editingStringFlag options:(NSDictionary *)options forClient:(id)client context:(NSDictionary *)context;
- (void)handleModifiedFileEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleClosedFileEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

@end

@implementation ODBEditor

static ODBEditor	*_sharedODBEditor;

+ (id)sharedODBEditor {
	if (_sharedODBEditor == nil) {
		_sharedODBEditor = [[ODBEditor alloc] init];
	}
	return _sharedODBEditor;
}

- (id)init {
	self = [super init];
	if (self != nil) {
		UInt32  packageType = 0;
		UInt32  packageCreator = 0;

		if (_sharedODBEditor != nil) {
			[self autorelease];
			[NSException raise: NSInternalInconsistencyException format: @"ODBEditor is a singleton - use [ODBEditor sharedODBEditor]"];
			return nil;
		}
		
		// our initialization
		
		CFBundleGetPackageInfo(CFBundleGetMainBundle(), &packageType, &packageCreator);
		_signature = packageCreator;
		
		[self setEditorBundleIdentifier: @"com.hogbaysoftware.WriteRoom"];
		
		_filesBeingEdited = [[NSMutableDictionary alloc] init];
		
		// setup our event handlers
		
		NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
		[appleEventManager setEventHandler: self andSelector: @selector(handleModifiedFileEvent:withReplyEvent:) forEventClass: kODBEditorSuite andEventID: kAEModifiedFile];
		[appleEventManager setEventHandler: self andSelector: @selector(handleClosedFileEvent:withReplyEvent:) forEventClass: kODBEditorSuite andEventID: kAEClosedFile];
	}
	
	return self;
}

- (void)dealloc {
	NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
	[appleEventManager removeEventHandlerForEventClass: kODBEditorSuite andEventID: kAEModifiedFile];
	[appleEventManager removeEventHandlerForEventClass: kODBEditorSuite andEventID: kAEClosedFile];
	[_editorBundleIdentifier release];
	[_filesBeingEdited release];
	[super dealloc];
}

- (void)setEditorBundleIdentifier:(NSString *)bundleIdentifier {
	[_editorBundleIdentifier autorelease];
	_editorBundleIdentifier = [bundleIdentifier copy];
}

- (NSString *)editorBundleIdentifier {
	return _editorBundleIdentifier;
}

- (void)abortEditingFile:(NSString *)path {
	 #warning REVIEW if we created a temporary file for this session should we try to delete it and/or close it in the editor?

	if (nil == [_filesBeingEdited objectForKey: path])
		NSLog(@"ODBEditor: No active editing session for \"%@\"", path);

	 [_filesBeingEdited removeObjectForKey: path];
}

- (void)abortAllEditingSessionsForClient:(id)client {
	 #warning REVIEW if we created a temporary file for this session should we try to delete it and/or close it in the editor?

	BOOL found = NO;
	NSEnumerator *enumerator = [_filesBeingEdited objectEnumerator];
	NSMutableArray *keysToRemove = [NSMutableArray array];
	NSDictionary *dictionary = nil;
	
	while (nil != (dictionary = [enumerator nextObject])) {
		id  iterClient = [[dictionary objectForKey: ODBEditorNonRetainedClient] nonretainedObjectValue];
		
		if (iterClient == client) {
			found = YES;
			[keysToRemove addObject: [dictionary objectForKey: ODBEditorFileName]];
		}
	}
	
	[_filesBeingEdited removeObjectsForKeys: keysToRemove];
	
	if (! found) {
		NSLog(@"ODBEditor: No active editing session for \"%@\"", client);
	}
}

- (BOOL)editFile:(NSString *)path options:(NSDictionary *)options forClient:(id)client context:(NSDictionary *)context {
	return [self _editFile: path isEditingString: NO options: options forClient: client context: context];
}

- (BOOL)editString:(NSString *)string options:(NSDictionary *)options forClient:(id)client context:(NSDictionary *)context {
	BOOL success = NO;
	NSString *path = [self _tempFileForEditingString: string];
	
	if (path != nil) {
		success = [self _editFile: path isEditingString: YES options: options forClient: client context: context];
    }
    
	return success;
}

@end


@implementation ODBEditor(Private)

- (BOOL)_launchExternalEditor {
	BOOL success = NO;
	BOOL running = NO;
	NSWorkspace	*workspace = [NSWorkspace sharedWorkspace];
	NSArray	*runningApplications = [workspace launchedApplications];
	NSEnumerator *enumerator = [runningApplications objectEnumerator];
	NSDictionary *applicationInfo;
	
	while (nil != (applicationInfo = [enumerator nextObject])) {
		NSString *bundleIdentifier = [applicationInfo objectForKey: @"NSApplicationBundleIdentifier"];
		
		if ([bundleIdentifier isEqualToString: _editorBundleIdentifier]) {
			running = YES;
			// bring the app forward
			success = [workspace launchApplication: [applicationInfo objectForKey: @"NSApplicationPath"]];
			break;
		}
	}
	
	if (running == NO) {
		success = [workspace launchAppWithBundleIdentifier: _editorBundleIdentifier options: 0L additionalEventParamDescriptor: nil launchIdentifier: nil];
	}
	
	return success;
}

- (NSString *)_tempFileForEditingString:(NSString *)string {
	static  unsigned sTempFileSequence;
	
	NSString *fileName = nil;

	sTempFileSequence++;
	
	fileName = [NSString stringWithFormat: @"ODBEditor-%@-%06d.txt", [[NSBundle mainBundle] bundleIdentifier], sTempFileSequence];
	fileName = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];

	if (NO == [string writeToFile:fileName atomically:NO encoding:NSUTF8StringEncoding error:nil])
		fileName = nil;

	return fileName;
}

- (BOOL)_editFile:(NSString *)fileName isEditingString:(BOOL)editingStringFlag options:(NSDictionary *)options forClient:(id)client context:(NSDictionary *)context {
    // 10.2 fix- akm Nov 30 2004
    fileName = [fileName stringByResolvingSymlinksInPath];
    
	BOOL success = NO;
	OSStatus status = noErr;
	NSData *targetBundleID = [_editorBundleIdentifier dataUsingEncoding: NSUTF8StringEncoding];
	NSAppleEventDescriptor *targetDescriptor = [NSAppleEventDescriptor descriptorWithDescriptorType: typeApplicationBundleID data: targetBundleID];
	NSAppleEventDescriptor *appleEvent = [NSAppleEventDescriptor appleEventWithEventClass: kCoreEventClass
																				   eventID: kAEOpenDocuments
																		  targetDescriptor: targetDescriptor
																				  returnID: kAutoGenerateReturnID
																		     transactionID: kAnyTransactionID];
	NSAppleEventDescriptor  *replyDescriptor = nil;
	NSAppleEventDescriptor  *errorDescriptor = nil;
	AEDesc reply = {typeNull, NULL};														
	NSString *customPath = [options objectForKey: ODBEditorCustomPathKey];
	
	[self _launchExternalEditor];
	
	[appleEvent setParamDescriptor: [NSAppleEventDescriptor descriptorWithFilePath: fileName] forKeyword: keyDirectObject];
	[appleEvent setParamDescriptor: [NSAppleEventDescriptor descriptorWithTypeCode: _signature] forKeyword: keyFileSender];
	if (customPath != nil)
		[appleEvent setParamDescriptor: [NSAppleEventDescriptor descriptorWithString: customPath] forKeyword: keyFileCustomPath];
	
	status = AESend([appleEvent aeDesc], &reply, kAEWaitReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);		
	
	if (status == noErr) {
		replyDescriptor = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy: &reply] autorelease];
		errorDescriptor = [replyDescriptor paramDescriptorForKeyword: keyErrorNumber];
		
		if (errorDescriptor != nil) {
			status = [errorDescriptor int32Value];
		}
		
		if (status == noErr) {
			// save off some information that we'll need when we get called back
			
			NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
			
			[dictionary setObject: [NSValue valueWithNonretainedObject: client] forKey: ODBEditorNonRetainedClient];
			if (context != NULL)
				[dictionary setObject: context forKey: ODBEditorClientContext];
			[dictionary setObject: fileName forKey: ODBEditorFileName];
			[dictionary setObject: [NSNumber numberWithBool: editingStringFlag] forKey: ODBEditorIsEditingString];
			
			[_filesBeingEdited setObject: dictionary forKey: fileName];
		}
	}

	success = (status == noErr);

	return success;
}

- (void)handleModifiedFileEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSAppleEventDescriptor *fpDescriptor = [[event paramDescriptorForKeyword: keyDirectObject] coerceToDescriptorType: typeFileURL];
	NSString *urlString = [[[NSString alloc] initWithData: [fpDescriptor data] encoding: NSUTF8StringEncoding] autorelease];
	NSString *fileName = [[[NSURL URLWithString: urlString] path] stringByResolvingSymlinksInPath];
	NSAppleEventDescriptor	*nfpDescription = [[event paramDescriptorForKeyword: keyNewLocation] coerceToDescriptorType: typeFileURL];
	NSString *newUrlString = [[[NSString alloc] initWithData: [nfpDescription data] encoding: NSUTF8StringEncoding] autorelease];
	NSString *newFileName = [[NSURL URLWithString: newUrlString] path];
	NSDictionary *dictionary = nil;
	
	dictionary = [_filesBeingEdited objectForKey: fileName];
	
	if (dictionary != nil)
	{
		id  client		= [[dictionary objectForKey: ODBEditorNonRetainedClient] nonretainedObjectValue];
		id isString		= [dictionary objectForKey: ODBEditorIsEditingString];
		NSDictionary *context	= [dictionary objectForKey: ODBEditorClientContext];
// XXXX JESSE		NSDictionary *context	= [[dictionary objectForKey: ODBEditorClientContext] nonretainedObjectValue];
		
		if(isString)
		{
			NSString	*stringContents = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
			[client odbEditor: self didModifyFileForString: stringContents context: context];
		}
		else
			[client odbEditor:self didModifyFile:fileName newFileLocation:newFileName context:context];

		// if we've received a Save As message, remove the file from the list of edited files
		// This may be break compatibility with BBEdit versioner < 6.0, since these versions
		// continue to send notifications after after doing a Save As...
		if(newFileName)
		{
			[_filesBeingEdited removeObjectForKey: fileName];
	    }

	}
	else
	{
		NSLog(@"Got ODB editor event for unknown file.");
	}
}

- (void)handleClosedFileEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSAppleEventDescriptor  *descriptor = [[event paramDescriptorForKeyword: keyDirectObject] coerceToDescriptorType: typeFileURL];
	NSString				*urlString = [[[NSString alloc] initWithData: [descriptor data] encoding: NSUTF8StringEncoding] autorelease];

	NSString				*fileName = [[[NSURL URLWithString: urlString] path] stringByResolvingSymlinksInPath];

	NSDictionary			*dictionary = nil;
	
	dictionary = [_filesBeingEdited objectForKey: fileName];
	
	if (dictionary != nil)
	{
		id client		= [[dictionary objectForKey: ODBEditorNonRetainedClient] nonretainedObjectValue];
		id isString		= [dictionary objectForKey: ODBEditorIsEditingString];
		NSDictionary *context	= [dictionary objectForKey: ODBEditorClientContext];
		
		if(isString)
		{
			NSString	*stringContents = [NSString stringWithContentsOfFile: fileName];
			[client odbEditor: self didCloseFileForString: stringContents context: context];
		}
		else
		{
			[client odbEditor:self didClosefile:fileName context:context];
		}
	}
	else
	{
		NSLog(@"Got ODB editor event for unknown file.");
	}
	
	 [_filesBeingEdited removeObjectForKey: fileName];
}

@end

