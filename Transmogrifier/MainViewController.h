//
//  MainViewController.h
//  Transmogrifier
//
//  Created by  on 12/8/11.
//  Copyright (c) 2011 Doug Russell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HTTPLSTransmogrifier.h"

@class MainView;

@interface MainViewController : NSViewController <NSTableViewDelegate, NSTableViewDataSource, HTTPLSTransmogrifierDelegate>

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSButton *startButton;
@property (strong) IBOutlet NSButton *clearButton;
@property (strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong) IBOutlet NSButton *cancelButton;
@property (strong) IBOutlet NSTextField *statusLabel;
@property (strong) HTTPLSTransmogrifier *transmogrifier;

- (IBAction)start:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)cancel:(id)sender;

@end
