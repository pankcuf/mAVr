//
//  MAVRControlsView.m
//  mAVr
//
//  Created by Vladimir Pirogov on 15/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import "MAVRControlsView.h"

@interface MAVRControlsView()

@end

@implementation MAVRControlsView {
}

- (void)awakeFromNib {
	[super awakeFromNib];
	
	[self.buttonPlayPause setTitle:@">" forState:UIControlStateNormal];
	[self.buttonPlayPause setTitle:@"||" forState:UIControlStateSelected];

	[self.buttonFullScreen setTitle:@"][" forState:UIControlStateNormal];
	[self.buttonFullScreen setTitle:@"[]" forState:UIControlStateSelected];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {

	}
	return self;
}

-(void)updateCurrentTime:(double)time {
	[self.labelCtime setText:[self.class convertTimeToString:time]];
}

-(void)updateBuffer:(double)percent {
	[self.sliderSeek setBufferValue:percent];
}

-(void)updateDuration:(double)time {
	[self.labelDuration setText:[self.class convertTimeToString:time]];
}

-(void)updateSliderSeek:(double)percent {
	//NSLog(@"updateSliderSeek %f", percent);
	[self.sliderSeek setValue:percent];
}

-(void)setEnabled:(BOOL)value {
	[self.buttonPlayPause setEnabled:value];
}

+(NSString*)convertTimeToString:(double)secs {
	int hours =  secs / 3600;
	int minutes = (secs - hours * 3600 ) / 60;
	int seconds = secs - hours * 3600 - minutes * 60;
	
	NSString* s = [NSString stringWithFormat:@"%.2d:%.2d", minutes, seconds];
	if (hours)
		s = [NSString stringWithFormat:@"%.2d:%@", hours, s];

	return s;
}
@end
