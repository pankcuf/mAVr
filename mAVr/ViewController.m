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

	NSString *url = @"http://bl.rutube.ru/live/LIVE/1073/HLS/SD/-vqFBvS2HC990HjL3xnucg/1477499295/S-a:57d6a8f7fe79acea718b4596/playlist_v2.m3u8?audio_only=1";
	
	[[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		
		
		
		NSString* newStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		
		[_player loadWithContent:newStr];

	}] resume];

}

-(void)loadRootManifest:(NSString*)url {
	
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

@end
