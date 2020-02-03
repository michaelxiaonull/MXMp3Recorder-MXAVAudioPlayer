//
//  MXMp3Recorder.m
//  1108 - MXMp3Recoder
//
//  Created by Michael on 2017/11/8.
//  Copyright © 2017年 Michael. All rights reserved.
//

#import "MXMp3Recorder.h"
#if __has_include(<lame/lame.h>)
#import <lame/lame.h>
#else
#import "lame.h"
#endif
#import <AVFoundation/AVFoundation.h>

#ifdef DEBUG
#define MXLog(fmt, ...)    NSLog((@"%s [Line %d]" fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define MXLog(fmt, ...)
#endif

//use macro to replace redundent new `@available` if-else statements
#define AVAILABLE_WHEN_IOS_VERSION(SYSTEM_VERSION_FLOAT_VALUE, SYSTEM_VERSION_GT_SHOULD_GO, SYSTEM_VERSION_LT_SHOULD_GO)\
if (@available(iOS SYSTEM_VERSION_FLOAT_VALUE, *)) {\
SYSTEM_VERSION_GT_SHOULD_GO;\
} else {\
SYSTEM_VERSION_LT_SHOULD_GO;\
}

@interface MXMp3Recorder() <AVAudioRecorderDelegate> {
    
    __weak AVAudioSession *_session;
    AVAudioRecorder *_recorder;
    CADisplayLink *_link;
}

@property (nonatomic, readwrite) MXRecorderRecordStatus recordStatus;
@property (nonatomic, copy) NSString *cafPath;

@end

@implementation MXMp3Recorder

#pragma mark - life cycle
+ (instancetype)shareInstance {
    
    static dispatch_once_t onceToken;
    static id shareInstance;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
        [shareInstance configSessionAndRecorder];
    });
    return shareInstance;
}

+ (instancetype)recorderWithCachePath:(NSString *)cachePath delegate:(id<MXMp3RecorderDelegate>)delegate {
    
    MXMp3Recorder *recorder = [self shareInstance];
    recorder.cachePath = cachePath;
    recorder.delegate = delegate;
    
    return recorder;
}

#pragma mark - private methods
- (void)configSessionAndRecorder {
    if (!_cachePath) {
        // call setter to create dir
        self.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.default.MXMp3Recorder.audioCache"];
        _cafPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmp.caf"];
    }
    [self configAVAudioSession];
    [self configAVAudioRecorder];
}

