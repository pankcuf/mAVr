//
//  MAVRPlayerDelegate.h
//  mAVr
//
//  Created by Vladimir Pirogov on 15/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import "MAVRPlayer.h"

@protocol MAVRPlayerDelegate <NSObject>
@property (readonly) MAVRPlayerState state;

@property (readonly) double duration;
@property (readonly) double currentTime;
@property (readonly) double bufferTime;
@property (readonly) NSUInteger currentStreamIndex;
@property (readonly) BOOL isExternalPlayback;

-(void)setVisible:(BOOL)value;
-(void)addHandler:(MAVRPlayerNotificationType)type withBlock:(MAVRPlayerBlockHandler)func;
-(void)removeHandler:(MAVRPlayerNotificationType)type withBlock:(MAVRPlayerBlockHandler)func;

-(void)pause;
-(void)play;
-(void)seek:(double)time;
-(void)switchStream:(NSUInteger)index;

-(NSString*)stringifyState:(MAVRPlayerState)state;
-(NSString*)stringifyNotification:(MAVRPlayerNotificationType)notification;

@end
