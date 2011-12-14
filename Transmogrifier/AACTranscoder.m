//
//  AACTranscoder.m
//  Transmogrifier
//	

#import "AACTranscoder.h"

UInt32 const kBitRateHigh = 128000;
UInt32 const kBitRateLow = 64000;

NSString *const AACAudioConverterErrorDomain = @"com.atastypixel.TPAACAudioConverterErrorDomain";

#define checkResult(result,operation) (_checkResultLite((result),(operation),__FILE__,__LINE__))

static inline BOOL _checkResultLite(OSStatus result, const char *operation, const char* file, int line) 
{
	if ( result != noErr )
	{
		NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&result); 
		return NO;
	}
	return YES;
}

static BOOL _available;
static BOOL _available_set = NO;

@interface AACTranscoder ()
@property (nonatomic, retain) NSString *inputFilePath;
@property (nonatomic, retain) NSString *outputFilePath;
@property (assign, getter = isCancelled) BOOL cancelled;
@end

@implementation AACTranscoder
@synthesize inputFilePath=_inputFilePath;
@synthesize outputFilePath=_outputFilePath;
@synthesize error=_error;
@synthesize cancelled=_cancelled;
@synthesize bitRate=_bitRate;

+ (BOOL)AACConverterAvailable 
{
	if (_available_set)
	{
		return _available;
	}
	
	// get an array of AudioClassDescriptions for all installed encoders for the given format 
	// the specifier is the format that we are interested in - this is 'aac ' in our case
	UInt32 encoderSpecifier = kAudioFormatMPEG4AAC;
	UInt32 size;
	
	if (!checkResult(AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size),
		"AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders")) return NO;
	
	UInt32 numEncoders = size / sizeof(AudioClassDescription);
	AudioClassDescription encoderDescriptions[numEncoders];
	
	if (!checkResult(AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, encoderDescriptions),
	"AudioFormatGetProperty(kAudioFormatProperty_Encoders")) 
	{
	_available_set = YES;
	_available = NO;
	return NO;
	}
	
	for (UInt32 i=0; i < numEncoders; ++i) 
	{
		if (encoderDescriptions[i].mSubType == kAudioFormatMPEG4AAC_HE)
		{
			_available_set = YES;
			_available = YES;
			return YES;
		}
	}
	
	_available_set = YES;
	_available = NO;
	return NO;
}

- (id)initWithInputFile:(NSString *)inputFilePath outputFile:(NSString *)outputFilePath
{
	self = [super init];
	if (self)
	{
		self.inputFilePath = inputFilePath;
		self.outputFilePath = outputFilePath;
		self.bitRate = kBitRateLow;
	}
	return self;
}

