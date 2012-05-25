//
//  NPReceiptVerification.m
//
//  Created by Nick Paulson on 1/15/11.
//	Copyright (c) 2011 Nick Paulson
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//

#import "ReceiptVerification.h"

#import <IOKit/IOKitLib.h>
#import <Foundation/Foundation.h>

#import <Security/Security.h>
#import <Security/CSCommon.h>
#import <Security/SecStaticCode.h>
#import <Security/SecRequirement.h>

#include <openssl/pkcs7.h>
#include <openssl/objects.h>
#include <openssl/sha.h>
#include <openssl/x509.h>
#include <openssl/err.h>

@interface ReceiptVerification ()
+ (NSData *)systemMACAddress;
+ (NSData *)appleRootCertificateData;
+ (NSDictionary *)appStoreReceiptDictionaryForFile:(NSString *)receiptFilePath;
@end

//These need to be defined for each application and version
static NSString * const kReceiptBundleVersion = @"2.7";
static NSString * const kReceiptBundleIdentifier = @"com.hogbaysoftware.QuickCursor";

static NSString * const kReceiptBundleIdentiferKey = @"BundleIdentifier";
static NSString * const kReceiptBundleIdentiferDataKey = @"BundleIdentifierData";
static NSString * const kReceiptVersionKey = @"Version";
static NSString * const kReceiptOpaqueValueKey = @"OpaqueValue";
static NSString * const kReceiptHashKey = @"Hash";

@implementation ReceiptVerification

