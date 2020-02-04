# MXMp3Recorder
A tool can record  mp3 file on iOS


## Screenshot

![DEMO录制界面](https://upload-images.jianshu.io/upload_images/2546918-1cf9983f8cf55b73.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/540)

## How to use

### 录制/继续录制音频 
``` objective-c
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
```

### 暂停录制
``` objective-c
// 暂停录制
- (IBAction)pauseRecording:(UIButton *)sender {
    [MXMp3Recorder.shareInstance pauseRecording];
}
```

### 停止录制
``` objective-c
// 停止录制
- (IBAction)stopRecordering:(UIButton *)sender {
    [MXMp3Recorder.shareInstance stopRecording];
}
```

### 取消录制
``` objective-c
// 取消录制
- (IBAction)cancelRecordering:(UIButton *)sender {
    [MXMp3Recorder.shareInstance cancelRecording];
}
```

# MXAVAudioPlayer
A tool can play mp3 file on iOS

## How to use

### 播放本地音频
``` objective-c
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
```

### 暂停播放音频
``` objective-c
// 暂停播放音频
- (IBAction)pausePlaying:(UIButton *)sender {
    [MXAVAudioPlayer.shareInstance pauseAudioPlayer];
}
```

### 停止播放音频
``` objective-c
// 停止播放音频
- (IBAction)stopPlaying:(UIButton *)sender {
    [MXAVAudioPlayer.shareInstance stopAudioPlayer];
}
```




