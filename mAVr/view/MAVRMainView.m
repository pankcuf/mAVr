//
//  MAVRMainView.m
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import "MAVRMainView.h"

@interface MAVRMainView()

@end

@implementation MAVRMainView {
	id<MAVRPlayerDelegate> playerDelegate;
	void (^playerNotification)(id<MAVRPlayerDelegate> delegate, MAVRPlayerNotificationType state);
	float seekTarget;
	BOOL seeking;
}

- (void)awakeFromNib {
	[super awakeFromNib];
	
	[self setControlsHidden:YES];
	[self setControlsEnabled:NO];
	[self.playerHolder setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
	[self.controls setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
	
	[self.controls.buttonPlayPause addTarget:self action:@selector(buttonPlayPausePressed:) forControlEvents:UIControlEventTouchUpInside];
	[self.controls.buttonFullScreen addTarget:self action:@selector(buttonFullScreenPressed:) forControlEvents:UIControlEventTouchUpInside];
	
	[self.controls.sliderSeek setContinuous:NO];
	[self.controls.sliderSeek addTarget:self action:@selector(sliderSeekTouchDown:) forControlEvents:UIControlEventTouchDown];
	[self.controls.sliderSeek addTarget:self action:@selector(sliderSeekValueChange:) forControlEvents:UIControlEventValueChanged];
	[self.controls.sliderSeek addTarget:self action:@selector(sliderSeekTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
	
	[self.buttonMinus addTarget:self action:@selector(buttonSwitchMinus:) forControlEvents:UIControlEventTouchUpInside];
	[self.buttonPlus addTarget:self action:@selector(buttonSwitchPlus:) forControlEvents:UIControlEventTouchUpInside];
}

-(void)initWithDelegate:(id<MAVRPlayerDelegate>)delegate {
	playerDelegate = delegate;
	__weak typeof(self) weakSelf = self;
	
	playerNotification = ^(id<MAVRPlayerDelegate> delegate, MAVRPlayerNotificationType notificationType) {
		
		switch (notificationType) {
			
			case MAVRPlayerNotificationLoading:
				NSLog(@"playerNotification: MAVRPlayerNotificationLoading state %@", [delegate stringifyState:[delegate state]]);
				
				[weakSelf setControlsHidden:YES];
				[weakSelf setControlsEnabled:YES];
				[weakSelf updateDuration];
				[weakSelf updateCurrentTime];
				break;

			case MAVRPlayerNotificationReady:
				NSLog(@"playerNotification: MAVRPlayerNotificationReady state %@", [delegate stringifyState:[delegate state]]);
				
				[weakSelf setControlsHidden:NO];
				[weakSelf setControlsEnabled:YES];
				[weakSelf updateDuration];
				[weakSelf updateCurrentTime];
				break;
				
			case MAVRPlayerNotificationStarted:
				NSLog(@"playerNotification: MAVRPlayerNotificationStarted state %@", [delegate stringifyState:[delegate state]]);
				
				[weakSelf updateDuration];
				[weakSelf updateCurrentTime];
				[weakSelf setControlsEnabled:YES];
				[weakSelf setPlayButtonSelected:YES];
				break;
			
			case MAVRPlayerNotificationPlaying:
				NSLog(@"playerNotification: MAVRPlayerNotificationPlaying state %@", [delegate stringifyState:[delegate state]]);

				[weakSelf setControlsEnabled:YES];
				[weakSelf setPlayButtonSelected:YES];
				break;
				
			case MAVRPlayerNotificationPaused:
				NSLog(@"playerNotification: MAVRPlayerNotificationPaused state %@", [delegate stringifyState:[delegate state]]);

				[weakSelf setControlsEnabled:YES];
				[weakSelf setPlayButtonSelected:NO];
				break;
			
			case MAVRPlayerNotificationCompleted:
				NSLog(@"playerNotification: MAVRPlayerNotificationCompleted state %@", [delegate stringifyState:[delegate state]]);
				
				[weakSelf updateCurrentTime];
				[weakSelf setPlayButtonSelected:NO];
				break;

			case MAVRPlayerNotificationError:
				NSLog(@"playerNotification: MAVRPlayerNotificationError state %@", [delegate stringifyState:[delegate state]]);
				break;
				
			case MAVRPlayerNotificationCurrentTimeChange:
				NSLog(@"playerNotification: MAVRPlayerNotificationCurrentTimeChange state %@ currentTime %f", [delegate stringifyState:[delegate state]], [delegate currentTime]);
				[weakSelf updateCurrentTime];
				break;
				
			case MAVRPlayerNotificationBufferChange:
//				NSLog(@"playerNotification: MAVRPlayerNotificationBufferChange state %@ buffer %f ", [delegate stringifyState:[delegate state]], [delegate bufferTime]);
				[weakSelf updateBuffer];
				break;

			default:
				break;
		}
	};
	
	[playerDelegate addHandler:MAVRPlayerNotificationLoading withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationReady withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationStarted withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationPlaying withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationPaused withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationCompleted withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationCurrentTimeChange withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationBufferChange withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationBufferingStart withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationBufferingEnd withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationError withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationSwitchQualityStart withBlock:playerNotification];
	[playerDelegate addHandler:MAVRPlayerNotificationSwitchQualityEnd withBlock:playerNotification];
}

-(void)dealloc {
	[playerDelegate removeHandler:MAVRPlayerNotificationLoading withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationReady withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationStarted withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationPlaying withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationPaused withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationCompleted withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationCurrentTimeChange withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationBufferChange withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationBufferingStart withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationBufferingEnd withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationError withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationSwitchQualityStart withBlock:playerNotification];
	[playerDelegate removeHandler:MAVRPlayerNotificationSwitchQualityEnd withBlock:playerNotification];
	
	playerDelegate = nil;
	playerNotification = nil;
}

- (void)layoutSubviews {

	self.playerHolder.frame = self.bounds;
	
	for (CALayer* sub in self.playerHolder.layer.sublayers) {
		sub.frame = self.playerHolder.layer.bounds;
	}
	
	CGRect crect = self.bounds;
	crect.origin.y = self.frame.origin.y + self.bounds.size.height - self.controls.bounds.size.height;

	switch ([UIDevice currentDevice].orientation) {
		case UIDeviceOrientationLandscapeLeft:
		case UIDeviceOrientationLandscapeRight:
			self.controls.buttonFullScreen.selected = YES;
			break;
		case UIDeviceOrientationPortrait:
			self.controls.buttonFullScreen.selected = NO;
		default:
			break;
	}
	
	self.controls.frame = crect;
}
-(void)buttonPlayPausePressed:(UIButton *)sender {
	
	self.controls.buttonPlayPause.enabled = NO;
	
	switch ([playerDelegate state]) {
		
		case MAVRPlayerStatePlaying:
			[playerDelegate pause];
			break;
		
		case MAVRPlayerStateReady:
			
			[self.controls.labelCtime setText:[[NSNumber numberWithDouble:[playerDelegate currentTime]] stringValue]];
			[self.controls.labelDuration setText: [[NSNumber numberWithDouble:[playerDelegate duration]] stringValue]];
			
		case MAVRPlayerStateCompleted:
		case MAVRPlayerStatePaused:
			[playerDelegate play];
			break;
			
		default:
			break;
	}
}

-(void)buttonFullScreenPressed:(UIButton *)sender {
	
	switch ([UIDevice currentDevice].orientation) {
		
		case UIDeviceOrientationLandscapeLeft:
		case UIDeviceOrientationLandscapeRight:
			[[UIDevice currentDevice] setValue:[NSNumber numberWithInteger: UIInterfaceOrientationPortrait] forKey:@"orientation"];
			break;
		
		case UIDeviceOrientationPortrait:
			[[UIDevice currentDevice] setValue:[NSNumber numberWithInteger: UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
		
		default:
			break;
	}
}

#pragma mark wrappers
-(void)setControlsHidden:(BOOL)value {
	[self.controls setHidden:value];
}

-(void)setControlsEnabled:(BOOL)value {
	[self.controls setEnabled:value];
}

-(void)setPlayButtonSelected:(BOOL)value {
	[self.controls.buttonPlayPause setSelected:value];
}

-(void)updateCurrentTime {
	if (seeking)
		return;
	
	double ctime = [playerDelegate currentTime];
	[self.controls updateCurrentTime:ctime];
	[self.controls updateSliderSeek:ctime / [playerDelegate duration]];
}

-(void)updateDuration {
	[self.controls updateDuration:[playerDelegate duration]];
}

-(void)updateBuffer {
	[self.controls updateBuffer:[playerDelegate bufferTime] / [playerDelegate duration]];
}

#pragma mark Handlers for slider

-(void)sliderSeekTouchDown:(id)sender {

	seekTarget = -1;
	seeking = YES;
}

-(void)sliderSeekTouchUp:(id)sender {
	
	if (seekTarget > -1)
		[playerDelegate seek:seekTarget];
	
	seekTarget = -1;
	seeking = NO;
}

-(void)sliderSeekValueChange:(id)sender {
	
	seekTarget = [self.controls.sliderSeek value]*[playerDelegate duration];
	
	if (seekTarget > -1)
		[playerDelegate seek:seekTarget];
}

-(void)buttonSwitchMinus:(id)sender {
	[playerDelegate switchStream:[playerDelegate currentStreamIndex] - 1];
}
-(void)buttonSwitchPlus:(id)sender {
	[playerDelegate switchStream:[playerDelegate currentStreamIndex] + 1];
}



@end