//
//  AACTranscoder.h
//  Transmogrifier
//	

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

// This class is a retooling of
// http://atastypixel.com/blog/easy-aac-compressed-audio-conversion-on-ios/
// to use ARC, support configurable bit rate, perform transcoding synchronously

// Original code is MIT License
//
//  TPAACAudioConverter.h
//
//  Created by Michael Tyson on 02/04/2011.
//  Copyright 2011 A Tasty Pixel. All rights reserved.
//	

// Changes are MIT Licensed (or honestly whatever license works for you, don't really care)
//
//  Changes by Doug Russell
//  Copyright 2011 Doug Russell. All rights reserved.
//

extern NSString *const AACAudioConverterErrorDomain;
enum {
	AACAudioConverterFileError,
	AACAudioConverterFormatError,
	AACAudioConverterConverterError,
	AACAudioConverterUnrecoverableInterruptionError,
	AACAudioConverterInitialisationError
};

extern UInt32 const kBitRateLow;
extern UInt32 const kBitRateHigh;

@interface AACTranscoder : NSObject

+ (BOOL)AACConverterAvailable;

@property (nonatomic, retain) NSError *error;
@property (assign) UInt32 bitRate;

- (id)initWithInputFile:(NSString *)inputFilePath outputFile:(NSString *)outputFilePath;
- (BOOL)start;
- (void)cancel;

@end