+ (void)load {

#ifndef MAS
	return;
#endif
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	NSBundle *appBundle = [NSBundle mainBundle];
	NSString *appPath = [appBundle bundlePath];
	NSString *masReceiptPath = [[[appPath stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"_MASReceipt"] stringByAppendingPathComponent:@"receipt"];
	
	//If the receipt file doesn't exist...
	if (![[NSFileManager defaultManager] fileExistsAtPath:masReceiptPath]) {
		exit(173);
		pool = (NSAutoreleasePool *)1;
	}
	
	//Verify code signing identity is something Apple
	SecStaticCodeRef staticCode = NULL;
    SecRequirementRef req = NULL;
	
	char thea = 'a';
	char theSpace = ' ';
	char thec = 'c';
	char thel = 'l';
	char theh = 'h';
	char ther = 'r';
	char thep = 'p';
	char theo = 'o';
	char then = 'n';
	char thee = 'e';
	
	NSString *anchorString = [NSString stringWithFormat:@"%5$c%9$c%1$c%8$c%6$c%10$c%3$c%5$c%2$c%2$c%7$c%4$c",
							  thec, thep, theSpace, thee, thea, theo, thel, theh, then, ther];
	anchorString = [anchorString stringByAppendingString:@" generic"];
	
    OSStatus status = SecStaticCodeCreateWithPath((CFURLRef)[NSURL fileURLWithPath:appPath], kSecCSDefaultFlags, &staticCode);
    status = SecRequirementCreateWithString((CFStringRef)anchorString, kSecCSDefaultFlags, &req);
    status = SecStaticCodeCheckValidity(staticCode, kSecCSDefaultFlags, req);
	
	if(status != noErr) {
		exit(173);
		pool = (NSAutoreleasePool *)1;
	}
	
	//Verify MAS Receipt
	NSDictionary *receiptDict = [[self class] appStoreReceiptDictionaryForFile:masReceiptPath];
	
	if(receiptDict == nil) {
		exit(173);
		pool = (NSAutoreleasePool *)1;
	}
	
	
	NSData *guidData = [[self class] systemMACAddress];
	if (guidData == nil) {
		exit(173);
		pool = (NSAutoreleasePool *)1;
	}
	
	NSAssert([kReceiptBundleVersion isEqualToString:[appBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]], 
			 @"CFBundleShortVersionString must match hardcoded version number!");
	NSAssert([kReceiptBundleIdentifier isEqualToString:[appBundle bundleIdentifier]], 
			 @"Bundle identifier must match hardcoded bundle identifier");
	
	NSMutableData *input = [NSMutableData data];
	[input appendData:guidData];
	[input appendData:[receiptDict objectForKey:kReceiptOpaqueValueKey]];
	[input appendData:[receiptDict objectForKey:kReceiptBundleIdentiferDataKey]];
	
	NSMutableData *hash = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
	SHA1([input bytes], [input length], [hash mutableBytes]);
	
	if (!([kReceiptBundleIdentifier isEqualToString:[receiptDict objectForKey:kReceiptBundleIdentiferKey]] &&
		[kReceiptBundleVersion isEqualToString:[receiptDict objectForKey:kReceiptVersionKey]] &&
		[hash isEqualToData:[receiptDict objectForKey:kReceiptHashKey]]) )
	{
		exit(173);
		pool = (NSAutoreleasePool *)1;
	}

	[pool release];
}

+ (NSData *)appleRootCertificateData {
	OSStatus status;
	
	SecKeychainRef keychain = nil;
	
	NSString *rootString = @"Root";
	NSString *ificatesString = @"ificates";
	NSString *keychainsString = @"Keychains";
	NSString *systemString = @"System";
	NSString *certString = @"Cert";
	
	
	NSString *pathString = [NSString stringWithFormat:@"/%3$@/Library/%2$@/%3$@%1$@%5$@%4$@.%6$@", 
							rootString, keychainsString, systemString, ificatesString, certString, [[keychainsString lowercaseString] substringWithRange:NSMakeRange(0, [keychainsString length] - 1)]];
	
	status = SecKeychainOpen([pathString cStringUsingEncoding:NSUTF8StringEncoding], &keychain);
	if(status) {
		if(keychain) CFRelease(keychain);
		return nil;
	}
	
	CFArrayRef searchList = CFArrayCreate(kCFAllocatorDefault, (const void**)&keychain, 1, &kCFTypeArrayCallBacks);
	
	// For some reason we get a malloc reference underflow warning message when garbage collection
	// is on. Perhaps a bug in SecKeychainOpen where the keychain reference isn't actually retained
	// in GC?
#ifndef __OBJC_GC__
	if (keychain)
		CFRelease(keychain);
#endif
	
	SecKeychainSearchRef searchRef = nil;
	status = SecKeychainSearchCreateFromAttributes(searchList, kSecCertificateItemClass, NULL, &searchRef);
	if(status) {
		if(searchRef) CFRelease(searchRef);
		if(searchList) CFRelease(searchList);
		return nil;
	}
	
	SecKeychainItemRef itemRef = nil;
	NSData * resultData = nil;
	
	char theA = 'A';
	char thep = 'p';
	char theC = 'C';
	char theSpace = ' ';
	char theR = 'R';
	char thee = 'e';
	char theo = 'o';
	char thel = 'l';
	char thet = 't';
	
	NSString *certName = [NSString stringWithFormat:@"%3$c%2$c%2$c%1$c%7$c%9$c%8$c%4$c%4$c%5$c%9$c%6$c%3$c",
						  thel, thep, theA, theo, thet, theC, thee, theR, theSpace];
	
	while(SecKeychainSearchCopyNext(searchRef, &itemRef) == noErr && resultData == nil) {
		// Grab the name of the certificate
		SecKeychainAttributeList list;
		SecKeychainAttribute attributes[1];
		
		attributes[0].tag = kSecLabelItemAttr;
		
		list.count = 1;
		list.attr = attributes;
		
		SecKeychainItemCopyContent(itemRef, nil, &list, nil, nil);
		NSData *nameData = [NSData dataWithBytesNoCopy:attributes[0].data length:attributes[0].length freeWhenDone:NO];
		NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
		
		if([name isEqualToString:certName]) {
			CSSM_DATA certData;
			status = SecCertificateGetData((SecCertificateRef)itemRef, &certData);
			
            if (!status) {
                resultData = [NSData dataWithBytes:certData.Data length:certData.Length];
            }
		}
		SecKeychainItemFreeContent(&list, NULL);
        if(itemRef) 
            CFRelease(itemRef);
        [name release];
	}
	CFRelease(searchList);
	CFRelease(searchRef);
	
	return resultData;
	
}

+ (NSData *)systemMACAddress {
	kern_return_t             kernResult;
    mach_port_t               master_port;
    CFMutableDictionaryRef    matchingDict;
    io_iterator_t             iterator;
    io_object_t               service;
    CFDataRef                 macAddress = nil;
	
    kernResult = IOMasterPort(MACH_PORT_NULL, &master_port);
    if (kernResult != KERN_SUCCESS) {
		// NSLog("IOMasterPort returned %d", kernResult);
        return nil;
    }
	
	char then = 'n';
	char thee = 'e';
	char the0 = '0';
	NSString *bsdName = [NSString stringWithFormat:@"%2$c%3$c%1$c", the0, thee, then];
	matchingDict = IOBSDNameMatching(master_port, 0, [bsdName UTF8String]);
    if(!matchingDict) {
		//  NSLog("IOBSDNameMatching returned empty dictionary");
        return nil;
    }
	
    kernResult = IOServiceGetMatchingServices(master_port, matchingDict, &iterator);
    if (kernResult != KERN_SUCCESS) {
		// NSLog("IOServiceGetMatchingServices returned %d", kernResult);
        return nil;
    }
	
    while((service = IOIteratorNext(iterator)) != 0)
    {
        io_object_t        parentService;
		
        kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService);
        if(kernResult == KERN_SUCCESS)
        {
            if(macAddress) CFRelease(macAddress);
			char theO = 'O';
			char theI = 'I';
			char thes = 's';
			char theC = 'C';
			char ther = 'r';
			char theM = 'M';
			char thed = 'd';
			char theA = 'A';
			
			NSString *macAddressString = [NSString stringWithFormat:
										  @"%2$c%7$c%5$c%1$c%8$c%1$c%3$c%3$c%6$c%9$c%4$c%4$c", theA, theI, thed, thes, theM, ther, theO, theC, thee];
			macAddress = IORegistryEntryCreateCFProperty(parentService, (CFStringRef)macAddressString, kCFAllocatorDefault, 0);
            IOObjectRelease(parentService);
        }
        else {
            //NSLog("IORegistryEntryGetParentEntry returned %d", kernResult);
        }
		
        IOObjectRelease(service);
    }
	
	return [(NSData *)macAddress autorelease];
}

