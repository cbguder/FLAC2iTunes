//
//  iTunesMetadataFetcher.h
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 5/5/13.
//  Copyright (c) 2013 CBG. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface iTunesMetadataFetcher : NSObject

+ (NSArray *)fetchMetadataFromAlbumURL:(NSURL *)URL;

@end
