
/***********************************************************
 //  YFAudioConvert.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import <Foundation/Foundation.h>

@interface YFAudioConvert : NSObject

+ (NSData*) amrDataFromWaveData:(NSData *)data;
+ (NSData*) wavDataFromAmrData:(NSData *)data;

@end
