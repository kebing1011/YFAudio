
/***********************************************************
 //  YFAudioRecorder.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioRecorder.h"
#import "YFAudioConvert.h"

static const float kMISMessageVoiceMetersRefreshInterval = 0.1;
static const float kMISMessageVoiceLengthRefreshInterval = 0.5;

static YFAudioRecorder* instance = nil;
static NSInteger maxVoiceLength = 60;
static NSInteger minVoiceLength = 1;

@interface RecorderThread : NSThread
@end

@implementation RecorderThread

- (void)main
{
	@autoreleasepool {
		NSTimer* timer = [NSTimer timerWithTimeInterval:10 target:nil selector:nil userInfo:nil repeats:YES];
		
		[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
		
		while (YES) {
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
		}
	}
}

@end



@interface YFAudioRecorder()
@property(nonatomic, strong)NSDictionary* recordSettings;
@property(nonatomic, strong)AVAudioRecorder* recorder;
@property(strong, nonatomic)NSString* cafFilePath;
@property(nonatomic, strong)RecorderThread* thread;
@property(nonatomic, strong)NSTimer* recordTimer;
@property(nonatomic, strong)NSTimer* refreshMetersTimer;
@property(nonatomic, strong)NSTimer* refreshLengthTimer;
@property(nonatomic, assign)float lowPassResults;
@property(nonatomic, assign)NSInteger voiceLength;

@end

@implementation YFAudioRecorder

+ (YFAudioRecorder *)shareRecorder
{
	@synchronized(self)
	{
		if (instance == nil)
		{
			instance = [[YFAudioRecorder alloc] init];
		}
	}
	
	return instance;
}

+ (void)setMaxVoiceLength:(NSInteger)length
{
	@synchronized(self)
	{
		maxVoiceLength = length;
	}
}

+ (NSInteger )maxVoiceLength
{
	@synchronized(self)
	{
		return maxVoiceLength;
	}
}

+ (void)setMinVoiceLength:(NSInteger)length
{
	@synchronized(self)
	{
		minVoiceLength = length;
	}
}
+ (NSInteger )minVoiceLength
{
	@synchronized(self)
	{
		return minVoiceLength;
	}
}

- (id)init
{
	self = [super init];
	if (self)
	{
		self.thread = [[RecorderThread alloc] init];
		[self.thread start];
		self.enableLength = YES;
		self.enableMeters = YES;
	}
	return self;
}

- (NSDictionary *)recordSettings
{
	if (_recordSettings == nil)
	{
		NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] initWithCapacity:4];
		[recordSettings setObject:[NSNumber numberWithInt: kAudioFormatLinearPCM] forKey: AVFormatIDKey];
		[recordSettings setObject:[NSNumber numberWithFloat:8000.0] forKey: AVSampleRateKey];
		[recordSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
		[recordSettings setObject:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
		_recordSettings = [NSDictionary dictionaryWithDictionary:recordSettings];
	}
	return _recordSettings;
}


- (void)startRecord
{
	[self performSelector:@selector(doStartRecordTask) onThread:self.thread withObject:nil waitUntilDone:NO];
}
- (void)stopRecord
{
	[self performSelector:@selector(doStopRecordTask) onThread:self.thread withObject:nil waitUntilDone:NO];
}

- (void)invalitateTimers
{
	if ([self.recordTimer isValid])
	{
		[self.recordTimer invalidate];
		self.recordTimer = nil;
	}
	
	if ([self.refreshMetersTimer isValid])
	{
		[self.refreshMetersTimer invalidate];
		self.refreshMetersTimer = nil;
	}
	
	if ([self.refreshLengthTimer isValid])
	{
		[self.refreshLengthTimer invalidate];
		self.refreshLengthTimer = nil;
	}
	
}

- (void)doStopRecordTask
{
	//取消timer
	[self invalitateTimers];
	
	//有这个可以区分是否能停止录音。以免重复得到
	if (self.recorder == nil)
	{
		return;
	}
	
	self.voiceLength = nearbyint(self.recorder.currentTime);
	
	if (self.voiceLength < [YFAudioRecorder minVoiceLength])
	{
		//时间小放弃编码＋提示
		[self notifyDelegateInMainThreadWith:RecorderErrorTooShort];
	}
	
	[self.recorder stop];
}

- (void)cancelRecord
{
	[self performSelector:@selector(doCancelRecordTask) onThread:self.thread withObject:nil waitUntilDone:NO];
}

- (void)doCancelRecordTask
{
	self.recorder.delegate = nil;
	[self.recorder stop];
	[self performSelectorInBackground:@selector(notifyDelegateCancelRecord) withObject:nil];
}

- (void)clearDeleateAndCanceRecorder
{
	[self cancelRecord];
	self.delegate = nil;
}

- (void)checkRecordAvailableBlock:(void(^)(BOOL available))block
{
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	
	if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
        
        [audioSession requestRecordPermission:^(BOOL available) {
            block(available);
        }];
    }
	else
	{
		block(YES);
	}
}


- (void)doStartRecordTask
{
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];

	BOOL isSpeakerMode = self.isSpeakerMode;
	if (isSpeakerMode == YES)
	{
		[audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
	}
	else
	{
		[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
	}
	
	[audioSession setActive:YES error:nil];
	
	//create a .caf file use timestamp
	NSString* fileName = [NSString stringWithFormat:@"%.0f.caf", [[NSDate date] timeIntervalSince1970]];
	self.cafFilePath = [self tempPath:fileName];
	NSURL* url = [NSURL fileURLWithPath:self.cafFilePath];
	
	NSError *error = nil;
	self.recorder = [[ AVAudioRecorder alloc] initWithURL:url settings:self.recordSettings error:&error];
	self.recorder.delegate = self;
	self.recorder.meteringEnabled = YES;
	self.voiceLength = 0;
	
	if ([self.recorder prepareToRecord])
	{
		[self.recorder record];
		
		//取消timer
		[self invalitateTimers];
		
		
		//计时timer+计时开始
		self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:[YFAudioRecorder maxVoiceLength] target:self selector:@selector(stopRecord) userInfo:nil repeats:NO];
		
		//刷新timer-meters
		if (self.enableMeters)
		{
			self.refreshMetersTimer = [NSTimer scheduledTimerWithTimeInterval:kMISMessageVoiceMetersRefreshInterval target:self selector:@selector(updateMeters) userInfo:nil repeats:YES];
		}
		
		//刷新timer-length
		if (self.enableLength)
		{
			self.refreshLengthTimer = [NSTimer scheduledTimerWithTimeInterval:kMISMessageVoiceLengthRefreshInterval target:self selector:@selector(updateLength) userInfo:nil repeats:YES];
		}
		
		//通知主线程开始录音
		[self performSelectorOnMainThread:@selector(notifyDelegateStartRecord) withObject:nil waitUntilDone:NO];
	}
	else
	{
		[self notifyDelegateInMainThreadWith:RecorderErrorStart];
	}
}


- (NSString *)tempPath:(NSString *)fileName
{
	NSString* tempDrectry = NSTemporaryDirectory();
	return [tempDrectry stringByAppendingPathComponent:fileName];
}

- (void)updateMeters
{
	[self performSelector:@selector(doUpdateMetersTask) onThread:self.thread withObject:nil waitUntilDone:NO];
}


- (void)doUpdateMetersTask
{
	if (!self.recorder.isRecording)
	{
		return;
	}
	
	[self.recorder updateMeters];
	
	self.lowPassResults = pow(10, (0.05 * [self.recorder peakPowerForChannel:0]));
	
	[self performSelectorOnMainThread:@selector(notifyDelegateRecordingWithMeters:) withObject:[NSNumber numberWithFloat:self.lowPassResults] waitUntilDone:NO];
}

- (void)updateLength
{
	[self performSelector:@selector(doUpdateLengthTask) onThread:self.thread withObject:nil waitUntilDone:NO];
}

- (void)doUpdateLengthTask
{
	if (!self.recorder.isRecording)
	{
		return;
	}
	
	self.voiceLength = nearbyint(self.recorder.currentTime);
	
	[self performSelectorOnMainThread:@selector(notifyDelegateRecordingWithLength:) withObject:[NSNumber numberWithFloat:self.voiceLength] waitUntilDone:NO];
}


- (void)notifyDelegateStartRecord
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(didStartRecord)])
	{
		[self.delegate performSelector:@selector(didStartRecord)];
	}
}

- (void)notifyDelegateRecordingWithMeters:(NSNumber* )metersNumber
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(didRecordingWithMeters:)])
	{
		[self.delegate didRecordingWithMeters:metersNumber.floatValue];
	}
}

- (void)notifyDelegateRecordingWithLength:(NSNumber* )metersNumber
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(didRecordingWithLength:)])
	{
		[self.delegate didRecordingWithLength:metersNumber.floatValue];
	}
}

- (void)notifyDelegateRecordFailed:(NSNumber *)error
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(didRecordFailedWithError:)])
	{
		[self.delegate didRecordFailedWithError:error.intValue];
	}
}
- (void)notifyDelegateRecordFinishedWithInfo:(NSDictionary *)info
{
	NSString* filePath = [info valueForKey:@"filePath"];
	NSNumber* lengthNum = [info valueForKey:@"length"];
	if (self.delegate && [self.delegate respondsToSelector:@selector(didRecordFinishedWithFilePath:length:)])
	{
		[self.delegate didRecordFinishedWithFilePath:filePath length:lengthNum.integerValue];
	}
}
- (void)notifyDelegateCancelRecord
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(didCancelRecord)])
	{
		[self.delegate performSelector:@selector(didCancelRecord)];
	}
}

- (void)notifyDelegateInMainThreadWith:(RecorderError )error
{
	[self performSelectorOnMainThread:@selector(notifyDelegateRecordFailed:) withObject:[NSNumber numberWithInteger:error] waitUntilDone:NO];
}

- (void)doStartEncodeTask
{
	//如果不存在
	if (self.cafFilePath == nil || ![[NSFileManager defaultManager] fileExistsAtPath:self.cafFilePath])
	{
		[self notifyDelegateInMainThreadWith:RecorderErrorEncode];
		return;
	}
	
	//开始转码
	NSData* wavData = [NSData dataWithContentsOfFile:self.cafFilePath];
	NSData* amrData = [YFAudioConvert amrDataFromWaveData:wavData];
	
	NSString* fileName = [NSString stringWithFormat:@"%.0f.amr", [[NSDate date] timeIntervalSince1970]];
	NSString* filePath = [self cachePathForMedia:fileName];
	[amrData writeToFile:filePath atomically:YES];
	
	//通知到主线程
	self.voiceLength = MIN([YFAudioRecorder maxVoiceLength], self.voiceLength);
	self.voiceLength = MAX([YFAudioRecorder minVoiceLength], self.voiceLength);
	
	NSNumber* lengthNumber = [NSNumber numberWithInteger:self.voiceLength];
	NSDictionary* info = @{@"filePath":filePath, @"length":lengthNumber};
	
	[self performSelectorOnMainThread:@selector(notifyDelegateRecordFinishedWithInfo:) withObject:info waitUntilDone:NO];
}

- (NSString *)cachePathForMedia:(NSString *)fileName
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* diskCachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Cache"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:diskCachePath])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
								  withIntermediateDirectories:YES
												   attributes:nil
														error:NULL];
	}
	
	//only filename filter path or url
	NSString *filename_ = fileName;
	NSRange range = [filename_ rangeOfString:@"/"];
	
	while (range.length > 0)
	{
		filename_ = [filename_ substringFromIndex:range.location + 1];
		range = [filename_ rangeOfString:@"/"];
	}
	
	return [diskCachePath stringByAppendingPathComponent:filename_];
}

#pragma mark ==========AVAudioRecorderDelegate==================================
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
	if (flag)
	{
		//结束时间戳
		if (self.voiceLength < [YFAudioRecorder minVoiceLength])
		{
			//时间小放弃编码＋提示
			return;
		}
		
		if (self.voiceLength >= [YFAudioRecorder maxVoiceLength])
		{
			//时间长编码＋提示
			[self notifyDelegateInMainThreadWith:RecorderErrorTooLong];
		}
		
		[self performSelector:@selector(doStartEncodeTask) onThread:self.thread withObject:nil waitUntilDone:NO];
	}
	else
	{
		[self notifyDelegateInMainThreadWith:RecorderErrorFinish];

	}
	
	self.recorder.delegate = nil;
	self.recorder = nil;
}

/* if an error occurs while encoding it will be reported to the delegate. */
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
	[self notifyDelegateInMainThreadWith:RecorderErrorStart];
	self.recorder.delegate = nil;
	self.recorder = nil;

}

@end
