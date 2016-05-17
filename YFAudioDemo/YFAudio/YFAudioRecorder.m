
/***********************************************************
 //  YFAudioRecorder.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioRecorder.h"
#import "YFAudioConvert.h"

static const float YFAudioRecorderRefreshInterval = 0.1f;
static  NSInteger YFAudioRecorderMaxVoiceLength   = 60;
static  NSInteger YFAudioRecorderMinVoiceLength   = 1;

@interface YFAudioRecorder()

@property (nonatomic, strong) AVAudioRecorder* recorder;
@property (nonatomic, strong) NSString* cafFilePath;
@property (nonatomic, strong) NSTimer* refreshTimer;
@property (nonatomic) NSInteger voiceLength;
@property (nonatomic) YFRecordPermission recordPermission;

@end

@implementation YFAudioRecorder

/**
 *  线程切入点
 */
+ (void)threadEntryPoint {
	@autoreleasepool {
		[[NSThread currentThread] setName:@"YFRecorderThread"];
		NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
		[runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
		[runLoop run];
	}
}

/**
 *  共享线程
 *
 *  @return NSThread
 */
+ (NSThread *)operateThread {
	static NSThread *_operateThread = nil;
	static dispatch_once_t oncePredicate;
	dispatch_once(&oncePredicate, ^{
		_operateThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadEntryPoint) object:nil];
		[_operateThread start];
	});
	return _operateThread;
}

/**
 *  录音唯一入口
 *
 *  @return 单例
 */
+ (YFAudioRecorder *)shareRecorder {
	static YFAudioRecorder* instance = nil;
	static dispatch_once_t oncePredicate;
	dispatch_once(&oncePredicate, ^{
		instance = [[YFAudioRecorder alloc] init];
	});
	
	return instance;
}

/**
 *  设定最大录音时长
 *
 *  @param length 时长 - 单位:秒
 */
+ (void)setMaxVoiceLength:(NSInteger)length {
	YFAudioRecorderMaxVoiceLength = length;
}

+ (NSInteger )maxVoiceLength {
	return YFAudioRecorderMaxVoiceLength;
}

/**
 *  设定最小录音时长
 *
 *  @param length 时长 - 单位:秒
 */
+ (void)setMinVoiceLength:(NSInteger)length {
		YFAudioRecorderMinVoiceLength = length;
}

+ (NSInteger )minVoiceLength {
	return YFAudioRecorderMinVoiceLength;
}


#pragma Life Cycle

- (instancetype)init {
	self = [super init];
	if (self) {
		[[self class] operateThread];
		
		[self checkRecordPermiss];
	}
	return self;
}

- (void)checkRecordPermiss {
	//for ios8.0+
	if ([AVAudioSession instancesRespondToSelector:@selector(recordPermission)]) {
		AVAudioSessionRecordPermission permission = [AVAudioSession sharedInstance].recordPermission;
		switch (permission) {
			case AVAudioSessionRecordPermissionUndetermined:
				self.recordPermission = YFRecordPermissionUndetermined;
				break;
			case AVAudioSessionRecordPermissionDenied:
				self.recordPermission = YFRecordPermissionDenied;
				break;
			case AVAudioSessionRecordPermissionGranted:
				self.recordPermission = YFRecordPermissionGranted;
				break;
			default:
				break;
		}
	} else if ([AVAudioSession instancesRespondToSelector:@selector(requestRecordPermission:)]) {
		self.recordPermission = YFRecordPermissionNone;
	}
	else {
		self.recordPermission = YFRecordPermissionGranted;
	}
}

- (NSDictionary *)recordSettings {
	return @{
			 AVFormatIDKey:@(kAudioFormatLinearPCM),
			 AVSampleRateKey:@8000.0f,
			 AVNumberOfChannelsKey:@1,
			 AVLinearPCMBitDepthKey:@16
			 };
}

#pragma mark - Public Methods

/**
 *  开始录音
 */
- (void)startRecord {
	[self performSelector:@selector(doStartRecordTask) onThread:[[self class] operateThread] withObject:nil waitUntilDone:NO];
}

/**
 *  停止录音
 */
- (void)stopRecord {
	[self performSelector:@selector(doStopRecordTask) onThread:[[self class] operateThread] withObject:nil waitUntilDone:NO];
}

/**
 *  取消录音
 */
- (void)cancelRecord
{
	[self performSelector:@selector(doCancelRecordTask) onThread:[[self class] operateThread] withObject:nil waitUntilDone:NO];
}


/**
 *  重置回调
 */
- (void)clearDeleateAndCanceRecorder
{
	[self cancelRecord];
	self.delegate = nil;
}

/**
 *  授权检查
 *
 *  @param block 回调
 */
- (void)checkRecordAvailableBlock:(void(^)(BOOL available))block
{
	if (self.recordPermission == YFRecordPermissionGranted)
	{
		block(YES);
		return;
	}
	
	if (self.recordPermission == YFRecordPermissionDenied)
	{
		block(NO);
		return;
	}
	
	
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	
	if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
		
		[audioSession requestRecordPermission:^(BOOL available) {
			block(available);
			if (available)
			{
				self.recordPermission = YFRecordPermissionGranted;
			}
			else
			{
				self.recordPermission = YFRecordPermissionDenied;
			}
		}];
		
		//异步来计算是不是
		if (self.recordPermission == YFRecordPermissionNone)
		{
			self.recordPermission = YFRecordPermissionUndetermined;
		}
	}
}

#pragma mark - Private Methods

/**
 *  禁用 timer
 */
