//
//  HTTPLSTransmogrifier.h
//  Transmogrifier
//
//  Created by  on 12/10/11.
//  Copyright (c) 2011 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AACTranscoder.h"

#define USE_FLOATING_DURATIONS 1 // Floating point is not supportted pre iOS 4.1

@protocol HTTPLSTransmogrifierDelegate;

@interface HTTPLSTransmogrifier : NSObject

@property (assign) id<HTTPLSTransmogrifierDelegate> delegate;
@property (strong) NSSet *acceptableFileTypes;

// Pass in a c array of UInt32 values representing aac encoding bits per second
- (void)setBitrates:(UInt32 *)bitRates count:(NSInteger)count;
// NSString paths to the files to be transcoded
- (NSArray *)files;
// Currently NSURL paths to the files produced, may change to NSString paths
- (NSArray *)resultFiles;
// Add files to files arrays to be processed
- (void)addFiles:(NSArray *)files;
// Begin processing with callbacks to delegate as progress is made
- (void)start;
// Clear the content of files array
- (void)clear;
// Cancel current processing
- (void)cancel;
- (BOOL)isCancelled;
// 
- (BOOL)isProcessing;

@end

// All delegate callbacks are guaranteed to be on the main queue

@protocol HTTPLSTransmogrifierDelegate <NSObject>

- (void)transmogrifier:(HTTPLSTransmogrifier *)transmogrifier didAddFiles:(NSArray *)files;
- (void)transmogrifier:(HTTPLSTransmogrifier *)transmogrifier fileDidComplete:(NSString *)file;
- (void)transmogrifierDidComplete:(HTTPLSTransmogrifier *)transmogrifier;

@end
