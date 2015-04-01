//
//  ViewController.m
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import "ViewController.h"
#import "MAVRMainView.h"
#import "MAVRPlayer.h"
#import "MAVRPlayerDelegate.h"

@interface ViewController ()

@end

@implementation ViewController {
	MAVRPlayer* _player;
	MAVRMainView* mainView;

	NSEnumerator *_enumerator;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.autoresizesSubviews = YES;
	
	_enumerator = [@[
					  @"http://h5media.nationalgeographic.com/video/player/media-mp4/sumatra-marbled-cat-vin/mp4/sumatra-marbled-cat-vin_1800/index0.m3u8",
											  ] objectEnumerator];
	
	mainView = (MAVRMainView*)self.view;
	_player = [[MAVRPlayer alloc] initWithView:mainView.playerHolder];

	[mainView initWithDelegate:(id)_player];

	void (^handler)() = ^(id<MAVRPlayerDelegate> delegate, MAVRPlayerNotificationType notificationType) {
	
		switch (notificationType) {
			case MAVRPlayerNotificationError:
			case MAVRPlayerNotificationCompleted:
				//[self playNext];
				break;

			default:
				break;
		}
	};
		
	[_player addHandler:MAVRPlayerNotificationCompleted withBlock:handler];
	[_player addHandler:MAVRPlayerNotificationError withBlock:handler];

	NSString* str = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n",
					 @"#EXTM3U",
					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=679000, CODECS=\"avc1.42c01e, mp4a.40.5\"\n"
					 @"http://video-1-19.rutube.ru/hls-vod/55JtF70d5nGRHOiWDoL4RQ/1424302113/7/n2vol2/6d44bb01998a422fb7079b4c1d36bd05.mp4.m3u8?i=512x288_679",
					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=1032000, CODECS=\"avc1.4d401f, mp4a.40.5\"",
					 @"http://video-1-19.rutube.ru/hls-vod/RhwhNW08HHtrIFaMbQB1cA/1424302113/7/n5vol1/940ce4f7a4a74ef492c81311e7d8e283.mp4.m3u8?i=768x432_1032",
					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=1261000, CODECS=\"avc1.4d401f, mp4a.40.2\"",
					 @"http://video-1-19.rutube.ru/hls-vod/r5tlgEhp0aquj1JtOlpqHg/1424302113/7/n5vol1/e890f2a365274a5a860852b9b6c102c8.mp4.m3u8?i=992x544_1261"
					 ];

	[_player loadWithContent:str];
}

-(void)playNext {
	NSString* s = [_enumerator nextObject];
	
	if (s)
		[_player load:s];
	else
		_player = nil;
}

- (void)orientationChanged:(NSNotification *)notification {
	//UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	
	[mainView setNeedsDisplay];
	[mainView setNeedsLayout];

	//NSLog(@"Orientation changed %ld", orientation);
}

-(NSUInteger)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (void)viewDidLayoutSubviews {
	//NSLog(@"viewDidLayoutSubviews");
	[super viewDidLayoutSubviews];
}

-(void)viewWillAppear:(BOOL)animated {
	//NSLog(@"viewWillAppear");
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
}

-(void)viewWillDisappear:(BOOL)animated {
	//NSLog(@"viewWillDisappear");
	[super viewWillDisappear:animated];

	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

-(void)viewWillLayoutSubviews {
	//NSLog(@"viewWillLayoutSubviews");
	[super viewWillLayoutSubviews];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
	//NSLog(@"viewWillTransitionToSize(%@) with %@", NSStringFromCGSize(size), coordinator);
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

@end
