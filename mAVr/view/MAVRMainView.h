//
//  MAVRMainView.h
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MAVRControlsView.h"
#import "MAVRPlayerDelegate.h"

@interface MAVRMainView : UIView
@property (weak, nonatomic) IBOutlet UIView *playerHolder;
@property (weak, nonatomic) IBOutlet MAVRControlsView *controls;
@property (weak, nonatomic) IBOutlet UIButton *buttonPlus;
@property (weak, nonatomic) IBOutlet UIButton *buttonMinus;

-(void)initWithDelegate:(id<MAVRPlayerDelegate>)delegate;
@end
