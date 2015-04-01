//
//  MAVRUITimeline.m
//  mAVr
//
//  Created by Vladimir Pirogov on 16/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import "MAVRUITimeline.h"
#import "MAVRUILoadingBar.h"
#define THUMB_SIZE 15
#define EFFECTIVE_THUMB_SIZE 25

@interface MAVRUITimeline()
@property (nonatomic, strong) MAVRUILoadingBar *bufferView;
@end

@implementation MAVRUITimeline

-(id)initWithCoder:(NSCoder *)aDecoder {
	
	self = [super initWithCoder:aDecoder];
	
	if (self) {

		self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
		
		[self setMaximumTrackTintColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.3]];

		_bufferValue = 0;
		
		_bufferView = [[MAVRUILoadingBar alloc] initWithFrame:self.bounds];

		[self addSubview:_bufferView];

		[self sendSubviewToBack:_bufferView];
	}
	return self;
}

-(CGRect)trackRectForBounds:(CGRect)bounds {
	CGRect resultBounds = bounds;
	resultBounds.size.height = 5;
	resultBounds.origin.y = ( bounds.size.height - resultBounds.size.height ) / 2;
	return resultBounds;
}

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
	CGRect bounds = self.bounds;
	bounds = CGRectInset(bounds, -15, -10);
	return CGRectContainsPoint(bounds, point);
}

-(BOOL)beginTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event {
	
	CGRect bounds = self.bounds;
	float thumbPercent = (self.value - self.minimumValue) / (self.maximumValue - self.minimumValue);
	float thumbPos = THUMB_SIZE + (thumbPercent * (bounds.size.width - (2 * THUMB_SIZE)));
	CGPoint touchPoint = [touch locationInView:self];
	return (touchPoint.x >= (thumbPos - EFFECTIVE_THUMB_SIZE) && touchPoint.x <= (thumbPos + EFFECTIVE_THUMB_SIZE));
}


-(void)setFrame:(CGRect)frame {
	
	[super setFrame:frame];
	
	self.bufferView.frame = self.bounds;
	self.bufferValue = _bufferValue;
}

-(void)setBufferValue:(float)bufferingValue {
	
	_bufferView.value = bufferingValue;

	[_bufferView setNeedsDisplay];
}

@end
