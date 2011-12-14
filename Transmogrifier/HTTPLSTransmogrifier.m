//
//  HTTPLSTransmogrifier.m
//  Transmogrifier
//
//  Created by  on 12/10/11.
//  Copyright (c) 2011 Doug Russell. All rights reserved.
//

#import "HTTPLSTransmogrifier.h"
#import "AACTranscoder.h"

@interface HTTPLSTransmogrifier ()
{
	dispatch_semaphore_t tasksSemaphore;
	dispatch_semaphore_t encodingSemaphore;
}
@property (strong) NSMutableArray *files;
@property (strong) NSMutableArray *resultFiles;
@property (strong) NSMutableArray *tasks;
@property (assign, getter = isCancelled) BOOL cancelled;
@property (assign, getter = isProcessing) BOOL processing;
- (void)addTask:(id)task;
@end

@implementation HTTPLSTransmogrifier
{
	UInt32 *_bitRates;
	NSInteger _bitRateCount;
}
@synthesize delegate=_delegate;
@synthesize files=_files;
@synthesize resultFiles=_resultFiles;
@synthesize acceptableFileTypes=_acceptableFileTypes;
@synthesize cancelled=_cancelled;
@synthesize processing=_processing;
@synthesize tasks=_tasks;

static dispatch_queue_t processingQueue;
static dispatch_queue_t dispatch_get_processing_queue(void)
{
	if (processingQueue == nil)
	{
		processingQueue = dispatch_queue_create("com.es.processingqueue", DISPATCH_QUEUE_CONCURRENT);
		dispatch_set_target_queue(processingQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
	}
	return processingQueue;
}

- (id)init
{
	self = [super init];
	if (self)
	{
		tasksSemaphore = dispatch_semaphore_create(1);
		encodingSemaphore = dispatch_semaphore_create([[NSProcessInfo processInfo] processorCount]);
		_files = [NSMutableArray new];
		_resultFiles = [NSMutableArray new];
		_tasks = [NSMutableArray new];
		_bitRateCount = 2;
		_bitRates = malloc(sizeof(UInt32)*_bitRateCount);
		_bitRates[0] = kBitRateLow;
		_bitRates[2] = kBitRateHigh;
		self.acceptableFileTypes = [NSSet setWithObjects:
									@"mp3", 
									@"m4a", 
									@"aac", 
									@"wav", 
									@"aif", 
									@"aiff", 
									@"caf",
									nil];
	}
	return self;
}

- (void)dealloc
{
	free(_bitRates);
	dispatch_release(tasksSemaphore);
	dispatch_release(encodingSemaphore);
}

- (void)start
{
	self.processing = YES;
	dispatch_group_t group = dispatch_group_create();
	dispatch_queue_t hi = dispatch_get_processing_queue();
	for (NSString *filePath in self.files)
	{
		@autoreleasepool {
			if ([self isCancelled])
				break;
			dispatch_group_async(group, hi, ^{
				NSString *fileBaseName = [[filePath lastPathComponent] stringByDeletingPathExtension];
				NSString *basePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileBaseName];
				// Make sure our folder isn't already there
				BOOL isDir;
				NSFileManager *manager = [NSFileManager defaultManager];
				if ([manager fileExistsAtPath:basePath isDirectory:&isDir])
				{
					[manager removeItemAtPath:basePath error:nil];
				}
				// Make working folder
				[manager createDirectoryAtPath:basePath withIntermediateDirectories:NO attributes:nil error:nil];
				
				if ([self isCancelled])
					return;
				// Convert audio files
				dispatch_group_t encodeGroup = dispatch_group_create();
				for (int i = 0; i < _bitRateCount; i++)
				{
					dispatch_group_async(encodeGroup, hi, ^{
						if ([self isCancelled])
							return;
						dispatch_semaphore_wait(encodingSemaphore, DISPATCH_TIME_FOREVER);
						if ([self isCancelled])
						{
							dispatch_semaphore_signal(encodingSemaphore);
							return;
						}
						// Paths for audio intermediate files
						NSString *audioPath = [[[basePath stringByAppendingPathComponent:fileBaseName] stringByAppendingFormat:@"%04d", i] stringByAppendingPathExtension:@"m4a"];
						
						BOOL isDir;
						NSString *segmentsFolder = [basePath stringByAppendingFormat:@"/%04d", i];
						if ([manager fileExistsAtPath:segmentsFolder isDirectory:&isDir])
						{
							[manager removeItemAtPath:segmentsFolder error:nil];
						}
						// Make working folder
						[manager createDirectoryAtPath:segmentsFolder withIntermediateDirectories:NO attributes:nil error:nil];
						
						AACTranscoder *transcoder = [[AACTranscoder alloc] initWithInputFile:filePath outputFile:audioPath];
						transcoder.bitRate = _bitRates[i];
						[self addTask:transcoder];
						[transcoder start];
						dispatch_semaphore_signal(encodingSemaphore);
					});
				}
				dispatch_group_wait(encodeGroup, DISPATCH_TIME_FOREVER);
				dispatch_release(encodeGroup);
				if ([self isCancelled])
					return;
				// segment audio
				dispatch_group_t segmentGroup = dispatch_group_create();
				for (int i = 0; i < _bitRateCount; i++)
				{
					dispatch_group_async(segmentGroup, hi, ^{
						if ([self isCancelled])
							return;
						NSString *audioPath = [[[basePath stringByAppendingPathComponent:fileBaseName] stringByAppendingFormat:@"%04d", i] stringByAppendingPathExtension:@"m4a"];
						NSString *segmentsFolder = [basePath stringByAppendingFormat:@"/%04d", i];
						NSArray *args = [NSArray arrayWithObjects:
										 @"-q", 
#if !USE_FLOATING_DURATIONS
										 @"--no-floating-point-duration",
#endif
										 @"-t", @"10",
										 @"-f", segmentsFolder,
										 @"-a",
										 @"-I",
										 audioPath,
										 nil];
						NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/mediafilesegmenter" arguments:args];
						[self addTask:task];
						[task waitUntilExit];
					});
				}
				dispatch_group_wait(segmentGroup, DISPATCH_TIME_FOREVER);
				dispatch_release(segmentGroup);
				if ([self isCancelled])
					return;
				NSString *variantPlaylist = [basePath stringByAppendingPathComponent:[fileBaseName stringByAppendingPathExtension:@"m3u8"]];
				NSMutableArray *args = [NSMutableArray arrayWithObjects:
										@"-o", variantPlaylist,
										nil];
				for (int i = 0; i < _bitRateCount; i++)
				{
					[args addObject:[NSString stringWithFormat:@"%04d/prog_index.m3u8", i]];
					[args addObject:[[[basePath stringByAppendingPathComponent:fileBaseName] stringByAppendingFormat:@"%04d", i] stringByAppendingPathExtension:@"plist"]];
				}
				NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/variantplaylistcreator" arguments:args];
				[self addTask:task];
				[task waitUntilExit];
				// Remove this file from the list of files being processed
				dispatch_async(dispatch_get_main_queue(), ^{
					NSMutableArray *results = [NSMutableArray arrayWithObjects:
											   [NSURL fileURLWithPath:variantPlaylist],
											   nil];
					for (int i = 0; i < _bitRateCount; i++)
					{
						NSString *segmentsFolder = [basePath stringByAppendingFormat:@"/%04d", i];
						NSArray *contents = [manager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:segmentsFolder] 
												   includingPropertiesForKeys:nil 
																	  options:NSDirectoryEnumerationSkipsHiddenFiles
																		error:nil];
						if (contents)
						{
							[results addObjectsFromArray:contents];
						}
					}
					[self.resultFiles addObjectsFromArray:results];
					[self.files removeObject:filePath];
					[self.delegate transmogrifier:self fileDidComplete:filePath];
				});
				// Clean up intermediates
				for (int i = 0; i < _bitRateCount; i++)
				{
					//continue; //Uncomment to leave all the intermediate files in place
					[manager removeItemAtPath:[[[basePath stringByAppendingPathComponent:fileBaseName] stringByAppendingFormat:@"%04d", i] stringByAppendingPathExtension:@"m4a"] error:nil];
					[manager removeItemAtPath:[[[basePath stringByAppendingPathComponent:fileBaseName] stringByAppendingFormat:@"%04d", i] stringByAppendingPathExtension:@"plist"] error:nil];
				}
			});
		}
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		dispatch_release(group);
		if (!self.cancelled)
			[self.delegate transmogrifierDidComplete:self];
		self.cancelled = NO;
		self.processing = NO;
	});
}

