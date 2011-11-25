//
//  FLACMetadataReader.h
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import <Foundation/Foundation.h>

NSDictionary * FLACMetadataDictionaryFromFile(NSString *path);
NSArray * FLACCommentsFromFile(NSString *path);
