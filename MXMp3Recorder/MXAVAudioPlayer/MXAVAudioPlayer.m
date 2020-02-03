//
//  MXAVAudioPlayer.m
//  0919 - MXAVAudioPlayer
//
//  Created by Michael on 2017/9/18.
//  Copyright © 2017年 Michael. All rights reserved.
//

#import "MXAVAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "NSString+YunluMD5.h"
#import <UIKit/UIKit.h>

#ifdef DEBUG
#define MXLog(fmt, ...)    NSLog((@"%s [Line %d]" fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define MXLog(fmt, ...)
#endif

@interface MXAVAudioPlayer () <AVAudioPlayerDelegate> {
    __weak AVAudioSession *_session;
    AVAudioPlayer *_audioPlayer;
    NSString *_audioCacheKey;
}

@property (nonatomic, readwrite) MXAVAudioPlayerPlayStatus playStatus;
@property (nonatomic, strong) NSOperationQueue *audioDataCacheOperationQueue;

@end

@implementation MXAVAudioPlayer

#pragma mark - life cycle
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //[[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    //    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
}

+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    static id shareInstance;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
        [shareInstance configSession];
    });
    return shareInstance;
}

+ (instancetype)playerWithCachePath:(NSString *)cachePath delegate:(id<MXAVAudioPlayerDelegate>)delegate {
    MXAVAudioPlayer *player = [self shareInstance];
    player.cachePath = cachePath;
    player.delegate = delegate;
    return player;
}

#pragma mark - private methods
- (void)configSession {
    if (!_cachePath) {
        _cachePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.default.MXAVAudioPlayer.audioCache"];
    }
    [self configAVAudioSession];
    //监听是否被打断
    [[NSNotificationCenter defaultCenter] addObserver:self
     selector:@selector(handleInterruption:)
     name:AVAudioSessionInterruptionNotification                                           object:nil];
    //添加应用进入后台通知
    UIApplication *app = [UIApplication sharedApplication];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:app];
}

