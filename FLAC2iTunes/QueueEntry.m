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
    return [[self alloc] initWithPath:path];
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
        result = path;
    }

    return result;
}

- (void)setPath:(NSString *)aPath {
    @synchronized (self) {
        path = [aPath copy];

        pathHash = [path MD5];

        NSString *decodedFilename = [pathHash stringByAppendingPathExtension:@"wav"];
        decodedPath = [NSTemporaryDirectory() stringByAppendingPathComponent:decodedFilename];

        comments = FLACMetadataDictionaryFromFile(path);
    }
}

@end
