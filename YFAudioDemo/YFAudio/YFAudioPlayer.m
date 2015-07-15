
/***********************************************************
 //  YFAudioPlayer.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioPlayer.h"
#import "YFAudioConvert.h"

static const float kMISMessageVoiceLengthRefreshInterval = 0.5;

static YFAudioPlayer* instance = nil;

@interface YFAudioPlayer()
@property(nonatomic, weak)id<YFAudioPlayerDelegate>delegate;
@property(nonatomic, strong)AVAudioPlayer* player;
@property(nonatomic, assign)BOOL isPlaying;
@property(nonatomic, strong)NSTimer* refreshLengthTimer;

@end

@implementation YFAudioPlayer

+ (YFAudioPlayer *)sharePlayer
{
	@synchronized(self)
	{
		if (instance == nil)
		{
			instance = [[YFAudioPlayer alloc] init];
			instance.enableLength = YES;
		}
	}
	
	return instance;
}

- (void)startPlayAudioWithPath:(NSString *)filePath delegate:(id<YFAudioPlayerDelegate>)delegate isSpeakerMode:(BOOL)isSpeakerMode
{
	[self stopPlay];
	
	self.delegate = delegate;
	
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	if (isSpeakerMode)
	{
		[audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
	}
	else
	{
		[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
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

#pragma mark =============AVAudioPlayerDelegate====================================

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	[self stopPlay];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
	[self stopPlay];
}


@end
