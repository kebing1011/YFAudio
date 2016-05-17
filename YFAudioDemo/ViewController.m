//
//  ViewController.m
//  YFAudioDemo
//
//  Created by mao on 1/3/15.
//  Copyright (c) 2015 mao. All rights reserved.
//

#import "ViewController.h"
#import "YFAudioPlayer.h"
#import "YFAudioRecorder.h"


@interface ViewController ()<YFAudioPlayerDelegate, YFAudioRecorderDelegate>
@property(nonatomic, copy)NSString* filePath;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	
	[YFAudioRecorder setMaxVoiceLength:60];
	[YFAudioRecorder setMinVoiceLength:1];

	
	
	self.title = @"YFAudio";
	
	self.view.backgroundColor = [UIColor whiteColor];
	
	
	
	UIButton* bt1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	bt1.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - 100) / 2.0, 150, 100, 50);
	[self.view addSubview:bt1];
	[bt1 addTarget:self action:@selector(startRecord) forControlEvents:UIControlEventTouchDown];
	[bt1 addTarget:self action:@selector(stopRecord) forControlEvents:UIControlEventTouchUpInside];
	[bt1 setTitle:@"按下开始录音" forState:UIControlStateNormal];
	[bt1 setTitle:@"松开完成录音" forState:UIControlStateHighlighted];
	
	
	UIButton* bt2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	bt2.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - 100) / 2.0, 250, 100, 50);
	[self.view addSubview:bt2];
	[bt2 addTarget:self action:@selector(startPlay:) forControlEvents:UIControlEventTouchDown];
	[bt2 setTitle:@"开始播放" forState:UIControlStateNormal];
	[bt2 setTitle:@"停止播放" forState:UIControlStateSelected];
}

- (void)startRecord
{
	[YFAudioRecorder shareRecorder].delegate = self;
	[[YFAudioRecorder shareRecorder] startRecord];
}

- (void)stopRecord
{
	[[YFAudioRecorder shareRecorder] stopRecord];
}

- (void)startPlay:(UIButton *)bt
{
	if (!bt.selected && [[NSFileManager defaultManager] fileExistsAtPath:self.filePath])
	{
		[[YFAudioPlayer sharePlayer] startPlayAudioWithPath:self.filePath delegate:self];
	}
	else
	{
		[[YFAudioPlayer sharePlayer] stopPlay];
	}
	
	bt.selected = !bt.selected;
}




#pragma mark ===
- (void)didStartRecord
{
	NSLog(@"%s", __func__);
}
- (void)didRecordFailedWithError:(YFRecorderError )error
{
	
}
- (void)didRecordingWithMeters:(float )meters
{
	NSLog(@"%s, meters:%@", __func__,  @(meters));
}
- (void)didRecordingWithLength:(NSTimeInterval )length
{
	NSLog(@"%s, length:%@", __func__,  @(length));
}
- (void)didRecordFinishedWithFilePath:(NSString *)filePath length:(NSInteger )length
{
	self.filePath = filePath;
	
	NSLog(@"%s, file:%@, length:%@", __func__, filePath, @(length));
}
- (void)didCancelRecord
{
	NSLog(@"%s", __func__);
}

#pragma mark ====

- (void)didPlayingWithLength:(NSInteger)length
{
	NSLog(@"%s, length:%@", __func__,  @(length));
}
- (void)didStartPlay
{
	NSLog(@"%s", __func__);

}
- (void)didStopPlay
{
	NSLog(@"%s", __func__);

}

@end
