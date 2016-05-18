#YFAudio
轻量级的语音录制下载播放工具。

###功能模块

* 录音模块.
* 编解码模块 将录音编码成``amr``格式，可以与 android 平台统一使用.
* 下载模块.
* 缓存模块，会缓存到内存和本地.
* 播放模块，传入文件URL 或 HTTP URL 进行播放.

###调用方式

* 录音

```
遵守
<YFAudioRecorderDelegate>

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


//开始录音
[YFAudioRecorder shareRecorder].delegate = self;
[[YFAudioRecorder shareRecorder] startRecord];	

//结束录音
[[YFAudioRecorder shareRecorder] stopRecord];

```

* 播放

```
遵守 <YFAudioPlayerDelegate>

/**
 *  正在播放
 *
 *  @param length 当前播放的秒数
 */
- (void)didPlayingWithLength:(NSInteger)length;

/**
 *  开始播放
 */
- (void)didStartPlay;

/**
 *  已停止或播放完成
 */
- (void)didStopPlay;


//开始播放
@param filePath //文件地址 或 URLString 
[[YFAudioPlayer sharePlayer] startPlayAudioWithPath:filePath delegate:self];

```

* 可以操作管理者 ```YFAudioManager```

```
- (void)downloadWithURL:(NSURL *)url delegate:(id<YFAudioManagerDelegate>)delegate;
- (void)cancelForDelegate:(id<YFAudioManagerDelegate>)delegate;
```