- (void)configAVAudioSession {
    _session = _session ?: [AVAudioSession sharedInstance];
    NSError *sessionError;
    [_session setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
    if(_session == nil) {
        MXLog(@"Error creating session: %@", [sessionError description]);
    } else {
        //[_session setActive:YES error:nil];
        [_session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

- (NSData *)audioDataWithURLString:(NSString *)URLString {
    NSData *audioData;
    //1.检查URLString是本地文件还是网络文件
    if ([URLString hasPrefix:@"http"] || [URLString hasPrefix:@"https"]) {
        //2.来自网络,先检查本地缓存,缓存key是URLString的MD5编码
        NSString *audioCacheKey = URLString.yunlu_MD5String;
        _audioCacheKey = audioCacheKey;
        //3.本地缓存存在->直接读取本地缓存   不存在->从网络获取数据,并且缓存
        NSString *path = [self.cachePath stringByAppendingPathComponent:audioCacheKey];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            audioData = [NSData dataWithContentsOfFile:path];
        } else {
            audioData = [NSData dataWithContentsOfURL:[NSURL URLWithString:URLString]];
            [audioData writeToFile:path atomically:YES];
        }
    } else {
        audioData = [NSData dataWithContentsOfFile:URLString];
    }
    return audioData;
}

- (void)playAudioWithData:(NSData *)audioData {
    [self configAVAudioSession];
    NSError *audioPlayerError;
    _audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:&audioPlayerError];
    if (!_audioPlayer || !audioData) return;
    
    _audioPlayer.volume = 1.0f;
    _audioPlayer.delegate = self;
    [_audioPlayer prepareToPlay];
    [_audioPlayer play];
    self.playStatus = MXAVAudioPlayerPlayStatusPlaying;
}

- (void)pauseAudioPlayer {
    if (_audioPlayer && _audioPlayer.isPlaying) {
        [_audioPlayer pause];
        self.playStatus = MXAVAudioPlayerPlayStatusPause;
    }
}

- (void)resumeAudioPlayer {
    if (_audioPlayer && !_audioPlayer.isPlaying) {
        [_audioPlayer play];
        self.playStatus = MXAVAudioPlayerPlayStatusPlaying;
    }
}

- (void)stopLastPlayerIfNeeded {
    if (_audioPlayer.isPlaying) {
        //说明当前有正在播放, 或者正在加载的视频,取消 operation(如果没有在执行任务),停止播放
        [self cancelOperation];
        [self stopAudioPlayer];
    }
}

- (void)stopAudioPlayer {
    if (_audioPlayer) {
        _audioPlayer.playing ? [_audioPlayer stop] : nil;
        // 意外停止，`playStatus`为`MXAVAudioPlayerPlayStatusEndFromCancel`
        self.playStatus = MXAVAudioPlayerPlayStatusEndFromCancel;
        _audioPlayer.delegate = nil;
        _audioPlayer = nil;
    }
}

- (void)cancelOperation {
    for (NSOperation *operation in self.audioDataCacheOperationQueue.operations) {
        if(!_audioCacheKey) continue;
        if ([operation.name isEqualToString:[NSString stringWithFormat:@"%@", _audioCacheKey]]) {
            [operation cancel];
            break;
        }
    }
}

- (void)cleanAudioCache {
    NSArray *files = [[NSFileManager defaultManager] subpathsAtPath:self.cachePath];
    for (NSString *file in files) {
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    }
}

#pragma mark - public methods
- (void)playAudioWithURLString:(NSString *)URLString {
    if (!URLString) return;
    //invoke -MXAVAudioPlayerWillStartPlaying: callback
    if (_delegate && [_delegate respondsToSelector:@selector(MXAVAudioPlayerWillStartPlaying:)]) {
        [_delegate MXAVAudioPlayerWillStartPlaying:self];
    }
    [self stopLastPlayerIfNeeded];
    self.playStatus = MXAVAudioPlayerPlayStatusStart;
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSData *audioData = [self audioDataWithURLString:URLString];
        if (!audioData) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            //invoke -MXAVAudioPlayerDidFinishDownloading: callback
            if (_delegate && [_delegate respondsToSelector:@selector(MXAVAudioPlayerDidFinishDownloading:)]) {
                [_delegate MXAVAudioPlayerDidFinishDownloading:self];
            }
            [self playAudioWithData:audioData];
        });
    }];
    [blockOperation setName:[NSString stringWithFormat:@"%@", URLString.yunlu_MD5String]];
    [self.audioDataCacheOperationQueue addOperation:blockOperation];
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    //    //删除近距离事件监听
    //    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    //    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
    //延迟一秒将audioPlayer 释放
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .2f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self stopAudioPlayer];
        // 正常播放完毕，非意外停止
        self.playStatus = MXAVAudioPlayerPlayStatusEnd;
        //invoke -MXAVAudioPlayerDidFinishDownloading: callback
        if (_delegate && [_delegate respondsToSelector:@selector(MXAVAudioPlayerDidFinishPlaying:)]) {
            [_delegate MXAVAudioPlayerDidFinishPlaying:self];
        }
    });
}

#pragma mark - NSNotificationCenter Methods
- (void)applicationWillResignActive:(UIApplication *)application {
    [self cancelOperation];
}

- (void)proximityStateChanged:(NSNotification *)notification {
    //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗，以达到省电的目的。
    if ([[UIDevice currentDevice] proximityState] == YES) {
        MXLog(@"Device is close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    } else {
        MXLog(@"Device is not close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

#pragma mark - setter methods
- (void)setPlayStatus:(MXAVAudioPlayerPlayStatus)playStatus {
    if (_playStatus == playStatus) return;
    _playStatus = playStatus;
    if ([self.delegate respondsToSelector:@selector(audioPlayer:playStatusDidChange:)]) {
        [self.delegate audioPlayer:self playStatusDidChange:playStatus];
    }
}

- (void)setCachePath:(NSString *)cachePath {
    if ([_cachePath isEqualToString:cachePath]) return;
    _cachePath = cachePath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark - getter methods
- (NSOperationQueue *)audioDataCacheOperationQueue {
    if (_audioDataCacheOperationQueue == nil) {
        NSOperationQueue *audioDataCacheOperationQueue  = [[NSOperationQueue alloc] init];
        audioDataCacheOperationQueue.name = @"com.yunlu6.MXAVAudipPlayer.audioDataCacheOperationQueue";
        _audioDataCacheOperationQueue = audioDataCacheOperationQueue;
    }
    return _audioDataCacheOperationQueue;
}

#pragma mark - notifications
- (void)handleInterruption:(NSNotification *)notificaton {
    MXLog(@"notificaton: %@", notificaton);
}

@end
