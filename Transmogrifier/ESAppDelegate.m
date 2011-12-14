//
//  ESAppDelegate.m
//  Transmogrifier
//
//  Created by  on 12/8/11.
//  Copyright (c) 2011 Doug Russell. All rights reserved.
//

#import "ESAppDelegate.h"
#import "MainViewController.h"

@implementation ESAppDelegate
@synthesize window=_window;
@synthesize mainViewController=_mainViewController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	self.mainViewController = [MainViewController new];
	self.window.contentView = self.mainViewController.view;
}

@end
