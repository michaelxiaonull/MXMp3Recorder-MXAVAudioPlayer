//
//  MXMp3Recorder.h
//  1108 - MXMp3Recoder
//
//  Created by Michael on 2017/11/8.
//  Copyright © 2017年 Michael. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, MXRecorderRecordStatus) {
    MXRecorderRecordStatusStart,
    MXRecorderRecordStatusRecording,
    MXRecorderRecordStatusPause,
    MXRecorderRecordStatusEndFromCancel,
    MXRecorderRecordStatusEnd,
    MXRecorderRecordStatusConvertSuccess,
    MXRecorderRecordStatusConvertFail
};

@class MXMp3Recorder;

@protocol MXMp3RecorderDelegate <NSObject>

@optional;
- (void)mp3Recorder:(MXMp3Recorder *)recorder recordStatusDidChange:(MXRecorderRecordStatus)recordStatus;
- (void)mp3RecorderDidFailToRecord:(MXMp3Recorder *)recorder;
- (void)mp3RecorderDidBeginToConvert:(MXMp3Recorder *)recorder;
- (void)mp3Recorder:(MXMp3Recorder *)recorder didFinishingConvertingWithMP3FilePath:(NSString *)filePath;
- (void)mp3Recorder:(MXMp3Recorder *)recorder didUpdateDecibel:(CGFloat)convertedValue;

@end

@interface MXMp3Recorder : NSObject

@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, weak) id<MXMp3RecorderDelegate> delegate;
//@property (readonly) BOOL isRecording; /* is it recording or not? */
//@property (readonly) BOOL isPausing;
@property (readonly) MXRecorderRecordStatus recordStatus;

+ (instancetype)shareInstance;
+ (instancetype)recorderWithCachePath:(NSString *)cachePath delegate:(id<MXMp3RecorderDelegate>)delegate;

/// 开始录制，`shouldUpdateDecibel`是否监听音频的分贝数，会触发回调[_delegate mp3Recorder:self didUpdateDecibel:convertedValue]`;
- (void)startRecordingAndDecibelUpdate:(BOOL)shouldUpdateDecibel;
/// 暂停录制
- (void)pauseRecording;
/// 继续录制
- (void)resumeRecording;
/// 停止录制
- (void)stopRecording;
/// 取消之后，录制的缓存文件会删除
- (void)cancelRecording;

@end
