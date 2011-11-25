//
//  AppDelegate.m
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import "AppDelegate.h"
#import "FilesController.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize filesController;

- (void)dealloc {
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
	[filesController addFiles:filenames];
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
	if (flag == NO) {
		[self.window makeKeyAndOrderFront:self];
	}

	return YES;
}

@end
