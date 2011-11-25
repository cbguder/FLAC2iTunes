//
//  QueueEntry.m
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 24/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import "QueueEntry.h"
#import "FLACMetadataReader.h"
#import "NSString+MD5.h"

@implementation QueueEntry

@synthesize pathHash, decodedPath, comments, status;

+ (id)entryWithPath:(NSString *)path {
	return [[[self alloc] initWithPath:path] autorelease];
}

- (void)dealloc {
	[path release];
	[pathHash release];
	[decodedPath release];
	[comments release];
	[super dealloc];
}

- (id)initWithPath:(NSString *)aPath {
	if ((self = [super init])) {
		self.path = aPath;
	}

	return self;
}

- (NSString *)path {
	id result;

	@synchronized (self) {
		result = [path retain];
	}

	return [result autorelease];
}

- (void)setPath:(NSString *)aPath {
	@synchronized (self) {
		if (path != aPath) {
			[path release];
			path = [aPath copy];

			[pathHash release];
			pathHash = [[path MD5] retain];

			[decodedPath release];
			NSString *decodedFilename = [pathHash stringByAppendingPathExtension:@"wav"];
			decodedPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:decodedFilename] retain];

			[comments release];
			comments = [FLACMetadataDictionaryFromFile(path) retain];
		}
	}
}

@end
