//
//  MainViewController.h
//  Transmogrifier
//	
//  Copyright Doug Russell 2011. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
