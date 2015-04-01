//
//  MAVRUILoadingBar.m
//  mAVr
//
//  Created by Vladimir Pirogov on 17/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//
#import "MAVRUILoadingBar.h"
@interface MAVRUILoadingBar()
@end

@implementation MAVRUILoadingBar

-(id)initWithFrame:(CGRect)frame {
	
	self = [super initWithFrame:frame];
	
	if (self) {
		
		_value = 0;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.userInteractionEnabled = NO;
		self.layer.masksToBounds = YES;
		self.layer.cornerRadius = 2.5;
	}
	
	return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		_value = 0;

		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.userInteractionEnabled = NO;
		self.layer.masksToBounds = YES;
		self.layer.cornerRadius = 2.5;
	}
	return self;
}


-(void)drawRect:(CGRect)rect {
	CGContextRef c = UIGraphicsGetCurrentContext();
	[[UIColor whiteColor] set];
	CGContextFillRect(c, CGRectMake(self.bounds.origin.x, (self.bounds.size.height - 5) / 2, self.bounds.size.width * self.value, 5));
}
@end