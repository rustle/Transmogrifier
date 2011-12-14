//
//  AACTranscoder.h
//  Transmogrifier
//	

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

// This class is a retooling of
// http://atastypixel.com/blog/easy-aac-compressed-audio-conversion-on-ios/
// to use ARC, support configurable bit rate, perform transcoding synchronously

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
