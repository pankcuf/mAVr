//
//  MAVRViewController.m
//  mAVr
//
//  Created by Vladimir Pirogov on 10/26/2016.
//  Copyright (c) 2016 Vladimir Pirogov. All rights reserved.
//

#import "MAVRViewController.h"
#import "MAVRMainView.h"
#import "MAVRPlayer.h"
#import "MAVRPlayerDelegate.h"

@interface MAVRViewController ()

@end

@implementation MAVRViewController {

	MAVRPlayer* _player;
	MAVRMainView* mainView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

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
	
	//[self loadMultiBitrate:@"http://bl.rutube.ru/live/LIVE/1073/HLS/SD/-vqFBvS2HC990HjL3xnucg/1477499295/S-a:57d6a8f7fe79acea718b4596/playlist_v2.m3u8?audio_only=1"];
	
	[self loadSingleBitrate:@"http://h5media.nationalgeographic.com/video/player/media-mp4/sumatra-marbled-cat-vin/mp4/sumatra-marbled-cat-vin_1800/index0.m3u8"];
}

- (void)loadMultiBitrate:(NSString*)url {
	
	[[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		
		[_player loadWithContent:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
		
	}] resume];
}

- (void)loadSingleBitrate:(NSString*)url {
	
	[_player load:url];
}


@end
