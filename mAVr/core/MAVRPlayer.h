//
//  MAVRPlayer.h
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

typedef void (^MAVRPlayerBlockHandler)();

typedef enum {
	MAVRPlayerStateLoading,
	MAVRPlayerStateReady,
	MAVRPlayerStateBuffering,
	MAVRPlayerStatePlaying,
	MAVRPlayerStatePaused,
	MAVRPlayerStateCompleted,
	MAVRPlayerStateError
} MAVRPlayerState;

typedef enum {
	MAVRPlayerNotificationLoading,
	MAVRPlayerNotificationReady,
	MAVRPlayerNotificationBufferChange,
	MAVRPlayerNotificationBufferingStart,
	MAVRPlayerNotificationBufferingEnd,
	MAVRPlayerNotificationSwitchQualityStart,
	MAVRPlayerNotificationSwitchQualityEnd,
	MAVRPlayerNotificationSeekingStart,
	MAVRPlayerNotificationSeekingEnd,
	MAVRPlayerNotificationPlaying,
	MAVRPlayerNotificationPaused,
	MAVRPlayerNotificationCurrentTimeChange,
	MAVRPlayerNotificationDurationChange,
	MAVRPlayerNotificationStarted,
	MAVRPlayerNotificationCompleted,
	MAVRPlayerNotificationVideoSizeChange,
	MAVRPlayerNotificationExternalPlaybackActive,
	MAVRPlayerNotificationError,

} MAVRPlayerNotificationType;

@interface MAVRPlayer : NSObject

@property (readonly) double duration;
@property (readonly) double currentTime;
@property (readonly) double bufferTime;
@property (readonly) NSUInteger currentStreamIndex;

@property (readonly) NSUInteger streamsCount;
@property (readonly) BOOL isExternalPlayback;
@property (nonatomic, setter=setIsZoomed:) BOOL isZoomed;

@property (readonly) MAVRPlayerState state;

-(id)initWithView:(UIView*)parent;
-(void)setFrame:(CGRect)frame;

-(void)addHandler:(MAVRPlayerNotificationType)type withBlock:(MAVRPlayerBlockHandler)func;
-(void)removeHandler:(MAVRPlayerNotificationType)type withBlock:(MAVRPlayerBlockHandler)func;

-(void)load:(NSString*)url;
-(void)loadWithContent:(NSString *)content;
-(void)pause;
-(void)play;
-(void)seek:(double)time;
-(void)stop;
-(void)switchStream:(NSUInteger)index;

-(NSString*)lowestQualityUrl;

-(NSString*)stringifyState:(MAVRPlayerState)state;

@end