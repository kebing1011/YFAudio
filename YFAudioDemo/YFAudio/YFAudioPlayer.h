
/***********************************************************
//  YFAudioPlayer.h
//  Mao Kebing
//  Created by mac on 13-7-25.
//  Copyright (c) 2013 Eduapp. All rights reserved.
***********************************************************/

#import <AVFoundation/AVFoundation.h>

@protocol YFAudioPlayerDelegate <NSObject>
@optional

/**
 *  正在播放
 *
 *  @param length 当前播放的秒数
 */
- (void)didPlayingWithLength:(NSInteger)length;

/**
 *  开始播放
 */
- (void)didStartPlay;

/**
 *  已停止或播放完成
 */
- (void)didStopPlay;

@end

/**
 *  播放模式
 */
typedef NS_ENUM(NSInteger, YFAudioPlayerPlayMode) {
	/**
	 *  扬声器
	 */
	YFAudioPlayerPlayModeSpeaker = 0x0,
	/**
	 *  听筒
	 */
	YFAudioPlayerPlayModeEarphone
};

@interface YFAudioPlayer : NSObject<AVAudioPlayerDelegate>
/**
 *  是否启用长度提示 默认:YES
 */
@property(nonatomic, assign)BOOL enableLength;

/**
 *  唯一入口
 *
 *  @return 单例
 */
+ (YFAudioPlayer *)sharePlayer;


/**
 *  使用距离感应来控制听筒还是杨声器播放
 *
 *  @param flag 开关 默认：开
 */
+ (void)setProximityMonitoringEnabled:(BOOL)flag;


/**
 *  设置播放模式
 *
 *  @param mode 扬声器 听筒 默认:扬声器
 */
+ (void)setPlayMode:(YFAudioPlayerPlayMode)mode;

/**
 *  当前播放模式
 *
 *  @return 模式
 */
+ (YFAudioPlayerPlayMode)playMode;

/**
 *  设置资源里面播放完成的音效文件名
 *
 *  @param fileURL 声音URL(本地)
 */
+ (void)setPlayFinishedSoundEffectFileName:(NSString *)fileName;


/**
 *  开始播放
 *
 *  @param filePath      amr音频文件地址(本地URL或网络URL都可以)
 *  @param delegate      当前回调
 */
- (void)startPlayAudioWithPath:(NSString *)filePath
					  delegate:(id<YFAudioPlayerDelegate>)delegate;

/**
 *  停止播放
 */
- (void)stopPlay;

/**
 *  清空回调并取消播放
 */
- (void)clearDeleateAndCancePlay;

/**
 *  是否在指定的delegate播放
 *
 *  @param delegate 回调
 *
 *  @return 是否
 */
- (BOOL)isPlayWithDelegate:(id<YFAudioPlayerDelegate>)delegate;

@end
