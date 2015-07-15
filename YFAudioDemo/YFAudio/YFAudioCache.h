
/***********************************************************
 //  YFAudioCache.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import <Foundation/Foundation.h>

@class YFAudioCache;
@protocol YFAudioCacheDelegate<NSObject>
@optional
- (void)audioCache:(YFAudioCache *)audioCache didFindAudio:(NSData *)data forKey:(NSString *)key userInfo:(NSDictionary *)info;
- (void)audioCache:(YFAudioCache *)audioCache didNotFindAudioForKey:(NSString *)key userInfo:(NSDictionary *)info;
@end


@interface YFAudioCache : NSObject
{
    NSMutableDictionary *memCache;
    NSString *diskCachePath;
    NSOperationQueue *cacheInQueue, *cacheOutQueue;
}

+ (YFAudioCache *)sharedAudioCache;
- (void)storeAudio:(NSData *)audio forKey:(NSString *)key;
- (void)storeAudio:(NSData *)data forKey:(NSString *)key toDisk:(BOOL)toDisk;
- (NSData *)audioFromKey:(NSString *)key;
- (NSData *)audioFromKey:(NSString *)key fromDisk:(BOOL)fromDisk;
- (void)queryDiskCacheForKey:(NSString *)key delegate:(id <YFAudioCacheDelegate>)delegate userInfo:(NSDictionary *)info;
- (void)removeAudioForKey:(NSString *)key;
- (void)removeAudioForKey:(NSString *)key fromDisk:(BOOL)fromDisk;
- (void)clearMemory;

@end
