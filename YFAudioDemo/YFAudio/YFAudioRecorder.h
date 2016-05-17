
/***********************************************************
 //  YFAudioRecorder.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

/**
 *  录音错误
 */
typedef NS_ENUM(NSInteger, YFRecorderError) {
	/**
	 *  正常
	 */
	YFRecorderErrorNone     = 0,
	/**
	 *  录音开始错误
	 */
	YFRecorderErrorStart    = 1,
	/**
	 *  录音完成错误
	 */
	YFRecorderErrorFinish   = 2,
	/**
	 *  录音转码错误
	 */
	YFRecorderErrorEncode   = 3,
	/**
	 *  录音太短
	 */
	YFRecorderErrorTooShort = 4,
	/**
	 *  录音太长
	 */
	YFRecorderErrorTooLong  = 5
};

/**
 *  用户授权状态
 */
typedef NS_ENUM(NSInteger, YFRecordPermission) {
	/**
	 *  未授权（iOS 7.0）
	 */
	YFRecordPermissionNone         = 0,
	/**
	 *  未授权（iOS 8.0+）
	 */
	YFRecordPermissionUndetermined = 1,
	/**
	 *  用户已拒绝
	 */
	YFRecordPermissionDenied       = 2,
	/**
	 *  用户已允许
	 */
	YFRecordPermissionGranted      = 3
};


@protocol YFAudioRecorderDelegate <NSObject>
@optional

/**
 *  开始录音
 */
- (void)didStartRecord;

/**
 *  录音出错
 *
 *  @param error 见错误码-RecorderError
 */
- (void)didRecordFailedWithError:(YFRecorderError)error;

/**
 *  正在录音
 *
 *  @param meters 声音指示
 */
- (void)didRecordingWithMeters:(float)meters;

/**
 *  正在录音
 *
 *  @param length 当前录单长度 单位：秒
 */
- (void)didRecordingWithLength:(NSTimeInterval)length;

/**
 *  录音完成
 *
 *  @param filePath 已保存的文件目录
 *  @param length   录音长度
 */
- (void)didRecordFinishedWithFilePath:(NSString *)filePath length:(NSInteger )length;

/**
 *  录音取消
 */
- (void)didCancelRecord;

@end

@interface YFAudioRecorder : NSObject<AVAudioRecorderDelegate>

/**
 *  录音代理
 */
@property (nonatomic, weak) id<YFAudioRecorderDelegate> delegate;

/**
 *  当前授权状态
 */
@property (nonatomic, readonly) YFRecordPermission recordPermission;

/**
 *  唯一入口
 *
 *  @return 单例
 */
+ (YFAudioRecorder *)shareRecorder;

/**
 *  设置录音最大长度。默认60s
 *
 *  @param length 最大录音长度
 */
+ (void)setMaxVoiceLength:(NSInteger)length;

/**
 *  获取当前最小长度
 *
 *  @return 设定的最小录音长度
 */
+ (NSInteger )maxVoiceLength;

/**
 *  设置录音最小长度。默认1s
 *
 *  @param length 录音长度
 */
+ (void)setMinVoiceLength:(NSInteger)length;

/**
 *  获取录音最小长度。默认1s
 *
 *  @param length 录音长度
 */
+ (NSInteger )minVoiceLength;

/**
 *  开始录录
 */
- (void)startRecord;

/**
 *  结束录音-录音完成
 */
- (void)stopRecord;

/**
 *  清空delegate
 */
- (void)clearDeleateAndCanceRecorder;

/**
 *  取消录音
 */
- (void)cancelRecord;

/**
 *  授权检查
 *
 *  @param block 等侍用户处理回调
 */
- (void)checkRecordAvailableBlock:(void(^)(BOOL available))block;


@end
