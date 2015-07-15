
/***********************************************************
 //  YFAudioCache.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioCache.h"
#import <CommonCrypto/CommonDigest.h>
#import <mach/mach.h>
#import <UIKit/UIKit.h>

static YFAudioCache *instance = nil;

@implementation YFAudioCache

#pragma mark NSObject

- (instancetype)init
{
    if ((self = [super init]))
    {
        // Init the memory cache
        memCache = [[NSMutableDictionary alloc] init];
		
        // Init the disk cache
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        diskCachePath = [paths[0] stringByAppendingPathComponent:@"Cache"];
		
        if (![[NSFileManager defaultManager] fileExistsAtPath:diskCachePath])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:NULL];
        }
		
        // Init the operation queue
        cacheInQueue = [[NSOperationQueue alloc] init];
        cacheInQueue.maxConcurrentOperationCount = 1;
        cacheOutQueue = [[NSOperationQueue alloc] init];
        cacheOutQueue.maxConcurrentOperationCount = 1;
		
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
	}
	
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (YFAudioCache *)sharedAudioCache
{
    if (instance == nil)
    {
        instance = [[YFAudioCache alloc] init];
    }
	
    return instance;
}

- (NSString *)cachePathForKey:(NSString *)key
{
	NSString *filename = key;
	NSRange range = [filename rangeOfString:@"/"];
	
	while (range.length > 0)
	{
		filename = [filename substringFromIndex:range.location + 1];
		range = [filename rangeOfString:@"/"];
	}
	
    return [diskCachePath stringByAppendingPathComponent:filename];
}

- (void)storeKeyWithDataToDisk:(NSArray *)keyAndData
{
    // Can't use defaultManager another thread
    NSFileManager *fileManager = [[NSFileManager alloc] init];
	
    NSString *key = keyAndData[0];
    NSData *data = [keyAndData count] > 1 ? keyAndData[1] : nil;
	
    if (data)
    {
        [fileManager createFileAtPath:[self cachePathForKey:key] contents:data attributes:nil];
    }
}

- (void)notifyDelegate:(NSDictionary *)arguments
{
    NSString *key = arguments[@"key"];
    id <YFAudioCacheDelegate> delegate = arguments[@"delegate"];
    NSDictionary *info = arguments[@"userInfo"];
    NSData *data = arguments[@"data"];
	
    if (data)
    {
        memCache[key] = data;
		
        if ([delegate respondsToSelector:@selector(audioCache:didFindAudio:forKey:userInfo:)])
        {
            [delegate audioCache:self didFindAudio:data forKey:key userInfo:info];
        }
    }
    else
    {
        if ([delegate respondsToSelector:@selector(audioCache:didNotFindAudioForKey:userInfo:)])
        {
            [delegate audioCache:self didNotFindAudioForKey:key userInfo:info];
        }
    }
}

- (void)queryDiskCacheOperation:(NSDictionary *)arguments
{
    NSString *key = arguments[@"key"];
    NSMutableDictionary *mutableArguments = [arguments mutableCopy];
	
    NSData* data = [NSData dataWithContentsOfFile:[self cachePathForKey:key]];
	if (data)
	{
		mutableArguments[@"data"] = data;
	}
	
    [self performSelectorOnMainThread:@selector(notifyDelegate:) withObject:mutableArguments waitUntilDone:NO];
}

#pragma mark ImageCache

- (void)storeAudio:(NSData *)data forKey:(NSString *)key toDisk:(BOOL)toDisk
{
    if (!key)
    {
        return;
    }
    
    memCache[key] = data;
	
    if (toDisk)
    {
        NSArray *keyWithData;
        if (data)
        {
            keyWithData = @[key, data];
        }
        else
        {
            keyWithData = @[key];
        }
		
        NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
																				selector:@selector(storeKeyWithDataToDisk:)
																				  object:keyWithData];
        [cacheInQueue addOperation:operation];
    }
}

- (void)storeAudio:(NSData *)audio forKey:(NSString *)key
{
    [self storeAudio:audio forKey:key toDisk:YES];
}


- (NSData *)audioFromKey:(NSString *)key
{
    return [self audioFromKey:key fromDisk:YES];
}

- (NSData *)audioFromKey:(NSString *)key fromDisk:(BOOL)fromDisk
{
    if (key == nil)
    {
        return nil;
    }
	
    NSData* data = memCache[key];
	
    if (!data && fromDisk)
    {
        data = [NSData dataWithContentsOfFile:[self cachePathForKey:key]];
        if (data)
        {
            memCache[key] = data;
        }
    }
	
    return data;
}

- (void)queryDiskCacheForKey:(NSString *)key delegate:(id <YFAudioCacheDelegate>)delegate userInfo:(NSDictionary *)info
{
    if (!delegate)
    {
        return;
    }
	
    if (!key)
    {
        if ([delegate respondsToSelector:@selector(audioCache:didNotFindAudioForKey:userInfo:)])
        {
            [delegate audioCache:self didNotFindAudioForKey:key userInfo:info];
        }
        return;
    }
	
    // First check the in-memory cache...
    NSData *data = memCache[key];
    if (data)
    {
        // ...notify delegate immediately, no need to go async
        if ([delegate respondsToSelector:@selector(audioCache:didFindAudio:forKey:userInfo:)])
        {
            [delegate audioCache:self didFindAudio:data forKey:key userInfo:info];
        }
        return;
    }
	
    NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithCapacity:3];
    arguments[@"key"] = key;
    arguments[@"delegate"] = delegate;
    if (info)
    {
        arguments[@"userInfo"] = info;
    }
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
																			selector:@selector(queryDiskCacheOperation:)
																			  object:arguments];
    [cacheOutQueue addOperation:operation];
}

- (void)removeAudioForKey:(NSString *)key
{
    [self removeAudioForKey:key fromDisk:YES];
}

- (void)removeAudioForKey:(NSString *)key fromDisk:(BOOL)fromDisk
{
    if (key == nil)
    {
        return;
    }
	
    [memCache removeObjectForKey:key];
	
    if (fromDisk)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[self cachePathForKey:key] error:nil];
    }
}

- (void)clearMemory
{
    [cacheInQueue cancelAllOperations]; // won't be able to complete
    [memCache removeAllObjects];
}



@end
