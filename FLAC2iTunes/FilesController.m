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
		files = [[NSMutableArray alloc] init];

		operationQueue = [[NSOperationQueue alloc] init];
		operationQueue.maxConcurrentOperationCount = 2;
		[operationQueue addObserver:self forKeyPath:@"operationCount" options:0 context:nil];

		iTunes = [[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"] retain];
		[iTunes setTimeout:kNoTimeOut];
	}

	return self;
}

- (void)dealloc {
	[operationQueue release];
	[_tableView release];
	[iTunes release];
	[files release];
	[super dealloc];
}

- (void)addFile:(NSString *)path {
	if ([[[path pathExtension] lowercaseString] isEqualToString:@"flac"]) {
		[files addObject:[QueueEntry entryWithPath:path]];
	}
}

- (void)addDirectory:(NSString *)path {
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:path]
															 includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, nil]
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
			badgeLabel = [NSString stringWithFormat:@"%d", operationQueue.operationCount];
		} else {
			[self performSelectorInBackground:@selector(encodeAll) withObject:nil];
		}

		[[[NSApplication sharedApplication] dockTile] setBadgeLabel:badgeLabel];
	}
}

- (void)refreshEntry:(QueueEntry *)entry {
	NSInteger index = [files indexOfObject:entry];
	[self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index]
							  columnIndexes:[NSIndexSet indexSetWithIndex:4]];
}

- (void)encodeAll {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

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
		QueueEntry *entry = [hashMap objectForKey:track.name];
		if (entry) {
			NSDictionary *comments = entry.comments;
			track.artist = [comments objectForKey:@"ARTIST"];
			track.album = [comments objectForKey:@"ALBUM"];
			track.name = [comments objectForKey:@"TITLE"];
			track.genre = [comments objectForKey:@"GENRE"];
			track.trackNumber = [[comments objectForKey:@"TRACKNUMBER"] integerValue];
			track.trackCount = [[comments objectForKey:@"TRACKTOTAL"] integerValue];
			track.discNumber = [[comments objectForKey:@"DISCNUMBER"] integerValue];
			track.discCount = [[comments objectForKey:@"DISCTOTAL"] integerValue];
			track.year = [[comments objectForKey:@"DATE"] integerValue];

			[[NSFileManager defaultManager] removeItemAtPath:entry.decodedPath error:nil];
			entry.status = QueueEntryStatusDone;
		}
	}

	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];

	[pool release];
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
	QueueEntry *entry = [files objectAtIndex:row];

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
		return [entry.comments objectForKey:[tableColumn.identifier uppercaseString]];
	}
}

@end
