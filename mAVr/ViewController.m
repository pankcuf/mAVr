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
					 @"http://bl.rutube.ru/route/a849305a707eaeba0de5a82ea98ff35e.m3u8?guids=896859f6-84e1-4aed-903f-075820d3559f_1280x720_2923410_avc1.640028_mp4a.40.2,7e1251ea-14af-4f84-996b-90256bbcfeee_896x504_1579911_avc1.4d401f_mp4a.40.2,6e795483-f70a-4d44-abe9-704bf5519096_640x360_990604_avc1.4d401f_mp4a.40.5,9ab1df34-045f-4fa8-88ff-21dec3eecdb0_512x288_684899_avc1.42c01e_mp4a.40.5&sign=0f3261c62701190cd469b640ac8cb41e&expire=1424268724",
					  @"http://bl.rutube.ru/route/aa2c3c7c3a2e470f97a4d089298ec2ad.m3u8?guids=43b55da7-8144-4b00-84fe-f32425be0824_1280x720_2268284_avc1.4d401f_mp4a.40.2,640b4744-ccce-4f04-ae7c-f7d701e085c0_768x432_1361770_avc1.4d401f_mp4a.40.5,7a602420-4a9a-4d7c-a045-c8264915cc5e_512x288_794551_avc1.42c01e_mp4a.40.5&sign=3e0a6bdf19eb512c85f213330f853baf&expire=1424209410",
					  @"http://bl.rutube.ru/route/6a2c33d1b04d990b1ffea07f7b8e8646.m3u8?guids=0a2e0fa2-08ec-40c8-b7f5-1503987749bd_496x368_535254_avc1.42c015_mp4a.40.2&sign=35acbbc525b4de3a1d97b2321778cb47&expire=1424124727",
					  @"http://h5media.nationalgeographic.com/video/player/media-mp4/sumatra-marbled-cat-vin/mp4/sumatra-marbled-cat-vin_1800/index0.m3u8",
					  @"http://bl.rutube.ru/route/761bf201c840b57bb3663a63c40b847f.m3u8?guids=e890f2a3-6527-4a5a-8608-52b9b6c102c8_992x544_1261312_avc1.4d401f_mp4a.40.2,940ce4f7-a4a7-4ef4-92c8-1311e7d8e283_768x432_1032495_avc1.4d401f_mp4a.40.5,6d44bb01-998a-422f-b707-9b4c1d36bd05_512x288_679308_avc1.42c01e_mp4a.40.5&sign=f480fd66fb3858b58545a4fbd9ad8af2&expire=1423961988"
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

//	[self playNext];
	
	
	
//	NSString* str = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n",
//					 @"#EXTM3U",
//					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=794000, CODECS=\"avc1.42c01e, mp4a.40.5\"\n"
//					 @"http://video-1-13.rutube.ru/hls-vod/HuI2Mn-nX8xP-KyMX_2cWg/1424282206/34/0x5000c500677355c1/7a6024204a9a4d7ca045c8264915cc5e.mp4.m3u8?i=512x288_794",
//					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=1361000, CODECS=\"avc1.4d401f, mp4a.40.5\"",
//					 @"http://video-1-13.rutube.ru/hls-vod/k8LLylX1H5Q4PcfPpBNh5Q/1424282206/42/0x5000cca23de5a4ae/640b4744ccce4f04ae7cf7d701e085c0.mp4.m3u8?i=768x432_1361",
//					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=2268000, CODECS=\"avc1.4d401f, mp4a.40.2\"",
//					 @"http://video-1-13.rutube.ru/hls-vod/Z7PBhFJPvdLK_m4OCCfv1Q/1424282206/40/0x5000cca23de49464/43b55da781444b0084fef32425be0824.mp4.m3u8?i=1280x720_2268"
//					 ];

	NSString* str = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n",
					 @"#EXTM3U",
					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=679000, CODECS=\"avc1.42c01e, mp4a.40.5\"\n"
					 @"http://video-1-19.rutube.ru/hls-vod/55JtF70d5nGRHOiWDoL4RQ/1424302113/7/n2vol2/6d44bb01998a422fb7079b4c1d36bd05.mp4.m3u8?i=512x288_679",
					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=1032000, CODECS=\"avc1.4d401f, mp4a.40.5\"",
					 @"http://video-1-19.rutube.ru/hls-vod/RhwhNW08HHtrIFaMbQB1cA/1424302113/7/n5vol1/940ce4f7a4a74ef492c81311e7d8e283.mp4.m3u8?i=768x432_1032",
					 @"#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=1261000, CODECS=\"avc1.4d401f, mp4a.40.2\"",
					 @"http://video-1-19.rutube.ru/hls-vod/r5tlgEhp0aquj1JtOlpqHg/1424302113/7/n5vol1/e890f2a365274a5a860852b9b6c102c8.mp4.m3u8?i=992x544_1261"
					 ];

	
	
//	NSString* str = @"#EXTM3U";
//#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=794000, CODECS=\"avc1.42c01e, mp4a.40.5\"\r\
//http://video-1-13.rutube.ru/hls-vod/HuI2Mn-nX8xP-KyMX_2cWg/1424282206/34/0x5000c500677355c1/7a6024204a9a4d7ca045c8264915cc5e.mp4.m3u8?i=512x288_794\r\
//#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=1361000, CODECS=\"avc1.4d401f, mp4a.40.5\"\r\
//http://video-1-13.rutube.ru/hls-vod/k8LLylX1H5Q4PcfPpBNh5Q/1424282206/42/0x5000cca23de5a4ae/640b4744ccce4f04ae7cf7d701e085c0.mp4.m3u8?i=768x432_1361\r\
//#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=2268000, CODECS=\"avc1.4d401f, mp4a.40.2\"\r\
//http://video-1-13.rutube.ru/hls-vod/Z7PBhFJPvdLK_m4OCCfv1Q/1424282206/40/0x5000cca23de49464/43b55da781444b0084fef32425be0824.mp4.m3u8?i=1280x720_2268";
	
	
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
