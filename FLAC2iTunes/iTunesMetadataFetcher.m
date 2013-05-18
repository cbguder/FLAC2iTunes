//
//  iTunesMetadataFetcher.m
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 5/5/13.
//  Copyright (c) 2013 CBG. All rights reserved.
//

#import "iTunesMetadataFetcher.h"

@implementation iTunesMetadataFetcher

+ (NSData *)extractServerDataFromBody:(NSData *)body {
    NSString *string = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];

    NSRange start = [string rangeOfString:@"its.serverData="];

    if (start.location != NSNotFound) {
        NSInteger startLocation = start.location + start.length;
        NSInteger remainingLength = [string length] - startLocation;

        NSRange end = [string rangeOfString:@"</script>"
                                    options:0
                                      range:NSMakeRange(startLocation, remainingLength)];

        if (end.location != NSNotFound) {
            NSRange jsonRange = NSMakeRange(startLocation, end.location - startLocation);

            return [[string substringWithRange:jsonRange] dataUsingEncoding:NSUTF8StringEncoding];
        }
    }

    return nil;
}

+ (NSArray *)fetchMetadataFromAlbumURL:(NSURL *)URL {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:@"iTunes/11.0.2 (Macintosh; OS X 10.8.3) AppleWebKit/536.28.10" forHTTPHeaderField:@"User-Agent"];

    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];

    NSData *jsonData = [self extractServerDataFromBody:data];

    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    NSDictionary *results = dict[@"pageData"][@"storePlatformData"][@"product-dv"][@"results"];

    NSMutableArray *comments = nil;

    NSDictionary *commentMap = @{
        @"ALBUM": @"collectionName",
        @"ARTIST": @"artistName",
        @"COMPOSER": @"composer.name",
        @"DATE": @"releaseDate",
        @"DISCNUMBER": @"discNumber",
        @"TITLE": @"name",
        @"TRACKNUMBER": @"trackNumber"
    };

    comments = [NSMutableArray array];

    for (NSDictionary *result in [results allValues]) {
        for (id childId in result[@"childrenIds"]) {
            NSString *childKey = [NSString stringWithFormat:@"%@", childId];
            NSDictionary *child = result[@"children"][childKey];

            if ([child[@"kind"] isEqualToString:@"song"]) {
                NSMutableDictionary *childComments = [NSMutableDictionary dictionaryWithCapacity:7];
                
                for (NSString *flacKey in commentMap) {
                    id value = [child valueForKeyPath:commentMap[flacKey]];
                    
                    if (value) {
                        childComments[flacKey] = value;
                    }
                }
                
                [comments addObject:childComments];
            }
        }
    }

    return comments;
}

@end
