//
//  FilesController.h
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import "iTunes.h"

@interface FilesController : NSObject <NSTableViewDataSource> {
    iTunesApplication *iTunes;
    NSOperationQueue *operationQueue;
    NSTableView *_tableView;
    NSMutableArray *files;
    NSDictionary *commentMap;
}

@property (retain) IBOutlet NSTableView *tableView;

- (void)addFiles:(NSArray *)filenames;

- (IBAction)startDecoding:(id)sender;

@end
