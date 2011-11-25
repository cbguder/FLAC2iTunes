//
//  QueueEntry.h
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 24/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	QueueEntryStatusWaiting,
	QueueEntryStatusDecoding,
	QueueEntryStatusDecoded,
	QueueEntryStatusFailed,
	QueueEntryStatusEncoding,
	QueueEntryStatusDone
} QueueEntryStatus;

@interface QueueEntry : NSObject {
	NSString *path;
	NSString *pathHash;
	NSString *decodedPath;
	NSDictionary *comments;
	QueueEntryStatus status;
}

@property (copy) NSString *path;
@property (readonly) NSString *pathHash;
@property (readonly) NSString *decodedPath;
@property (copy) NSDictionary *comments;
@property (assign) QueueEntryStatus status;

+ (id)entryWithPath:(NSString *)path;

- (id)initWithPath:(NSString *)path;

@end
