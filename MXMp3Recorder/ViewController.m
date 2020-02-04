//
//  ViewController.m
//  MXMp3Recorder
//
//  Created by Michael on 2020/2/3.
//  Copyright © 2020 Michael. All rights reserved.
//

#import "ViewController.h"
#import "MXMp3Recorder.h"
#import "MXAVAudioPlayer.h"

@interface ViewController () <MXMp3RecorderDelegate, MXAVAudioPlayerDelegate> {
    NSString *_mp3FilePath;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

// 录制/继续录制音频
- (IBAction)recorder:(UIButton *)sender {
    MXMp3Recorder *recorder = MXMp3Recorder.shareInstance;
    if (recorder.recordStatus == MXRecorderRecordStatusPause) {
        // 继续录制音频
        [recorder resumeRecording];
        return;
    }
    recorder = [MXMp3Recorder recorderWithCachePath:nil delegate:self];
    // 开始录制音频
    [recorder startRecordingAndDecibelUpdate:NO];
}

// 暂停录制
- (IBAction)pauseRecording:(UIButton *)sender {
    [MXMp3Recorder.shareInstance pauseRecording];
}

// 停止录制
- (IBAction)stopRecordering:(UIButton *)sender {
    [MXMp3Recorder.shareInstance stopRecording];
}

// 取消录制
- (IBAction)cancelRecordering:(UIButton *)sender {
    [MXMp3Recorder.shareInstance cancelRecording];
}

// 播放本地音频
- (IBAction)play:(UIButton *)sender {
    if (![NSFileManager.defaultManager fileExistsAtPath:_mp3FilePath]) {
        return;
    }
    MXAVAudioPlayer *player = MXAVAudioPlayer.shareInstance;
    if (player.playStatus == MXAVAudioPlayerPlayStatusPause) {
        // 继续播放音频
        [player resumeAudioPlayer];
        return;
    }
    player = [MXAVAudioPlayer playerWithCachePath:nil delegate:self];
    [player playAudioWithURLString:_mp3FilePath];
}

// 暂停播放音频
- (IBAction)pausePlaying:(UIButton *)sender {
    [MXAVAudioPlayer.shareInstance pauseAudioPlayer];
}

// 停止播放音频
- (IBAction)stopPlaying:(UIButton *)sender {
    [MXAVAudioPlayer.shareInstance stopAudioPlayer];
}

#pragma mark - MXMp3RecorderDelegate
- (void)mp3RecorderDidFailToRecord:(MXMp3Recorder *)recorder {
    NSLog(@"转换失败,录制时间太短了");
}

- (void)mp3RecorderDidBeginToConvert:(MXMp3Recorder *)recorder {
    NSLog(@"转换mp3中...");
}

- (void)mp3Recorder:(MXMp3Recorder *)recorder didFinishingConvertingWithMP3FilePath:(NSString *)filePath {
    NSLog(@"转换完成,路径为%@", filePath);
    _mp3FilePath = filePath;
}

@end