- (BOOL)start
{
	ExtAudioFileRef sourceFile = NULL;
	AudioStreamBasicDescription sourceFormat;
	if (self.inputFilePath) 
	{
		if (!checkResult(ExtAudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:self.inputFilePath], &sourceFile), 
						 "ExtAudioFileOpenURL"))
		{
			self.error = [NSError errorWithDomain:AACAudioConverterErrorDomain
											 code:AACAudioConverterFileError
										 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't open the source file", @"") forKey:NSLocalizedDescriptionKey]];
			return NO;
		}
		
		UInt32 size = sizeof(sourceFormat);
		if (!checkResult(ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat), 
						 "ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat)"))
		{
			self.error = [NSError errorWithDomain:AACAudioConverterErrorDomain
											 code:AACAudioConverterFormatError
										 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't read the source file", @"") forKey:NSLocalizedDescriptionKey]];
			return NO;
		}
	}
	else
	{
		//error
	}
	
	AudioStreamBasicDescription destinationFormat;
	memset(&destinationFormat, 0, sizeof(destinationFormat));
	destinationFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
	destinationFormat.mFormatID = kAudioFormatMPEG4AAC;
	destinationFormat.mSampleRate = 48000;
	UInt32 size = sizeof(destinationFormat);
	if (!checkResult(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat), 
					 "AudioFormatGetProperty(kAudioFormatProperty_FormatInfo)"))
	{
		self.error = [NSError errorWithDomain:AACAudioConverterErrorDomain
										 code:AACAudioConverterFormatError
									 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't setup destination format", @"") forKey:NSLocalizedDescriptionKey]];
		return NO;
	}
	
	ExtAudioFileRef destinationFile;
	if (!checkResult(ExtAudioFileCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:self.outputFilePath], kAudioFileM4AType, &destinationFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile), "ExtAudioFileCreateWithURL")) 
	{
		self.error = [NSError errorWithDomain:AACAudioConverterErrorDomain
										 code:AACAudioConverterFileError
									 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't open the source file", @"") forKey:NSLocalizedDescriptionKey]];
		return NO;
	}
	
	AudioStreamBasicDescription clientFormat;
	if (sourceFormat.mFormatID == kAudioFormatLinearPCM) 
	{
		clientFormat = sourceFormat;
	}
	else
	{
		memset(&clientFormat, 0, sizeof(clientFormat));
		int sampleSize = sizeof(AudioSampleType);
		clientFormat.mFormatID = kAudioFormatLinearPCM;
		clientFormat.mFormatFlags = kAudioFormatFlagsCanonical;
		clientFormat.mBitsPerChannel = 8 * sampleSize;
		clientFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
		clientFormat.mFramesPerPacket = 1;
		clientFormat.mBytesPerPacket = clientFormat.mBytesPerFrame = sourceFormat.mChannelsPerFrame * sampleSize;
		clientFormat.mSampleRate = sourceFormat.mSampleRate;
	}
	
	void (^cleanupBlock)(NSInteger errorCode, NSString *errorDescription) = 
	^ (NSInteger errorCode, NSString *errorDescription) {
		if (sourceFile)
		{
			ExtAudioFileDispose(sourceFile);
		}
		ExtAudioFileDispose(destinationFile);
		if (errorCode < -1)
		{
			self.error = [NSError errorWithDomain:AACAudioConverterErrorDomain
											 code:errorCode
										 userInfo:[NSDictionary dictionaryWithObject:errorDescription forKey:NSLocalizedDescriptionKey]];
		}
	};
	
	size = sizeof(clientFormat);
	if ((sourceFile && !checkResult(ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat), 
									"ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat")) ||
		!checkResult(ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat), 
					 "ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat")) 
	{
		cleanupBlock(AACAudioConverterFormatError, NSLocalizedString(@"Couldn't setup intermediate conversion format", @""));
		return NO;
	}
	
	AudioConverterRef converter;
	size = sizeof(converter);
	if (!checkResult(ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter), 
					 "ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter)"))
	{
		cleanupBlock(AACAudioConverterConverterError, NSLocalizedString(@"Couldn't get destination files audio converter property", @""));
		return NO;
	}
	
	UInt32 bitRate = self.bitRate;
	if (!checkResult(AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate),
					 "AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate)"))
	{
		cleanupBlock(AACAudioConverterConverterError, NSLocalizedString(@"Couldn't set destination files audio converter bit rate", @""));
		return NO;
	}
	
	size = 0;
	if (!checkResult(ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ConverterConfig, sizeof(size), &size),
					 "ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ConverterConfig, sizeof(size), &size)"))
	{
		cleanupBlock(AACAudioConverterConverterError, NSLocalizedString(@"Couldn't reset destination files audio converter configuration", @""));
		return NO;
	}
	
	SInt64 lengthInFrames = 0;
	if (sourceFile)
	{
		size = sizeof(lengthInFrames);
		ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileLengthFrames, &size, &lengthInFrames);
	}
	
	UInt32 bufferByteSize = 32768;
	char srcBuffer[bufferByteSize];
	SInt64 sourceFrameOffset = 0;
	
	while (![self isCancelled])
	{
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = bufferByteSize;
		fillBufList.mBuffers[0].mData = srcBuffer;
		
		UInt32 numFrames = bufferByteSize / clientFormat.mBytesPerFrame;
		
		if ([self isCancelled])
		{
			if (sourceFile)
			{
				ExtAudioFileDispose(sourceFile);
			}
			ExtAudioFileDispose(destinationFile);
			return NO;
		}
		
		if (sourceFile)
		{
			if (!checkResult(ExtAudioFileRead(sourceFile, &numFrames, &fillBufList), "ExtAudioFileRead"))
			{
				ExtAudioFileDispose(sourceFile);
				ExtAudioFileDispose(destinationFile);
				self.error = [NSError errorWithDomain:AACAudioConverterErrorDomain
												 code:AACAudioConverterFormatError
											 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Error reading the source file", @"") forKey:NSLocalizedDescriptionKey]];
				return NO;
			}
		}
		else
		{
			UInt32 length = bufferByteSize;
			numFrames = length / clientFormat.mBytesPerFrame;
			fillBufList.mBuffers[0].mDataByteSize = length;
		}
		
		if (!numFrames)
		{
			break;
		}
		
		sourceFrameOffset += numFrames;
		
		if ([self isCancelled])
		{
			if (sourceFile)
			{
				ExtAudioFileDispose(sourceFile);
			}
			ExtAudioFileDispose(destinationFile);
			return NO;
		}
		
		if (!checkResult(ExtAudioFileWrite(destinationFile, numFrames, &fillBufList), 
						 "ExtAudioFileWrite(destinationFile, numFrames, &fillBufList)"))
		{
			cleanupBlock(AACAudioConverterFileError, NSLocalizedString(@"Error writing the destination file", @""));
			return NO;
		}
	}
	
	cleanupBlock(-1, nil);
	return YES;
}

- (void)cancel
{
	self.cancelled = YES;
}

@end