- (void)addTask:(id)task
{
	if (task == nil)
		return;
	dispatch_semaphore_wait(tasksSemaphore, DISPATCH_TIME_FOREVER);
	[self.tasks addObject:task];
	dispatch_semaphore_signal(tasksSemaphore);
}

- (void)addFiles:(NSArray *)files
{
	if (files == nil)
		return;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSArray *newFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
			return [self.acceptableFileTypes containsObject:[[(NSString *)evaluatedObject pathExtension] lowercaseString]];
		}]];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.files addObjectsFromArray:newFiles];
			[self.delegate transmogrifier:self didAddFiles:newFiles];
		});
	});
}

- (void)cancel
{
	self.cancelled = YES;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		dispatch_semaphore_wait(tasksSemaphore, DISPATCH_TIME_FOREVER);
		for (id task in self.tasks)
		{
			if ([task respondsToSelector:@selector(terminate)])
			{
				[(NSTask *)task terminate];
			}
			else if ([task respondsToSelector:@selector(cancel)])
			{
				[(AACTranscoder *)task cancel];
			}
		}
		[self.tasks removeAllObjects];
		dispatch_semaphore_signal(tasksSemaphore);
	});
}

- (void)clear
{
	if ([self isProcessing])
	{
		[NSException raise:@"Clear During Processing Exception" format:@"Attempted to clear files array during processing"];
	}
	[self.files removeAllObjects];
	[self.resultFiles removeAllObjects];
}

- (void)setBitrates:(UInt32 *)bitRates count:(NSInteger)count
{
	if ([self isProcessing])
	{
		[NSException raise:@"Set Bitrates During Processing Exception" format:@"Attempted to set bitrates of transmogrifier during processing"];
	}
	if (_bitRateCount < count)
	{
		_bitRates = realloc(_bitRates, sizeof(UInt32)*count);
	}
	_bitRateCount = count;
	memcpy(_bitRates, bitRates, sizeof(UInt32)*count);
}

@end
