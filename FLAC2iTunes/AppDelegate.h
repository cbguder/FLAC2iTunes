//
//  AppDelegate.h
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FilesController;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource> {
	FilesController *filesController;
}

@property (assign) IBOutlet NSWindow *window;
@property (retain) IBOutlet FilesController *filesController;

@end
