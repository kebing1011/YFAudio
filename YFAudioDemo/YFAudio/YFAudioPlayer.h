
/***********************************************************
//  YFAudioPlayer.h
//  Mao Kebing
//  Created by mac on 13-7-25.
//  Copyright (c) 2013 Eduapp. All rights reserved.
***********************************************************/

#import <AVFoundation/AVFoundation.h>

@protocol YFAudioPlayerDelegate <NSObject>
@optional
- (void)didPlayingWithLength:(NSInteger)length;
- (void)didStartPlay;
- (void)didStopPlay;
@end

@interface YFAudioPlayer : NSObject<AVAudioPlayerDelegate>
@property(nonatomic, assign)BOOL enableLength;

+ (YFAudioPlayer *)sharePlayer;
- (void)startPlayAudioWithPath:(NSString *)filePath
					  delegate:(id<YFAudioPlayerDelegate>)delegate
				 isSpeakerMode:(BOOL)isSpeakerMode;
- (void)stopPlay;
- (void)clearDeleateAndCancePlay;
- (BOOL)isPlayWithDelegate:(id<YFAudioPlayerDelegate>)delegate;
@end