- (void)invalitateTimers {
	if ([self.refreshTimer isValid]) {
		[self.refreshTimer invalidate];
		self.refreshTimer = nil;
	}
}

/**
 *  停止完成录音任务
 */
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
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([self.delegate respondsToSelector:@selector(didRecordFailedWithError:)]) {
				[self.delegate didRecordFailedWithError:YFRecorderErrorTooShort];
			}
		});
	
		//回调重置
		self.recorder.delegate = nil;
	}
	
	[self.recorder stop];
}

/**
 *  取消录音任务
 */
- (void)doCancelRecordTask
{
	self.recorder.delegate = nil;
	[self.recorder stop];
	
	//通知代理
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([self.delegate respondsToSelector:@selector(didCancelRecord)]) {
			[self.delegate didCancelRecord];
		}
	});
}

/**
 *  开始录音任务
 */
- (void)doStartRecordTask {
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];
	
	//create a .caf file use timestamp
	NSString* fileName = [NSString stringWithFormat:@"%.0f.caf", [[NSDate date] timeIntervalSince1970]];
	self.cafFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
	NSURL* url = [NSURL fileURLWithPath:self.cafFilePath];

	//创建录音者
	NSError *error = nil;
	self.recorder = [[AVAudioRecorder alloc] initWithURL:url settings:self.recordSettings error:&error];
	self.recorder.delegate = self;
	self.recorder.meteringEnabled = YES;
	self.voiceLength = 0;
	
	
	//取消timer
	[self invalitateTimers];
	
	/**
	 *  开始录音
	 */
	if ([self.recorder prepareToRecord]) {
		[self.recorder recordForDuration:[YFAudioRecorder maxVoiceLength]];
		
		//创建更新的 timer
		self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:YFAudioRecorderRefreshInterval target:self selector:@selector(refreshRecordingInfo) userInfo:nil repeats:YES];
		
		//通知主线程开始录音
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([self.delegate respondsToSelector:@selector(didStartRecord)]) {
				[self.delegate performSelector:@selector(didStartRecord)];
				[self.delegate didStartRecord];
			}
		});
		
	} else {
		//通知主线程录音出错
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([self.delegate respondsToSelector:@selector(didRecordFailedWithError:)]) {
				[self.delegate didRecordFailedWithError:YFRecorderErrorStart];
			}
		});
	}
}

/**
 *  刷新录音信息
 */
- (void)refreshRecordingInfo {
	if (!self.recorder.isRecording) {
		return;
	}
	
	//更新电平指示
	[self.recorder updateMeters];
	float peakPowerValue = pow(10, (0.05 * [self.recorder peakPowerForChannel:0]));
	
	//获取时长
	NSTimeInterval interval = self.recorder.currentTime;
	self.voiceLength = nearbyint(interval);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		//更新电平
		if ([self.delegate respondsToSelector:@selector(didRecordingWithMeters:)]) {
			[self.delegate didRecordingWithMeters:peakPowerValue];
		}
		
		//更新录音时长
		if ([self.delegate respondsToSelector:@selector(didRecordingWithLength:)]) {
			[self.delegate didRecordingWithLength:interval];
		}
	});
}

/**
 *  启动编码任务
 */
- (void)doStartEncodeTask
{
	//如果不存在
	if (![[NSFileManager defaultManager] fileExistsAtPath:self.cafFilePath]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			//通知代理长度
			if ([self.delegate respondsToSelector:@selector(didRecordFailedWithError:)]) {
				[self.delegate didRecordFailedWithError:YFRecorderErrorEncode];
			}
		});
		
		return;
	}
	
	//开始转码
	NSData* wavData = [NSData dataWithContentsOfFile:self.cafFilePath];
	NSData* amrData = [YFAudioConvert amrDataFromWaveData:wavData];
	
	NSString* fileName = [NSString stringWithFormat:@"%.0f.amr", [[NSDate date] timeIntervalSince1970]];
	NSString* filePath = [self cachePathForMedia:fileName];
	[amrData writeToFile:filePath atomically:YES];
	
	//计算长度
	self.voiceLength = MIN([YFAudioRecorder maxVoiceLength], self.voiceLength);
	self.voiceLength = MAX([YFAudioRecorder minVoiceLength], self.voiceLength);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		//通知代理长度
		if ([self.delegate respondsToSelector:@selector(didRecordFinishedWithFilePath:length:)]) {
			[self.delegate didRecordFinishedWithFilePath:filePath length:self.voiceLength];
		}
	});
}

/**
 *  设定输出文件目录
 *
 *  @param fileName 文件名
 *
 *  @return 完成文件目录
 */
- (NSString *)cachePathForMedia:(NSString *)fileName
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* diskCachePath = [paths[0] stringByAppendingPathComponent:@"Cache"];
	
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

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
	if (flag) {
		//开始转码
		[self performSelector:@selector(doStartEncodeTask) onThread:[[self class] operateThread] withObject:nil waitUntilDone:NO];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			//通知代理出错了
			if ([self.delegate respondsToSelector:@selector(didRecordFailedWithError:)]) {
				[self.delegate didRecordFailedWithError:YFRecorderErrorFinish];
			}
		});
	}
	
	self.recorder.delegate = nil;
	self.recorder = nil;
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
	dispatch_async(dispatch_get_main_queue(), ^{
		//通知代理出错了
		if ([self.delegate respondsToSelector:@selector(didRecordFailedWithError:)]) {
			[self.delegate didRecordFailedWithError:YFRecorderErrorEncode];
		}
	});
	
	self.recorder.delegate = nil;
	self.recorder = nil;
}

@end
