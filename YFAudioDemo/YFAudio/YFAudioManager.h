
/***********************************************************
 //  YFAudioManager.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import <Foundation/Foundation.h>

@class YFAudioManager;
@protocol YFAudioManagerDelegate <NSObject>
@optional
- (void)audioManager:(YFAudioManager *)imageManager didFinishWithAudio:(NSData *)audio;
- (void)audioManager:(YFAudioManager *)imageManager didFailWithError:(NSError *)error;

@end

@interface YFAudioManager : NSObject

+ (instancetype)sharedManager;
- (void)downloadWithURL:(NSURL *)url delegate:(id<YFAudioManagerDelegate>)delegate;
- (void)cancelForDelegate:(id<YFAudioManagerDelegate>)delegate;

@end