- (void)configAVAudioSession {
    
    _session = _session ?: [AVAudioSession sharedInstance];
    NSError *sessionError;
    [_session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    
    if(_session == nil) {
        MXLog(@"Error creating session: %@", [sessionError description]);
    } else {
        //[_session setActive:YES error:nil];
        [_session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
    //添加应用进入后台通知
    UIApplication *app = [UIApplication sharedApplication];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:app];
}

- (void)configAVAudioRecorder {
    
    NSError *recorderSetupError = nil;
    NSURL *url = [NSURL fileURLWithPath:[self cafPath]];
    
    //[NSNumber numberWithInt: demo kAudioFormatAppleLossless]
    //AVSampleRateKey: 11025.0  demo 44100.0
    NSDictionary *settings = @{AVSampleRateKey: [NSNumber numberWithFloat: 11025.0],//采样率
                               AVFormatIDKey: [NSNumber numberWithInt: kAudioFormatLinearPCM],//录音格式 无法使用
                               AVNumberOfChannelsKey: [NSNumber numberWithInt: 2],//通道数
                               AVEncoderAudioQualityKey: [NSNumber numberWithInt: AVAudioQualityMin]};//音频质量,采样质量
    _recorder = [[AVAudioRecorder alloc] initWithURL:url
                                            settings:settings
                                               error:&recorderSetupError];
    if (recorderSetupError) {
        MXLog(@"%@",recorderSetupError.localizedDescription);
    }
    _recorder.meteringEnabled = YES;
    _recorder.delegate = self;
}

- (void)startRecordingAndDecibelUpdate:(BOOL)shouldUpdateDecibel {
    self.recordStatus = MXRecorderRecordStatusStart;
    [self configAVAudioSession];
    if (_recorder.isRecording) {
        [_recorder stop];
        [_recorder deleteRecording];
    }
    [_recorder prepareToRecord];
    [_recorder record];
    self.recordStatus = MXRecorderRecordStatusRecording;
    !shouldUpdateDecibel ?: [self addDisplayLink];
}

- (void)pauseRecording {
    if (_recorder.isRecording) {
        [_recorder pause];
        self.recordStatus = MXRecorderRecordStatusPause;
    }
}

- (void)resumeRecording {
    [_recorder record];
    self.recordStatus = MXRecorderRecordStatusRecording;
}

- (void)stopRecording {
    ////MXLog(@"MP3转换开始");
    if (_delegate && [_delegate respondsToSelector:@selector(mp3RecorderDidBeginToConvert:)]) {
        [_delegate mp3RecorderDidBeginToConvert:self];
    }
    NSTimeInterval cTime = _recorder.currentTime;
    [_recorder stop];
    self.recordStatus = MXRecorderRecordStatusEnd;
    if (cTime > 1) {
        [self audio_PCMtoMP3];
    } else {
        [_recorder deleteRecording];
        if ([_delegate respondsToSelector:@selector(mp3RecorderDidFailToRecord:)]) {
            [_delegate mp3RecorderDidFailToRecord:self];
        }
    }
    if(_link) {[_link invalidate]; _link = nil;};
}

- (void)cancelRecording {
    self.recordStatus = MXRecorderRecordStatusEndFromCancel;
    if (_recorder.isRecording) {
        [_recorder stop];
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:_recorder.url.path]) {
        [_recorder deleteRecording];
    }
    if(_link) {[_link invalidate]; _link = nil;};
}

- (BOOL)isRecording {
    return _recorder.isRecording;
}

- (void)audio_PCMtoMP3 {
    id<MXMp3RecorderDelegate> delegate = _delegate;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *mp3FilePath = [_cachePath stringByAppendingPathComponent:[self randomMP3FileName]];
        @try {
            int read, write;
            
            FILE *pcm = fopen([_cafPath cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
            fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
            FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置
            
            const int PCM_SIZE = 8192;
            const int MP3_SIZE = 8192;
            short int pcm_buffer[PCM_SIZE*2];
            unsigned char mp3_buffer[MP3_SIZE];
            
            lame_t lame = lame_init();
            lame_set_in_samplerate(lame, 11025.0);
            lame_set_VBR(lame, vbr_default);
            lame_init_params(lame);
            
            do {
                read = (int)fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
                if (read == 0)
                    write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
                else
                    write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
                
                fwrite(mp3_buffer, write, 1, mp3);
                
            } while (read != 0);
            
            lame_close(lame);
            fclose(mp3);
            fclose(pcm);
        }
        @catch (NSException *exception) {
            //MXLog(@"%@",[exception description]);
            mp3FilePath = nil;
        }
        @finally {
            //[[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];
            //MXLog(@"MP3转换结束");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (delegate && [delegate respondsToSelector:@selector(mp3Recorder:didFinishingConvertingWithMP3FilePath:)]) {
                    [delegate mp3Recorder:self didFinishingConvertingWithMP3FilePath:mp3FilePath];
                }
            });
            [self deleteCafCache];
        }
    });
}

- (void)addDisplayLink {
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    AVAILABLE_WHEN_IOS_VERSION(10.0, link.preferredFramesPerSecond = 2, link.frameInterval = 2)
    [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    _link = link;
}

#pragma mark - NSNotificationCenter Methods
- (void)applicationWillResignActive:(UIApplication *)application {
    [self pauseRecording];
}

#pragma mark - delete files
- (void)deleteMp3Cache{
    [self deleteFileAtPatth:_cachePath];
}

- (void)deleteCafCache {
    [self deleteFileAtPatth:_cafPath];
}

- (void)deleteFileAtPatth:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager removeItemAtPath:path error:nil]) {
        //MXLog(@"删除以前的mp3文件");
    }
}

#pragma mark - setter methods
- (void)setRecordStatus:(MXRecorderRecordStatus)recordStatus {
    if (_recordStatus == recordStatus) return;
    _recordStatus = recordStatus;
    if ([self.delegate respondsToSelector:@selector(mp3Recorder:recordStatusDidChange:)]) {
        [self.delegate mp3Recorder:self recordStatusDidChange:recordStatus];
    }
}

- (void)setCachePath:(NSString *)cachePath {
    if (!cachePath || [_cachePath isEqualToString:cachePath]) return;
    _cachePath = cachePath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark - display link
- (void)displayLinkFired:(CADisplayLink *)link {
    [_recorder updateMeters];
    CGFloat decibels = [_recorder averagePowerForChannel:0];
    if (decibels < -60.0f || decibels == 0.0f) {
        return;
    }
    CGFloat convertedValue = powf((powf(10.0f, 0.05f * decibels) - powf(10.0f, 0.05f * -60.0f)) * (1.0f / (1.0f - powf(10.0f, 0.05f * -60.0f))), 1.0f / 2.0f);
    if (_delegate && [_delegate respondsToSelector:@selector(mp3Recorder:didUpdateDecibel:)]) {
        [_delegate mp3Recorder:self didUpdateDecibel:convertedValue];
    }
}

#pragma mark - Path Utils
- (NSString *)randomMP3FileName {
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    NSString *fileName = [NSString stringWithFormat:@"record_%.0f.mp3",timeInterval];
    return fileName;
}

@end
