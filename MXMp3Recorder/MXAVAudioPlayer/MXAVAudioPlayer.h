//
//  MXAVAudioPlayer.h
//  0919 - MXAVAudioPlayer
//
//  Created by Michael on 2017/9/18.
//  Copyright © 2017年 Michael. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MXAVAudioPlayerPlayStatus) {
    MXAVAudioPlayerPlayStatusStart,
    MXAVAudioPlayerPlayStatusPlaying,
    MXAVAudioPlayerPlayStatusPause,
    MXAVAudioPlayerPlayStatusEndFromCancel,
    MXAVAudioPlayerPlayStatusEnd
};

@class MXAVAudioPlayer;
@protocol MXAVAudioPlayerDelegate <NSObject>

@optional
- (void)audioPlayer:(MXAVAudioPlayer *)player playStatusDidChange:(MXAVAudioPlayerPlayStatus)playStatus;
- (void)MXAVAudioPlayerWillStartPlaying:(MXAVAudioPlayer *)player;
- (void)MXAVAudioPlayerDidFinishDownloading:(MXAVAudioPlayer *)player;
- (void)MXAVAudioPlayerDidFinishPlaying:(MXAVAudioPlayer *)player;

@end

@interface MXAVAudioPlayer : NSObject

@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, weak) id<MXAVAudioPlayerDelegate> delegate;
@property (nonatomic, readonly) MXAVAudioPlayerPlayStatus playStatus;

+ (instancetype)shareInstance;
+ (instancetype)playerWithCachePath:(NSString *)cachePath delegate:(id<MXAVAudioPlayerDelegate>)delegate;

/// 播放音频
- (void)playAudioWithURLString:(NSString *)URLString;
/// 暂停音频
- (void)pauseAudioPlayer;
/// 继续音频
- (void)resumeAudioPlayer;
/// 意外停止，`playStatus`为`MXAVAudioPlayerPlayStatusEndFromCancel`
- (void)stopAudioPlayer;

@end
