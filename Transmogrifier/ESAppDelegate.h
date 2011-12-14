//
//  ESAppDelegate.h
//  Transmogrifier
//
//  Created by  on 12/8/11.
//  Copyright (c) 2011 Doug Russell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MainViewController;

@interface ESAppDelegate : NSObject <NSApplicationDelegate>

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet MainViewController *mainViewController;

@end