+ (NSDictionary *)appStoreReceiptDictionaryForFile:(NSString *)receiptFilePath {
	NSData * rootCertData = [[self class] appleRootCertificateData];
	
    enum ATTRIBUTES 
	{
        ATTR_START = 1,
        BUNDLE_ID,
        VERSION,
        OPAQUE_VALUE,
        HASH,
        ATTR_END
    };
    
	ERR_load_PKCS7_strings();
	ERR_load_X509_strings();
	OpenSSL_add_all_digests();
	
    // Expected input is a PKCS7 container with signed data containing
    // an ASN.1 SET of SEQUENCE structures. Each SEQUENCE contains
    // two INTEGERS and an OCTET STRING.
    
	const char * receiptPath = [[receiptFilePath stringByStandardizingPath] fileSystemRepresentation];
    FILE *fp = fopen(receiptPath, "rb");
    if (fp == NULL)
        return nil;
    
    PKCS7 *p7 = d2i_PKCS7_fp(fp, NULL);
    fclose(fp);
	
	// Check if the receipt file was invalid (otherwise we go crashing and burning)
	if (p7 == NULL) {
		return nil;
	}
    
    if (!PKCS7_type_is_signed(p7)) {
        PKCS7_free(p7);
        return nil;
    }
    
    if (!PKCS7_type_is_data(p7->d.sign->contents)) {
        PKCS7_free(p7);
        return nil;
    }
    
	int verifyReturnValue = 0;
	X509_STORE *store = X509_STORE_new();
	if (store)
	{
		const unsigned char *data = (unsigned char *)(rootCertData.bytes);
		X509 *appleCA = d2i_X509(NULL, &data, (long)rootCertData.length);
		if (appleCA)
		{
			BIO *payload = BIO_new(BIO_s_mem());
			X509_STORE_add_cert(store, appleCA);
			
			if (payload)
			{
				verifyReturnValue = PKCS7_verify(p7,NULL,store,NULL,payload,0);
				BIO_free(payload);
			}
			
			X509_free(appleCA);
		}
		X509_STORE_free(store);
	}
	EVP_cleanup();
	
	if (verifyReturnValue != 1)
	{
        PKCS7_free(p7);
		return nil;	
	}
	
    ASN1_OCTET_STRING *octets = p7->d.sign->contents->d.data;   
	const unsigned char *p = octets->data;
    const unsigned char *end = p + octets->length;
    
    int type = 0;
    int xclass = 0;
    long length = 0;
    
    ASN1_get_object(&p, &length, &type, &xclass, end - p);
    if (type != V_ASN1_SET) {
        PKCS7_free(p7);
        return nil;
    }
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    while (p < end) {
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        if (type != V_ASN1_SEQUENCE)
            break;
        
        const unsigned char *seq_end = p + length;
        
        int attr_type = 0;
        int attr_version = 0;
        
        // Attribute type
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_type = p[0];
        }
        p += length;
        
        // Attribute version
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_version = p[0];
			attr_version = attr_version;
        }
        p += length;
        
        // Only parse attributes we're interested in
        if (attr_type > ATTR_START && attr_type < ATTR_END) {
            NSString *key;
            
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_OCTET_STRING) {
                
                // Bytes
                if (attr_type == BUNDLE_ID || attr_type == OPAQUE_VALUE || attr_type == HASH) {
                    NSData *data = [NSData dataWithBytes:p length:(NSUInteger)length];
                    
                    switch (attr_type) {
                        case BUNDLE_ID:
                            // This is included for hash generation
                            key = kReceiptBundleIdentiferDataKey;
                            break;
                        case OPAQUE_VALUE:
                            key = kReceiptOpaqueValueKey;
                            break;
                        case HASH:
                            key = kReceiptHashKey;
                            break;
                    }
                    
                    [info setObject:data forKey:key];
                }
                
                // Strings
                if (attr_type == BUNDLE_ID || attr_type == VERSION) {
                    int str_type = 0;
                    long str_length = 0;
					const unsigned char *str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                    if (str_type == V_ASN1_UTF8STRING) {
                        NSString *string = [[[NSString alloc] initWithBytes:str_p
                                                                     length:(NSUInteger)str_length
                                                                   encoding:NSUTF8StringEncoding] autorelease];
						
                        switch (attr_type) {
                            case BUNDLE_ID:
                                key = kReceiptBundleIdentiferKey;
                                break;
                            case VERSION:
                                key = kReceiptVersionKey;
                                break;
                        }
                        
                        [info setObject:string forKey:key];
                    }
                }
            }
            p += length;
        }
        
        // Skip any remaining fields in this SEQUENCE
        while (p < seq_end) {
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            p += length;
        }
    }
    
    PKCS7_free(p7);
    
    return info;
}

@end
