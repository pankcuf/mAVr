//
//  MAVRControlsView.h
//  mAVr
//
//  Created by Vladimir Pirogov on 15/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MAVRUITimeline.h"

@interface MAVRControlsView : UIView
@property (weak, nonatomic) IBOutlet UIButton* buttonPlayPause;
@property (weak, nonatomic) IBOutlet UILabel* labelCtime;
@property (weak, nonatomic) IBOutlet MAVRUITimeline* sliderSeek;
@property (weak, nonatomic) IBOutlet UILabel* labelDuration;
@property (weak, nonatomic) IBOutlet UIButton* buttonFullScreen;
-(void)updateCurrentTime:(double)time;
-(void)updateBuffer:(double)time;
-(void)updateDuration:(double)time;
-(void)updateSliderSeek:(double)percent;
-(void)setEnabled:(BOOL)value;
@end
