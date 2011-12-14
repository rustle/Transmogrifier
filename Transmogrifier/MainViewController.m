//	
//  MainViewController.m
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

#import "MainViewController.h"
#import "HTTPLSTransmogrifier.h"
#import "AACTranscoder.h"

@interface MainViewController ()
- (void)resetUI;
@end

@interface MainView : NSView
@property (assign) MainViewController *viewController;
@end

@implementation MainViewController
@synthesize transmogrifier=_transmogrifier;
@synthesize tableView=_tableView;
@synthesize startButton=_startButton;
@synthesize clearButton=_clearButton;
@synthesize progressIndicator=_progressIndicator;
@synthesize cancelButton=_cancelButton;
@synthesize statusLabel=_statusLabel;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) 
	{
		_transmogrifier = [HTTPLSTransmogrifier new];
		_transmogrifier.delegate = self;
		UInt32 bitRates[3];
		bitRates[0] = kBitRateLow;
		bitRates[1] = 96000;
		bitRates[2] = kBitRateHigh;
		[_transmogrifier setBitrates:bitRates count:3];
    }
    return self;
}

- (void)awakeFromNib
{
	((MainView *)self.view).viewController = self;
}

- (void)dealloc
{
	((MainView *)self.view).viewController = nil;
	self.transmogrifier.delegate = nil;
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (self.transmogrifier.files)
		return self.transmogrifier.files.count;
	return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return [[self.transmogrifier.files objectAtIndex:row] lastPathComponent];
}

#pragma mark - Files

- (void)addFiles:(NSArray *)files
{
	if (files == nil)
		return;
	[self.progressIndicator startAnimation:nil];
	[self.startButton setHidden:YES];
	[self.clearButton setHidden:YES];
	[self.transmogrifier addFiles:files];
}

#pragma mark - Transmogrifier

- (void)transmogrifier:(HTTPLSTransmogrifier *)transmogrifier fileDidComplete:(NSString *)file
{
	[self.tableView reloadData];
}

- (void)transmogrifierDidComplete:(HTTPLSTransmogrifier *)transmogrifier
{
	[self resetUI];
//	NSLog(@"%@", transmogrifier.resultFiles);
}

- (void)transmogrifier:(HTTPLSTransmogrifier *)transmogrifier didAddFiles:(NSArray *)files
{
	[self.tableView reloadData];
	[self.progressIndicator stopAnimation:nil];
	[self.startButton setHidden:NO];
	[self.clearButton setHidden:NO];
}

#pragma mark -

- (void)resetUI
{
	[self.startButton setHidden:NO];
	[self.clearButton setHidden:NO];
	[self.cancelButton setHidden:YES];
	[self.progressIndicator stopAnimation:nil];
	[[self statusLabel] setStringValue:@""];
	[[self statusLabel] setHidden:YES];
}

- (IBAction)start:(id)sender
{
	if (self.transmogrifier.files.count == 0)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"No Files To Process" 
										 defaultButton:@"Dismiss" 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:@"Drag files onto list view to queue them for processing.", nil];
		[alert runModal];
		return;
	}
	[self.startButton setHidden:YES];
	[self.clearButton setHidden:YES];
	[self.cancelButton setHidden:NO];
	[self.progressIndicator startAnimation:nil];
	[[self statusLabel] setStringValue:@"Working"];
	[[self statusLabel] setHidden:NO];
	[self.transmogrifier start];
}

- (IBAction)clear:(id)sender
{
	[self.transmogrifier clear];
	[self.tableView reloadData];
}

- (IBAction)cancel:(id)sender
{
	[self.cancelButton setHidden:YES];
	[[self statusLabel] setStringValue:@"Cancelling"];
	[self.transmogrifier cancel];
	[self resetUI];
}

@end

@implementation MainView
@synthesize viewController=_viewController;

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
	
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
	if ([[pboard types] containsObject:NSFilenamesPboardType] &&
		(sourceDragMask & NSDragOperationLink)) 
	{
		return NSDragOperationLink;
    }
    return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
	if ([self.viewController.transmogrifier isProcessing])
		return NO;
	
	NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
	
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
    if ([[pboard types] containsObject:NSFilenamesPboardType] &&
		(sourceDragMask & NSDragOperationLink)) 
	{
		return YES;
    }
    return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
	
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
    if ([[pboard types] containsObject:NSFilenamesPboardType]) 
	{
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        if (sourceDragMask & NSDragOperationLink) 
		{
			[self.viewController addFiles:files];
        }
		return YES;
    }
    return NO;
}

@end
