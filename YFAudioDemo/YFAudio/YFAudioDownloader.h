
/***********************************************************
 //  YFAudioDownloader.h
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import <Foundation/Foundation.h>

@class YFAudioDownloader;
@protocol  YFAudioDownloaderDelegate<NSObject>
@optional
- (void)audioDownloaderDidFinish:(YFAudioDownloader *)downloader;
- (void)audioDownloader:(YFAudioDownloader *)downloader didFailWithError:(NSError *)error;
@end


@interface YFAudioDownloader : NSObject
{
@private
    NSURL *url;
	__weak id<YFAudioDownloaderDelegate> delegate;
    NSURLConnection *connection;
    NSMutableData *audioData;
    id userInfo;
}

@property (nonatomic, retain) NSURL *url;
@property (nonatomic, weak) id<YFAudioDownloaderDelegate> delegate;
@property (nonatomic, retain) NSMutableData *audioData;
@property (nonatomic, retain) id userInfo;
@property (nonatomic, readwrite) BOOL lowPriority;

+ (id)downloaderWithURL:(NSURL *)url delegate:(id<YFAudioDownloaderDelegate>)delegate userInfo:(id)userInfo;
+ (id)downloaderWithURL:(NSURL *)url delegate:(id<YFAudioDownloaderDelegate>)delegate;

- (void)start;
- (void)cancel;

@end
