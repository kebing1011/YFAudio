
/***********************************************************
 //  YFAudioPlayer.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioPlayer.h"
#import "YFAudioConvert.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

static const float kMISMessageVoiceLengthRefreshInterval = 0.5;
static BOOL YFAudioPlayerProximityMonitoringEnabled = YES;
static SystemSoundID YFAudioPlayerFinishedEffectSoundID = 0;
static YFAudioPlayerPlayMode YFPlayMode = YFAudioPlayerPlayModeSpeaker;


@interface YFAudioPlayer()
@property (nonatomic, weak) id<YFAudioPlayerDelegate>delegate;
@property (nonatomic, strong) AVAudioPlayer* player;
@property (nonatomic) BOOL isPlaying;
@property (nonatomic, strong) NSTimer* refreshLengthTimer;
@end

@implementation YFAudioPlayer

+ (YFAudioPlayer *)sharePlayer
{
	static YFAudioPlayer* instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[YFAudioPlayer alloc] init];
	});
	
	return instance;
}

+ (void)setProximityMonitoringEnabled:(BOOL)flag {
	YFAudioPlayerProximityMonitoringEnabled = flag;
}

+ (void)setPlayMode:(YFAudioPlayerPlayMode)mode {
	YFPlayMode = mode;
}

+ (YFAudioPlayerPlayMode)playMode {
	return YFPlayMode;
}

+ (void)setPlayFinishedSoundEffectFileName:(NSString *)fileName {
	static dispatch_once_t onceToken;
	__block SystemSoundID theSoundID = 0;
	dispatch_once(&onceToken, ^{
		NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
		NSURL* fileURL = [NSURL fileURLWithPath:filePath];
		OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)fileURL, &theSoundID);
		if (error != kAudioServicesNoError) {
			NSLog(@"%@, Faild to create sound!", fileName);
		} else {
			YFAudioPlayerFinishedEffectSoundID = theSoundID;
		}
	});
}

#pragma mark - Lifecycle

- (instancetype)init {
	self = [super init];
	if (self) {
		self.enableLength = YES;
		
		[UIDevice currentDevice].proximityMonitoringEnabled = YES;

		//距离感应 通知
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(proximityStateDidChangeNotification:)
													 name:UIDeviceProximityStateDidChangeNotification object:nil];
		
		//App挂起
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillResignActiveNotification:)
													 name:UIApplicationWillResignActiveNotification object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Public Methods

- (void)startPlayAudioWithPath:(NSString *)filePath
					  delegate:(id<YFAudioPlayerDelegate>)delegate {
	[self stopPlay];
	
	if(YFAudioPlayerProximityMonitoringEnabled) {
		[UIDevice currentDevice].proximityMonitoringEnabled = YES;
	}
	
	self.delegate = delegate;
	
	//距离近时-强制使用听筒
	if ([UIDevice currentDevice].proximityState) {
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
	}else{
		if (YFPlayMode == YFAudioPlayerPlayModeSpeaker) {
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
		}else if(YFPlayMode == YFAudioPlayerPlayModeEarphone) {
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
		}
	}
	
	//解码
	NSData* amrData = [NSData dataWithContentsOfFile:filePath];
	NSData* wavData = [YFAudioConvert wavDataFromAmrData:amrData];
	
	//播放
	self.player = [[AVAudioPlayer alloc] initWithData:wavData error:nil];
	self.player.numberOfLoops = 0;
	self.player.delegate = self;
	[self.player play];
	self.isPlaying = YES;
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(didStartPlay)])
	{
		[self.delegate didStartPlay];
	}
	
	//取消timer
	if (self.refreshLengthTimer && [self.refreshLengthTimer isValid])
	{
		[self.refreshLengthTimer invalidate];
		self.refreshLengthTimer = nil;
	}
	
	//刷新timer-length
	if (self.enableLength)
	{
		self.refreshLengthTimer = [NSTimer scheduledTimerWithTimeInterval:kMISMessageVoiceLengthRefreshInterval target:self selector:@selector(updateLength) userInfo:nil repeats:YES];
	}
}


- (void)stopPlay
{
	[self.player stop];
	self.isPlaying = NO;

	
	if (self.delegate && [self.delegate respondsToSelector:@selector(didStopPlay)])
	{
		[self.delegate didStopPlay];
	}
}


- (void)clearDeleateAndCancePlay
{
	self.delegate = nil;
	[self stopPlay];
}

- (BOOL)isPlayWithDelegate:(id<YFAudioPlayerDelegate>)delegate
{
	if (delegate == self.delegate && self.isPlaying)
	{
		return YES;
	}
	
	return NO;
}

#pragma mark - Private Methods

- (void)updateLength
{
	if (!self.player.isPlaying)
	{
		return;
	}
	
	int length = nearbyint(self.player.currentTime);
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(didPlayingWithLength:)])
	{
		[self.delegate didPlayingWithLength:length];
	}
}

- (void)playFinishedEffectSound {
	if (YFAudioPlayerFinishedEffectSoundID) {
		AudioServicesPlaySystemSound(YFAudioPlayerFinishedEffectSoundID);
	}
}

#pragma mark - Notifactions

- (void)proximityStateDidChangeNotification:(NSNotification *)notifaction {
	//距离感应时，使用听筒
	if ([UIDevice currentDevice].proximityState) {
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
	}else{
		if (YFPlayMode == YFAudioPlayerPlayModeSpeaker) {
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
		}else if(YFPlayMode == YFAudioPlayerPlayModeEarphone) {
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
		}
		
		//回复状态
		if (![self isPlaying]) {
			[UIDevice currentDevice].proximityMonitoringEnabled = NO;
		}
	}
}

- (void)applicationWillResignActiveNotification:(NSNotification *)notifaction {
	[self stopPlay];
}


#pragma mark =============AVAudioPlayerDelegate====================================

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	[self playFinishedEffectSound];
	
	[self stopPlay];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
	[self stopPlay];
}


@end
