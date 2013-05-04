//
//  FilesController.m
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import "FilesController.h"
#import "FLACDecoder.h"
#import "QueueEntry.h"

@implementation FilesController

@synthesize tableView = _tableView;

- (id)init {
    if ((self = [super init])) {
        files = [NSMutableArray array];

        operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.maxConcurrentOperationCount = [[NSProcessInfo processInfo] processorCount];
        [operationQueue addObserver:self forKeyPath:@"operationCount" options:0 context:nil];

        iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        [iTunes setTimeout:kNoTimeOut];

        NSString *commentMapPath = [[NSBundle mainBundle] pathForResource:@"CommentMap" ofType:@"plist"];
        commentMap = [NSDictionary dictionaryWithContentsOfFile:commentMapPath];
    }

    return self;
}


- (void)addFile:(NSString *)path {
    if ([[[path pathExtension] lowercaseString] isEqualToString:@"flac"]) {
        [files addObject:[QueueEntry entryWithPath:path]];
    }
}

- (void)addDirectory:(NSString *)path {
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:path]
                                                             includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:nil];
    NSNumber *isDirectory;

    for (NSURL *URL in enumerator) {
        [URL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];

        if ([isDirectory boolValue] == NO) {
            [self addFile:[URL path]];
        }
    }
}

- (void)addFiles:(NSArray *)filenames {
    BOOL isDir;

    for (NSString *filename in filenames) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir]) {
            if (isDir) {
                [self addDirectory:filename];
            } else {
                [self addFile:filename];
            }
        }
    }

    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == operationQueue && [keyPath isEqualToString:@"operationCount"]) {
        NSString *badgeLabel = nil;

        if (operationQueue.operationCount > 0) {
            badgeLabel = [NSString stringWithFormat:@"%ld", operationQueue.operationCount];
        } else {
            [self performSelectorInBackground:@selector(encodeAll) withObject:nil];
        }

        [[[NSApplication sharedApplication] dockTile] setBadgeLabel:badgeLabel];
    }
}

- (void)refreshEntry:(QueueEntry *)entry {
    NSInteger index = [files indexOfObject:entry];
    NSInteger statusIndex = [self.tableView columnWithIdentifier:@"status"];
    [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index]
                              columnIndexes:[NSIndexSet indexSetWithIndex:statusIndex]];
}

- (void)applyComments:(NSDictionary *)comments toTrack:(iTunesTrack *)track {
    for (NSString *key in comments) {
        NSDictionary *keyDesc = commentMap[key];

        if (keyDesc) {
            NSString *targetType = keyDesc[@"type"];
            NSString *targetKey = keyDesc[@"key"];

            NSString *stringValue = comments[key];
            id value;

            if ([targetType isEqualToString:@"integer"]) {
                value = [NSNumber numberWithInteger:[stringValue integerValue]];
            } else if ([targetType isEqualToString:@"boolean"]) {
                value = [NSNumber numberWithBool:[stringValue boolValue]];
            } else {
                value = stringValue;
            }

            [track setValue:value forKey:targetKey];
        }
    }
}

- (void)encodeAll {
    @autoreleasepool {
        NSMutableArray *encodeQueue = [NSMutableArray arrayWithCapacity:[files count]];
        NSMutableDictionary *hashMap = [NSMutableDictionary dictionaryWithCapacity:[files count]];

        for (QueueEntry *entry in files) {
            if (entry.status == QueueEntryStatusDecoded) {
                [hashMap setObject:entry forKey:entry.pathHash];
                [encodeQueue addObject:[NSURL fileURLWithPath:entry.decodedPath]];

                entry.status = QueueEntryStatusEncoding;
            }
        }

        [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];

        NSArray *tracks = (NSArray *)[iTunes convert:encodeQueue];

        for (iTunesTrack *track in tracks) {
            QueueEntry *entry = hashMap[track.name];
            if (entry) {
                [self applyComments:entry.comments toTrack:track];
                [[NSFileManager defaultManager] removeItemAtPath:entry.decodedPath error:nil];
                entry.status = QueueEntryStatusDone;
            }
        }

        [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    }
}

- (void)decodeEntry:(QueueEntry *)entry {
    entry.status = QueueEntryStatusDecoding;
    [self performSelectorOnMainThread:@selector(refreshEntry:) withObject:entry waitUntilDone:NO];

    if (FLACDecodeFile(entry.path, entry.decodedPath)) {
        entry.status = QueueEntryStatusDecoded;
    } else {
        entry.status = QueueEntryStatusFailed;
    }

    [self performSelectorOnMainThread:@selector(refreshEntry:) withObject:entry waitUntilDone:NO];
}

- (IBAction)startDecoding:(id)sender {
    [(NSToolbarItem *)sender setEnabled:NO];

    [operationQueue cancelAllOperations];
    [operationQueue setSuspended:YES];

    for (QueueEntry *entry in files) {
        entry.status = QueueEntryStatusWaiting;

        NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(decodeEntry:) object:entry];
        [operationQueue addOperation:operation];
    }

    [self.tableView reloadData];
    [operationQueue setSuspended:NO];
}

#pragma mark - Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [files count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    QueueEntry *entry = files[row];

    if ([tableColumn.identifier isEqualToString:@"path"]) {
        return [entry.path lastPathComponent];
    } else if ([tableColumn.identifier isEqualToString:@"status"]) {
        switch (entry.status) {
            case QueueEntryStatusDecoded: return @"Decoded";
            case QueueEntryStatusDecoding: return @"Decoding";
            case QueueEntryStatusDone: return @"Done";
            case QueueEntryStatusEncoding: return @"Encoding";
            case QueueEntryStatusFailed: return @"Failed";
            case QueueEntryStatusWaiting: return @"Waiting";
            default: return nil;
        }
    } else {
        if ([tableColumn.identifier isEqualToString:@"tracknumber"]) {
            NSInteger trackNumber = [entry.comments[@"TRACKNUMBER"] integerValue];
            NSInteger trackTotal = [entry.comments[@"TRACKTOTAL"] integerValue];

            if (trackTotal < trackNumber) {
                return [NSString stringWithFormat:@"%ld", trackNumber];
            } else {
                return [NSString stringWithFormat:@"%ld of %ld", trackNumber, trackTotal];
            }
        }

        return entry.comments[[tableColumn.identifier uppercaseString]];
    }
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    [tableView setDropRow:[tableView numberOfRows] dropOperation:NSTableViewDropAbove];
    return NSDragOperationGeneric;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSArray *pasteboardItems = [[info draggingPasteboard] pasteboardItems];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pasteboardItems count]];

    for (NSPasteboardItem *item in pasteboardItems) {
        NSString *URLString = [item stringForType:@"public.file-url"];

        if (URLString) {
            NSString *path = [[NSURL URLWithString:URLString] path];
            [items addObject:path];
        }
    }

    [self addFiles:items];

    return YES;
}

@end
