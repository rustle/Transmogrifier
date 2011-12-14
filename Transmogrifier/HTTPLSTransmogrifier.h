//
//  HTTPLSTransmogrifier.h
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
