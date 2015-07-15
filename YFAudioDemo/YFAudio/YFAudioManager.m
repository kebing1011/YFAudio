
/***********************************************************
 //  YFAudioManager.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioManager.h"
#import "YFAudioCache.h"
#import "YFAudioDownloader.h"

static YFAudioManager *instance;

@interface YFAudioManager()<YFAudioCacheDelegate, YFAudioDownloaderDelegate>
{
	NSMutableArray *downloadInfo;
	NSMutableArray *downloadDelegates;
	NSMutableArray *downloaders;
	NSMutableArray *cacheDelegates;
	NSMutableArray *cacheURLs;
	NSMutableDictionary *downloaderForURL;
}
@end

@implementation YFAudioManager

- (instancetype)init
{
    if ((self = [super init]))
    {
        downloadDelegates = [[NSMutableArray alloc] init];
        downloaders = [[NSMutableArray alloc] init];
        cacheDelegates = [[NSMutableArray alloc] init];
        cacheURLs = [[NSMutableArray alloc] init];
        downloaderForURL = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+ (instancetype)sharedManager
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[YFAudioManager alloc] init];
	});
	
	return instance;
}

- (NSString *)cacheKeyForURL:(NSURL *)url
{
    return [url absoluteString];
}


- (void)downloadWithURL:(NSURL *)url delegate:(id<YFAudioManagerDelegate>)delegate
{
	if ([url isKindOfClass:NSString.class])
    {
        url = [NSURL URLWithString:(NSString *)url];
    }
	
    if (!url || !delegate)
    {
        return;
    }
	
    // Check the on-disk cache async so we don't block the main thread
    [cacheDelegates addObject:delegate];
    [cacheURLs addObject:url];
    NSDictionary *info = @{@"delegate": delegate,
                          @"url": url};
    [[YFAudioCache sharedAudioCache] queryDiskCacheForKey:[self cacheKeyForURL:url] delegate:self userInfo:info];
}

- (void)cancelForDelegate:(id<YFAudioManagerDelegate>)delegate
{
	NSUInteger idx;
    while ((idx = [cacheDelegates indexOfObjectIdenticalTo:delegate]) != NSNotFound)
    {
        [cacheDelegates removeObjectAtIndex:idx];
        [cacheURLs removeObjectAtIndex:idx];
    }
	
    while ((idx = [downloadDelegates indexOfObjectIdenticalTo:delegate]) != NSNotFound)
    {
        YFAudioDownloader *downloader = downloaders[idx];
		
        [downloadInfo removeObjectAtIndex:idx];
        [downloadDelegates removeObjectAtIndex:idx];
        [downloaders removeObjectAtIndex:idx];
		
        if (![downloaders containsObject:downloader])
        {
            // No more delegate are waiting for this download, cancel it
            [downloader cancel];
            [downloaderForURL removeObjectForKey:downloader.url];
        }
    }
}

#pragma mark ======
- (void)audioDownloaderDidFinish:(YFAudioDownloader *)downloader
{
    // Notify all the downloadDelegates with this downloader
    for (NSInteger idx = (NSInteger)[downloaders count] - 1; idx >= 0; idx--)
    {
        NSUInteger uidx = (NSUInteger)idx;
        YFAudioDownloader *aDownloader = downloaders[uidx];
        if (aDownloader == downloader)
        {
            id<YFAudioManagerDelegate> delegate = downloadDelegates[uidx];
            if (downloader.audioData)
            {
                if ([delegate respondsToSelector:@selector(audioManager:didFinishWithAudio:)])
                {
                    [delegate audioManager:self didFinishWithAudio:downloader.audioData];
                }
			}
            else
            {
                if ([delegate respondsToSelector:@selector(audioManager:didFailWithError:)])
                {
                    [delegate performSelector:@selector(audioManager:didFailWithError:) withObject:self withObject:nil];
                }
			}
			
            [downloaders removeObjectAtIndex:uidx];
            [downloadDelegates removeObjectAtIndex:uidx];
        }
    }
    
    if (downloader.audioData)
    {
        // Store the image in the cache
        [[YFAudioCache sharedAudioCache] storeAudio:downloader.audioData forKey:[self cacheKeyForURL:downloader.url] toDisk:YES];
    }
	
    // Release the downloader
    [downloaderForURL removeObjectForKey:downloader.url];
}

- (void)audioDownloader:(YFAudioDownloader *)downloader didFailWithError:(NSError *)error
{
    // Notify all the downloadDelegates with this downloader
    for (NSInteger idx = (NSInteger)[downloaders count] - 1; idx >= 0; idx--)
    {
        NSUInteger uidx = (NSUInteger)idx;
        YFAudioDownloader *aDownloader = downloaders[uidx];
        if (aDownloader == downloader)
        {
            id<YFAudioDownloaderDelegate> delegate = downloadDelegates[uidx];
			
            if ([delegate respondsToSelector:@selector(audioManager:didFailWithError:)])
            {
                [delegate performSelector:@selector(audioManager:didFailWithError:) withObject:self withObject:error];
            }
       
			
            [downloaders removeObjectAtIndex:uidx];
            [downloadDelegates removeObjectAtIndex:uidx];
        }
    }
	
    [downloaderForURL removeObjectForKey:downloader.url];
}

- (NSUInteger)indexOfDelegate:(id<YFAudioManagerDelegate>)delegate waitingForURL:(NSURL *)url
{
    // Do a linear search, simple (even if inefficient)
    NSUInteger idx;
    for (idx = 0; idx < [cacheDelegates count]; idx++)
    {
        if (cacheDelegates[idx] == delegate && [cacheURLs[idx] isEqual:url])
        {
            return idx;
        }
    }
    return NSNotFound;
}


#pragma mark =========
- (void)audioCache:(YFAudioCache *)audioCache didFindAudio:(NSData *)data forKey:(NSString *)key userInfo:(NSDictionary *)info
{
	NSURL *url = info[@"url"];
    id<YFAudioManagerDelegate> delegate = info[@"delegate"];
	
    NSUInteger idx = [self indexOfDelegate:delegate waitingForURL:url];
    if (idx == NSNotFound)
    {
        // Request has since been canceled
        return;
    }
	
	
    if ([delegate respondsToSelector:@selector(audioManager:didFinishWithAudio:)])
    {
        [delegate audioManager:self didFinishWithAudio:data];
    }
	
	[cacheDelegates removeObjectAtIndex:idx];
    [cacheURLs removeObjectAtIndex:idx];
}

- (void)audioCache:(YFAudioCache *)audioCache didNotFindAudioForKey:(NSString *)key userInfo:(NSDictionary *)info
{
	NSURL *url = info[@"url"];
    id<YFAudioManagerDelegate> delegate = info[@"delegate"];
	
    NSUInteger idx = [self indexOfDelegate:delegate waitingForURL:url];
    if (idx == NSNotFound)
    {
        // Request has since been canceled
        return;
    }
	
    [cacheDelegates removeObjectAtIndex:idx];
    [cacheURLs removeObjectAtIndex:idx];
	
    // Share the same downloader for identical URLs so we don't download the same URL several times
    YFAudioDownloader *downloader = downloaderForURL[url];
	
    if (!downloader)
    {
        downloader = [YFAudioDownloader downloaderWithURL:url delegate:self userInfo:info];
        downloaderForURL[url] = downloader;
    }

    [downloadInfo addObject:info];
    [downloadDelegates addObject:delegate];
    [downloaders addObject:downloader];
}






@end
