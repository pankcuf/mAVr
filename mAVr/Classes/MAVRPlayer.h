//
//  MAVRPlayer.h
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>


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

@protocol MAVRPlayerDelegate;

typedef void (^MAVRPlayerBlockHandler)(id<MAVRPlayerDelegate> delegate, MAVRPlayerNotificationType notificationType);

@interface MAVRPlayer : NSObject

@property (readonly) BOOL isLive;
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
-(void)setVisible:(BOOL)value;

-(void)addHandler:(MAVRPlayerNotificationType)type withBlock:(MAVRPlayerBlockHandler)func;
-(void)removeHandler:(MAVRPlayerNotificationType)type withBlock:(MAVRPlayerBlockHandler)func;

-(void)load:(NSString*)url;
-(void)loadWithContent:(NSString *)content;
-(void)pause;
-(void)play;
-(void)seekToLive;
-(void)seek:(double)time;
-(void)stop;
-(void)switchStream:(NSUInteger)index;

@property (readonly) BOOL pipActive;
@property (readonly) BOOL pipAvailable;

-(BOOL)startPictureInPicture;
-(BOOL)stopPictureInPicture;


-(NSString*)lowestQualityUrl;

-(NSString*)stringifyState:(MAVRPlayerState)state;
-(NSString*)stringifyNotification:(MAVRPlayerNotificationType)notification;

@end
