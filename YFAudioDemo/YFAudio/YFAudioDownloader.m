
/***********************************************************
 //  YFAudioDownloader.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioDownloader.h"

@interface YFAudioDownloader ()
@property (nonatomic, retain) NSURLConnection *connection;
@end

@implementation YFAudioDownloader
@synthesize url, delegate, connection, audioData, userInfo, lowPriority;

#pragma mark Public Methods

+ (id)downloaderWithURL:(NSURL *)url delegate:(id<YFAudioDownloaderDelegate>)delegate
{
    return [self downloaderWithURL:url delegate:delegate userInfo:nil];
}

+ (id)downloaderWithURL:(NSURL *)url delegate:(id<YFAudioDownloaderDelegate>)delegate userInfo:(id)userInfo
{
    YFAudioDownloader *downloader = [[YFAudioDownloader alloc] init];
    downloader.url = url;
    downloader.delegate = delegate;
    downloader.userInfo = userInfo;
    [downloader performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
    return downloader;
}

- (void)start
{
    // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	
    if (!lowPriority)
    {
        [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
	
    [connection start];
	
    if (!connection)
    {
		if ([delegate respondsToSelector:@selector(audioDownloader:didFailWithError:)])
        {
            [delegate performSelector:@selector(audioDownloader:didFailWithError:) withObject:self withObject:nil];
        }
    }
}

- (void)cancel
{
    if (connection)
    {
        [connection cancel];
        self.connection = nil;
    }
}

#pragma mark NSURLConnection (delegate)

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response
{
    if (![response respondsToSelector:@selector(statusCode)] || [((NSHTTPURLResponse *)response) statusCode] < 400)
    {
        NSUInteger expectedSize = response.expectedContentLength > 0 ? (NSUInteger)response.expectedContentLength : 0;
        self.audioData = [[NSMutableData alloc] initWithCapacity:expectedSize];
    }
    else
    {
        [aConnection cancel];
		
        if ([delegate respondsToSelector:@selector(audioDownloader:didFailWithError:)])
        {
            NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain
                                                        code:[((NSHTTPURLResponse *)response) statusCode]
                                                    userInfo:nil];
            [delegate performSelector:@selector(audioDownloader:didFailWithError:) withObject:self withObject:error];
        }
		
        self.connection = nil;
        self.audioData = nil;
    }
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
    [audioData appendData:data];
}

#pragma GCC diagnostic ignored "-Wundeclared-selector"
- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
    self.connection = nil;
	
    if ([delegate respondsToSelector:@selector(audioDownloaderDidFinish:)])
    {
        [delegate performSelector:@selector(audioDownloaderDidFinish:) withObject:self];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([delegate respondsToSelector:@selector(imageDownloader:didFailWithError:)])
    {
        [delegate performSelector:@selector(imageDownloader:didFailWithError:) withObject:self withObject:error];
    }
	
    self.connection = nil;
    self.audioData = nil;
}


@end
