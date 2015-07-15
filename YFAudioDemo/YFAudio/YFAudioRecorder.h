
/***********************************************************
 //  YFAudioRecorder.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, RecorderError) {
	RecorderErrorNone     = 0,
	RecorderErrorStart    = 1,
	RecorderErrorFinish   = 2,
	RecorderErrorEncode   = 3,
	RecorderErrorTooShort = 4,
	RecorderErrorTooLong  = 5
};

typedef NS_ENUM(NSInteger, YFRecordPermission) {
	YFRecordPermissionNone         = 0,
	YFRecordPermissionUndetermined = 1,
	YFRecordPermissionDenied       = 2,
	YFRecordPermissionGranted      = 3
};

@protocol YFAudioRecorderDelegate <NSObject>
@optional
- (void)didStartRecord;
- (void)didRecordFailedWithError:(RecorderError )error;
- (void)didRecordingWithMeters:(float )meters;
- (void)didRecordingWithLength:(NSInteger )length;
- (void)didRecordFinishedWithFilePath:(NSString *)filePath length:(NSInteger )length;
- (void)didCancelRecord;
@end

@interface YFAudioRecorder : NSObject<AVAudioRecorderDelegate>
@property(nonatomic, weak)id<YFAudioRecorderDelegate> delegate;
@property(nonatomic, assign)BOOL enableMeters;
@property(nonatomic, assign)BOOL enableLength;
@property(nonatomic, assign)BOOL isSpeakerMode;
@property(nonatomic, assign)YFRecordPermission recordPermission;

+ (YFAudioRecorder *)shareRecorder;
+ (void)setMaxVoiceLength:(NSInteger)length;
+ (NSInteger )maxVoiceLength;
+ (void)setMinVoiceLength:(NSInteger)length;
+ (NSInteger )minVoiceLength;

- (void)startRecord;
- (void)stopRecord;
- (void)clearDeleateAndCanceRecorder;
- (void)cancelRecord;

- (void)checkRecordAvailableBlock:(void(^)(BOOL available))block;


@end
