//
//  FLACMetadataReader.m
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import "FLACMetadataReader.h"
#include "metadata.h"

NSArray * FLACCommentsFromFile(NSString *path) {
	FLAC__StreamMetadata *metadata = NULL;
	FLAC__metadata_get_tags([path cStringUsingEncoding:NSUTF8StringEncoding], &metadata);

	if (metadata == NULL) return nil;

	NSMutableArray *array = nil;

	if (metadata->type == FLAC__METADATA_TYPE_VORBIS_COMMENT) {
		FLAC__StreamMetadata_VorbisComment *comments = &(metadata->data.vorbis_comment);

		int num_comments = comments->num_comments;
		array = [NSMutableArray arrayWithCapacity:num_comments];

		for (int i = 0; i < num_comments; i++) {
			FLAC__StreamMetadata_VorbisComment_Entry *comment = &(comments->comments[i]);
			NSString *content = [NSString stringWithUTF8String:(const char *)comment->entry];
			[array addObject:content];
		}
	}

	FLAC__metadata_object_delete(metadata);

	return array;
}

NSDictionary * FLACMetadataDictionaryFromFile(NSString *path) {
	NSArray *comments = FLACCommentsFromFile(path);
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[comments count]];

	for (NSString *comment in comments) {
		NSArray *parts = [comment componentsSeparatedByString:@"="];
		NSUInteger partCount = [parts count];

		if (partCount < 2) continue;

		NSString *key = [parts[0] uppercaseString];
		NSString *value = nil;

		if (partCount == 2) {
			value = parts[1];
		} else {
			value = [[parts subarrayWithRange:NSMakeRange(1, partCount - 1)] componentsJoinedByString:@"="];
		}

		[dict setObject:value forKey:key];
	}

	return dict;
}
