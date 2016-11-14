//
//  MAVRPlayer.m
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "M3U8Kit.h"
#import "MAVRPlayer.h"
#import "MAVRPlayerDelegate.h"

#define kMAVR_EXTERNAL_PLAYBACK_ACTIVE @"externalPlaybackActive"
#define kMAVR_LOADED_TIME_RANGES @"loadedTimeRanges"
#define kMAVR_PRESENTATION_SIZE @"presentationSize"
#define kMAVR_BUFFER_EMPTY @"playbackBufferEmpty"
#define kMAVR_BUFFER_FULL @"playbackBufferFull"
#define kMAVR_STATUS @"status"
#define kMAVR_RATE @"rate"
#define kMAVR_CURRENT_ITEM @"currentItem"
#define kMAVR_DURATION @"duration"
#define kMAVR_PLAYBACK_LIKELY_KEEP_UP @"playbackLikelyToKeepUp"

#define kMAVR_STALL_TIME 8.0f

static void *kPlayerItemContext = (void *) 1;
static void *kPlayerItemStatusContext = (void *) 2;
static void *kPlayerRateContext = (void *) 4;
static void *kPlayerBufferChangeContext = (void *) 8;
static void *kPlayerBufferEmptyContext = (void *) 16;
static void *kPlayerBufferFullContext = (void *) 32;
static void *kPlayerVideoSizeContext = (void *) 64;
static void *kPlayerExternalPlaybackContext = (void *) 128;
static void *kPlayerDurationContext = (void *) 256;
static void *kPlaybackLikelyToKeepUpContext = (void *) 512;

#if TARGET_OS_TV

@interface MAVRPlayer() <MAVRPlayerDelegate, AVAudioPlayerDelegate>

#else

@interface MAVRPlayer() <MAVRPlayerDelegate, AVAudioPlayerDelegate, AVPictureInPictureControllerDelegate>

@property (readonly) AVPictureInPictureController* pipController;

#endif


-(void)notify:(MAVRPlayerNotificationType)notificationType;
-(void)callHandlers:(NSMutableArray*)blocks forType:(MAVRPlayerNotificationType)type;
-(void)bufferFullHandler;
-(void)bufferEmptyHandler;
-(void)playbackLikelyToKeepUpHandler;
-(void)externalPlaybackActiveHandler;
-(void)bufferChanged:(NSArray*)timeRanges;
-(void)itemReplaced:(AVPlayerItem*)oldItem by:(AVPlayerItem*)newItem;
-(void)rateChanged:(float)newRate;
-(void)statusChanged:(AVPlayerItemStatus)newStatus;
-(void)resetPlayer;
-(void)addBoundaryObservers;
-(void)removeBoundaryObservers;
-(void)removeCurrentTimeObserver;
-(void)removeStartObserver;
-(void)handleReady;
-(void)handleComplete;
-(void)handleError;
-(void)startStallTimer;
-(void)stopStallTimer;
-(CGFloat)getLiveTime;
-(void)handleDuration:(CGFloat)newValue;
-(void)handleLiveDuration;

#pragma mark M3U8 methods
-(NSString*)getStreamUrlForIndex:(NSUInteger)index;

#pragma mark Debug methods
-(NSString*)stringifyNotification:(MAVRPlayerNotificationType)notification;
-(NSString*)getFlagsString;
-(NSString*)stringifyAVPlayerItemStatus:(AVPlayerItemStatus)status;
@end

@implementation MAVRPlayer {
	
	AVPlayer* _player;
	AVPlayerLayer* _layer;
	AVAsset* _asset;
	NSMutableDictionary* registeredHandlers;
	
	M3U8MasterPlaylist* _playlist;
	NSTimer* stallTimer;
	id observerCurrentTime;
	id observerStart;
	
	BOOL started;
	BOOL completed;
	BOOL seeking;
	BOOL waitForResume;
	BOOL waitForComplete;
	BOOL switching;
	BOOL readdAfterReturnToForeground;
	BOOL autoPlayAfterReturnToForeground;
	BOOL ready;
	BOOL waitForLegalPause;
	BOOL seekNotAllowed;
	
	
	double seekToTime;
	double marginBeforeEnd;
	
	CGSize _bufferRange;
	
	float previousRate;
	
	AVPlayerItem* emptyItem;
	
}

#pragma mark lifecycle

-(id)initWithView:(UIView*)parent {
	
	self = [super init];
	
	if (self) {
		
		started = switching = seeking = completed = waitForResume = waitForComplete = ready = waitForLegalPause = seekNotAllowed = NO;
		
		id nilItem = nil;
		
		emptyItem = [AVPlayerItem playerItemWithURL:nilItem];
		
		marginBeforeEnd = 0.099;
		registeredHandlers = [NSMutableDictionary dictionaryWithCapacity:1];
		
		_player = [[AVPlayer alloc] init];
		_player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
		_layer = [AVPlayerLayer playerLayerWithPlayer:_player];
		_layer.frame = parent.bounds;
		_layer.videoGravity = AVLayerVideoGravityResizeAspect;
		[parent.layer addSublayer:_layer];
		
#if TARGET_OS_TV
#else
		
		if( [AVPictureInPictureController isPictureInPictureSupported] ) {
			_pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:_layer];
			_pipController.delegate = self;
		}
		
#endif
		
		
		
		NSNotificationCenter* dispatcher = [NSNotificationCenter defaultCenter];
		
		[dispatcher addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
		[dispatcher addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[dispatcher addObserver:self selector:@selector(handlePlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
		[dispatcher addObserver:self selector:@selector(handleFailedToPlayToEndTime:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player];
		[dispatcher addObserver:self selector:@selector(handlePlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:_player];
		
		NSError *error = nil;
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error: &error];
		[[AVAudioSession sharedInstance] setActive:YES error:&error];
		
		[_player addObserver:self forKeyPath:kMAVR_CURRENT_ITEM	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:kPlayerItemContext];
		[_player addObserver:self forKeyPath:kMAVR_RATE			options:NSKeyValueObservingOptionNew	context:kPlayerRateContext];
		[_player addObserver:self forKeyPath:kMAVR_EXTERNAL_PLAYBACK_ACTIVE options:NSKeyValueObservingOptionNew context:kPlayerExternalPlaybackContext];
	}
	
	return self;
}

-(double)bufferTime
{
	//check currentTime to hide buffer after backseek
	//check duration because the real is a little different
	return _currentTime < _bufferRange.width? 0: MAX(0, _bufferRange.width + (_bufferRange.height>_duration-1? _duration: _bufferRange.height)- _currentTime);
	
}

-(void)setFrame:(CGRect)frame {
	
	_layer.frame = frame;
	
}

-(void)setVisible:(BOOL)value {
	[_layer setHidden:!value];
	
}

-(void)resetPlayer {
	
	[_player cancelPendingPrerolls];
	
	[self stopStallTimer];
	[self removeBoundaryObservers];
	
	_currentStreamIndex = 0;
	previousRate = 0.0;
	_playlist = nil;
	started = NO;
	completed = NO;
	seeking = NO;
	waitForComplete = NO;
	waitForResume = NO;
	switching = NO;
	
}


-(void)dealloc {
	
	registeredHandlers = nil;
	
	[_player replaceCurrentItemWithPlayerItem:emptyItem];
	[self resetPlayer];
	
	@try {
		[_player removeObserver:self forKeyPath:kMAVR_RATE			context:kPlayerRateContext];
	} @catch (id anException) {}
	
	@try {
		[_player removeObserver:self forKeyPath:kMAVR_CURRENT_ITEM	context:kPlayerItemContext];
	} @catch (id anException) {}
	
	@try {
		[_player removeObserver:self forKeyPath:kMAVR_EXTERNAL_PLAYBACK_ACTIVE	context:kPlayerExternalPlaybackContext];
	} @catch (id anException) {}
	
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_layer removeFromSuperlayer];
	
#if TARGET_OS_TV
#else
	
	_pipController.delegate = nil;
	_pipController = nil;
	
#endif
	
	_layer = nil;
	_player = nil;
	
}

#pragma mark public API

-(void)addHandler:(MAVRPlayerNotificationType)notificationType withBlock:(MAVRPlayerBlockHandler)func {
	
	NSNumber* key = [NSNumber numberWithInt:notificationType];
	NSMutableArray *notificationHandlers = [registeredHandlers objectForKey:key];
	
	if (!notificationHandlers) {
		
		notificationHandlers = [NSMutableArray arrayWithObject:func];
		[registeredHandlers setObject:notificationHandlers forKey:key];
		
	} else if (![notificationHandlers containsObject:func]) {
		
		[notificationHandlers addObject:func];
	}
}

-(void)removeHandler:(MAVRPlayerNotificationType)notificationType withBlock:(MAVRPlayerBlockHandler)func {
	
	NSNumber* key = [NSNumber numberWithInt:notificationType];
	NSMutableArray *notificationHandlers = [registeredHandlers objectForKey:key];
	
	if (notificationHandlers && [notificationHandlers containsObject:func]) {
		
		[notificationHandlers removeObject:func];
		
		if ([notificationHandlers count] == 0)
			[registeredHandlers removeObjectForKey:key];
	}
}

-(void)load:(NSString*)url {
	
	if (!url)
		return;
	
	_state = MAVRPlayerStateLoading;
	previousRate = 0.0;
	
	[self notify:MAVRPlayerNotificationLoading];
	
	_asset = [AVAsset assetWithURL:[NSURL URLWithString:url]];
	
	AVPlayerItem* item = [[AVPlayerItem alloc] initWithAsset:_asset];
	
	[_player replaceCurrentItemWithPlayerItem:item];
	
}

-(void)loadWithContent:(NSString *)content {
	
	_currentStreamIndex = 0;
	
	started = ready = NO;
	
	_playlist = [[M3U8MasterPlaylist alloc] initWithContent:content baseURL:nil];
	
	if (self.streamsCount <= 0) {
		
		[self handleError];
		
	} else {
		
		[self load:[self getStreamUrlForIndex:_currentStreamIndex]];
	}
}

-(void)switchStream:(NSUInteger)index {
	
	if (_currentStreamIndex == index)
		return;
	
	_currentStreamIndex = index;
	
	switching = YES;
	seekToTime = _currentTime;
	
	waitForResume = _player.rate != 0.0;
	
	[self notify:MAVRPlayerNotificationSwitchQualityStart];
	
	_asset = [AVAsset assetWithURL:[NSURL URLWithString:[self getStreamUrlForIndex:_currentStreamIndex]]];
	
	AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:_asset];
	[item seekToTime:_player.currentTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
	[_player replaceCurrentItemWithPlayerItem:item];
	
}


-(void)play {
	
	if (_player.currentItem) {
		
		[_player play];
		
		if (self.isLive && !seeking && !started) {
			
			[self seekToLive];
		}
	}
}

-(void)pause {
	
	waitForLegalPause = YES;
	[_player pause];
}

-(void)seekToLive {
	
	[self seek:[self getLiveTime] - marginBeforeEnd];
}

-(void)seek:(double)time {
	
	if ( ( ready && !started ) || (seekNotAllowed && time != 0.0) || time < 0 )
		return;
	
	if (!completed && !switching && !seeking) {
		
		waitForResume = _player.rate != 0.0;
		
		seeking = YES;
		
		if (waitForResume)
			[self pause];
		
		[self notify:MAVRPlayerNotificationSeekingStart];
	}
	
	int32_t timeScale = self.isLive ? 1 : _player.currentItem.asset.duration.timescale;
	
	[self handleLiveDuration];

	if ( !self.isLive && _duration > 0 && floor(time) >= floor(_duration - marginBeforeEnd) ) {
		[self handleComplete];
		return;
	}
	
	//accurate
	//[_player seekToTime:CMTimeMakeWithSeconds(time, timeScale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
	//OR
	//fast
	[_player seekToTime:CMTimeMakeWithSeconds(time, timeScale) completionHandler:^(BOOL finished) {
		
		if (finished) {
			
			if (switching) {
				
				switching = NO;
				
				[self notify:MAVRPlayerNotificationSwitchQualityEnd];
				
			} else if (seeking) {
				
				[self notify:MAVRPlayerNotificationSeekingEnd];
			}
			
			if (waitForResume)
				[self play];
			
			seeking = NO;
			
			if ( ( started || completed ) && _state == MAVRPlayerStateCompleted ) {
				
				started = NO;
				[self notify:MAVRPlayerNotificationCompleted];
				
			} else if( started && previousRate == 1.0 ) {
				
				[self notify:MAVRPlayerNotificationPlaying];
				
			}
		}
	}];
}

-(void)stop {
	
	if( !_player.currentItem )
		return;
	
	if (_player.rate != 0.0)
		[self pause];
	
	[_player replaceCurrentItemWithPlayerItem:emptyItem];
	[self resetPlayer];
	
}

#pragma mark internal handlers

-(void)applicationDidBecomeActive:(NSNotification*)notify {
	
	[self externalPlaybackActiveHandler];
	
	if (readdAfterReturnToForeground) {
		
		[_layer setPlayer:_player];
		readdAfterReturnToForeground = NO;
		
	} else {
		
		NSError *activationError = nil;
		[[AVAudioSession sharedInstance] setActive:YES error:&activationError];
		
	}
	
	if (autoPlayAfterReturnToForeground) {
		if( _layer.hidden )
			_layer.hidden = NO;
		[self addBoundaryObservers];
		//[self play];
	}
}

-(void)applicationWillResignActive:(NSNotification*)notify {
	
	[self externalPlaybackActiveHandler];
	
	autoPlayAfterReturnToForeground = ( _player.rate != 0.0 ) && !waitForLegalPause;
	
	if (_player.isExternalPlaybackActive/* && _player.rate != 0.0*/) {
		
		[_layer setPlayer:nil];
		readdAfterReturnToForeground = YES;
		
	} else if(!self.pipActive) {
		
		if (_player.rate != 0.0)
			[self pause];
		
		/*
		 NSError *activationError = nil;
		 [[AVAudioSession sharedInstance] setActive:NO error:&activationError];
		 */
	}
}

-(void)handlePlayToEndTime:(NSNotification*)notify {
	if ([notify object] == _player.currentItem)
		[self handleComplete];
}

-(void)handlePlaybackStalled:(NSNotification*)notify {
	NSLog(@"handlePlaybackStalled");//inet is down
}

-(void)handleFailedToPlayToEndTime:(NSNotification*)notify {
	
	NSLog(@"handleFailedToPlayToEndTime %@", [notify.userInfo valueForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey]);
	started = NO;
}

#pragma mark internal KVO

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	
	void (^KVOBlock)() = ^(NSDictionary* change) {
		if (context == kPlayerItemStatusContext)
			[self statusChanged:[[change valueForKey:@"new"] integerValue]];
		else if (context == kPlayerItemContext)
			[self itemReplaced:[change valueForKey:@"old"] by:[change valueForKey:@"new"]];
		else if (context == kPlayerRateContext) {
			[self rateChanged:_player.rate];
			[self bufferChanged:_player.currentItem.loadedTimeRanges];
		} else if (context == kPlayerBufferChangeContext)
			[self bufferChanged:_player.currentItem.loadedTimeRanges];
		else if (context == kPlayerBufferEmptyContext)
			[self bufferEmptyHandler];
		else if (context == kPlayerBufferFullContext)
			[self bufferFullHandler];
		else if (context == kPlayerExternalPlaybackContext)
			[self externalPlaybackActiveHandler];
		else if (context == kPlayerDurationContext)
			[self handleDuration:CMTimeGetSeconds(_player.currentItem.duration)];
		else if (context == kPlaybackLikelyToKeepUpContext)
			[self playbackLikelyToKeepUpHandler];
	};
	
	if ([NSThread isMainThread])
		KVOBlock(change);
	else
		dispatch_sync(dispatch_get_main_queue(), ^{ KVOBlock(change); });
}

-(void)itemReplaced:(AVPlayerItem*)oldItem by:(AVPlayerItem*)newItem {
	
	if (oldItem && oldItem != (id)[NSNull null]) {
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_STATUS context:kPlayerItemStatusContext];
		} @catch (id anException) {}
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_LOADED_TIME_RANGES context:kPlayerBufferChangeContext];
		} @catch (id anException) {}
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_BUFFER_EMPTY context:kPlayerBufferEmptyContext];
		} @catch (id anException) {}
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_PLAYBACK_LIKELY_KEEP_UP context:kPlaybackLikelyToKeepUpContext];
		} @catch (id anException) {}
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_BUFFER_FULL context:kPlayerBufferFullContext];
		} @catch (id anException) {}
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_PRESENTATION_SIZE context:kPlayerVideoSizeContext];
		} @catch (id anException) {}
		
		@try {
			[oldItem removeObserver:self forKeyPath:kMAVR_DURATION		context:kPlayerDurationContext];
		} @catch (id anException) {}
	}
	
	if (newItem && newItem != (id)[NSNull null]) {
		
		[newItem addObserver:self forKeyPath:kMAVR_STATUS		options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlayerItemStatusContext];
		[newItem addObserver:self forKeyPath:kMAVR_LOADED_TIME_RANGES options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlayerBufferChangeContext];
		[newItem addObserver:self forKeyPath:kMAVR_BUFFER_EMPTY	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlayerBufferEmptyContext];
		[newItem addObserver:self forKeyPath:kMAVR_PLAYBACK_LIKELY_KEEP_UP	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlaybackLikelyToKeepUpContext];
		[newItem addObserver:self forKeyPath:kMAVR_BUFFER_FULL	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlayerBufferFullContext];
		[newItem addObserver:self forKeyPath:kMAVR_PRESENTATION_SIZE	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlayerVideoSizeContext];
		[newItem addObserver:self forKeyPath:kMAVR_DURATION	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:kPlayerDurationContext];
		
	}
}

-(void)rateChanged:(float)newRate {
	
	if( previousRate == newRate ) {
		
		if( waitForLegalPause && previousRate == 0 )
			waitForLegalPause = NO;
		
		return;
	}
	
	
	if (started || completed)
		previousRate = newRate;
	
	if (started && !completed) {
		
		if (newRate == 0.0) {
			
			if (_state == MAVRPlayerStateBuffering)
				[self notify:MAVRPlayerNotificationBufferingEnd];
			
			if (!seeking) {
				
				if ( waitForLegalPause || self.pipActive ) {
					
					waitForLegalPause = NO;
					_state = MAVRPlayerStatePaused;
					
					[self notify:MAVRPlayerNotificationPaused];
					
				} else {
					
					_state = MAVRPlayerStateBuffering;
					
					[self notify:MAVRPlayerNotificationBufferingStart];
					[self play];
				}
			}
			
		} else if (!seeking || _state == MAVRPlayerStateBuffering) {
			
			MAVRPlayerState oldState = _state;
			
			_state = MAVRPlayerStatePlaying;
			
			if (waitForResume) {
				
				waitForResume = NO;
				
			}
			
			if (oldState == MAVRPlayerStateBuffering)
				[self notify:MAVRPlayerNotificationBufferingEnd];
			
			[self notify:MAVRPlayerNotificationPlaying];
			
		}
		
	} else if (!started && newRate == 1.0) {
		
		completed = NO;
		previousRate = newRate;
		[self addBoundaryObservers];
		
	}
}

-(void)playbackLikelyToKeepUpHandler {
	
	if (_player.currentItem) {
		
		if (!_player.currentItem.playbackLikelyToKeepUp && _state == MAVRPlayerStatePlaying) {
			//HACK: We have a problem with playlists, coz real duration slightly different
			
			if ( self.isLive || _duration - _currentTime > /*8.0*/marginBeforeEnd)
				[self startStallTimer];
			else if (!seeking)
				[self handleComplete];
			
		} else if (_player.currentItem.playbackLikelyToKeepUp) {
			
			[self stopStallTimer];
			
			if (_state == MAVRPlayerStateBuffering) {
				
				_state = MAVRPlayerStatePlaying;
				[self notify:MAVRPlayerNotificationBufferingEnd];
			}
		}
	}
}

- (void)stallTimerHandler:(NSTimer *)theTimer {
	
	if (_player.currentItem) {
		
		[self stopStallTimer];
		
		if (seeking)
			[self startStallTimer];
		else if (!_player.currentItem.playbackLikelyToKeepUp)
			[self handleError];
	}
}

-(void)startStallTimer {
	
	if (stallTimer)
		[self stopStallTimer];
	
	stallTimer = [NSTimer scheduledTimerWithTimeInterval:kMAVR_STALL_TIME  target:self selector:@selector(stallTimerHandler:) userInfo:nil repeats:NO];
}

-(void)stopStallTimer {
	
	if (stallTimer) {
		[stallTimer invalidate];
		stallTimer = nil;
	}
}

-(void)statusChanged:(AVPlayerItemStatus)newStatus {
	
	if (waitForComplete) {
		
		waitForComplete = NO;
		[self handleComplete];
		return;
	}
	
	if (newStatus == AVPlayerItemStatusFailed) {
		
		[self handleError];
		
	} else if (newStatus == AVPlayerItemStatusReadyToPlay) {
		
		if (!seeking && !started && !completed) {
			
			if (_player.currentItem) {
				
				_currentTime = CMTimeGetSeconds(_player.currentItem.currentTime);

				[self handleDuration:CMTimeGetSeconds(_asset.duration)];
				
				_isLive = isnan(_duration);
				
				[self handleLiveDuration];
			}
			
			if (!ready) {
				[self handleReady];
			}
			
		} else if (completed) {
			
			started = NO;
			
		} else if (switching) {
			
			switching = NO;
			[self notify:MAVRPlayerNotificationSwitchQualityEnd];
			
		} else if (started && waitForResume && _state == MAVRPlayerStateBuffering) {
			
			[self notify:MAVRPlayerNotificationBufferingEnd];
		}
	}
}

-(void)bufferChanged:(NSArray*)timeRanges {
	
	if (timeRanges && timeRanges.count > 0) {
		
		CMTimeRange range = [timeRanges.lastObject CMTimeRangeValue];
		_bufferRange = CGSizeMake(CMTimeGetSeconds(range.start), CMTimeGetSeconds(range.duration));
		if (_duration != 0.0 && !completed && _state != MAVRPlayerStateCompleted)
			[self notify:MAVRPlayerNotificationBufferChange];
	}
}

-(void)bufferEmptyHandler {
	
	_bufferRange = CGSizeMake(0, 0);
	
	if (_state == MAVRPlayerStatePlaying) {
		
		_state = MAVRPlayerStateBuffering;
		[self notify:MAVRPlayerNotificationBufferingStart];
	}
}

-(void)externalPlaybackActiveHandler {
	
	if (_isExternalPlayback != _player.isExternalPlaybackActive) {
		
		_isExternalPlayback = _player.externalPlaybackActive;
		
		if (!_isExternalPlayback && ![_layer player])
			[_layer setPlayer:_player];
		
		[self notify:MAVRPlayerNotificationExternalPlaybackActive];
	}
}

-(CGFloat)getLiveTime {
	
	NSArray *seekableTimeRanges = _player.currentItem.seekableTimeRanges;
	
	CMTimeRange timeRange = [seekableTimeRanges.lastObject CMTimeRangeValue];
	
	CGFloat seekableStart = CMTimeGetSeconds(timeRange.start);
	CGFloat seekableDuration = CMTimeGetSeconds(timeRange.duration);
	CGFloat livetime = seekableStart + seekableDuration;
	return livetime;
}

-(void)bufferFullHandler {
	//NSLog(@"bufferFullHandler %@ %@", [self getFlagsString], [self stringifyState:_state]);
	if (_state == MAVRPlayerStateBuffering && !switching) {
		
		_state = MAVRPlayerStatePlaying;
		
		[self notify:MAVRPlayerNotificationBufferingEnd];
	}
}

#pragma mark internal API

-(void)notify:(MAVRPlayerNotificationType)notificationType {
	
	//NSLog(@"playernotification %@ %@", [self stringifyNotification:notificationType], [self stringifyState:_state]);
	
	NSMutableArray *handlersForNotification = [registeredHandlers objectForKey:[NSNumber numberWithInt:notificationType]];
	
	if (handlersForNotification && [handlersForNotification count] > 0) {
		
		if ([NSThread isMainThread])
			[self callHandlers:handlersForNotification forType:notificationType];
		else
			dispatch_sync(dispatch_get_main_queue(), ^{[self callHandlers:handlersForNotification forType:notificationType];});
	}
}

-(void)callHandlers:(NSMutableArray*)blocks forType:(MAVRPlayerNotificationType)type {
	
	for (id func in blocks) {
		
		((MAVRPlayerBlockHandler)func)(self, type);
	}
}

-(void)addBoundaryObservers {
	
	[self removeBoundaryObservers];
	
	MAVRPlayer* __weak wself = self;
	
	void (^startedBlock)() = ^() {
		
		MAVRPlayer *sself = wself;
		
		if (sself) {
			
			[sself removeStartObserver];
			
			if( !sself->started ) {
				
				sself->started = YES;
				sself->seekNotAllowed = NO;
				sself->_state = MAVRPlayerStatePlaying;
				[sself notify:MAVRPlayerNotificationStarted];
				
			}
			
		}
	};
	
	void (^currentTimeBlock)() = ^(CMTime time) {
		
		MAVRPlayer* sself = wself;
		double newTime = CMTimeGetSeconds(time);
		
		[sself handleLiveDuration];

		if (sself->_duration > 0 && sself->_duration - newTime <= sself->marginBeforeEnd && !sself->completed && !self.isLive) {
			
			if (!seeking)
				[sself handleComplete];
			else
				waitForComplete = YES;
			
		} else if (!sself->switching && newTime != sself->_currentTime) {
			
			sself->_currentTime = CMTimeGetSeconds(time);
			
			if (sself->started && sself->_state != MAVRPlayerStatePaused && !sself->seeking && !sself->completed){
				[sself notify:MAVRPlayerNotificationCurrentTimeChange];
				[sself notify:MAVRPlayerNotificationBufferChange];
			}
		}
	};
	
	observerCurrentTime = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.1, NSEC_PER_SEC) queue:nil usingBlock:currentTimeBlock];
	
	UIApplicationState state = [[UIApplication sharedApplication] applicationState];
	
	if (state == UIApplicationStateBackground || state == UIApplicationStateInactive) {
		seekNotAllowed = NO;
		autoPlayAfterReturnToForeground = YES;
	} else {
		observerStart = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:startedBlock];
	}
	
}

-(void)removeBoundaryObservers {
	
	[self removeCurrentTimeObserver];
	[self removeStartObserver];
}

-(void)removeCurrentTimeObserver {
	
	if (observerCurrentTime != nil) {
		
		@try { [_player removeTimeObserver:observerCurrentTime];}
		
		@catch (id anException) {}
		
		observerCurrentTime = nil;
	}
}

-(void)removeStartObserver {
	
	if (observerStart != nil) {
		
		@try { [_player removeTimeObserver:observerStart];}
		
		@catch (id anException) {}
		
		observerStart = nil;
	}
}

-(void)handleReady {
	
	[self addBoundaryObservers];
	
	_state = MAVRPlayerStateReady;
	
	ready = YES;
	
	[self notify:MAVRPlayerNotificationReady];
}

-(void)handleComplete {
	
	if( completed )
		return;
	
	[self removeBoundaryObservers];
	[self stopStallTimer];
	
	if (_state == MAVRPlayerStateBuffering)
		[self notify:MAVRPlayerNotificationBufferingEnd];
	
	completed = YES;
	
	if (seeking) {
		
		seeking = NO;
		[self notify:MAVRPlayerNotificationSeekingEnd];
	}
	
	waitForResume = NO;
	ready = NO;
	
	_currentTime = 0;
	_bufferRange = CGSizeMake(0, 0);
	_state = MAVRPlayerStateCompleted;
	
	if (started)
		[self pause];
	
	seekNotAllowed = YES;
	[self seek:0.0];
}

-(void)handleLiveDuration {
	
	if (self.isLive) {
		
		[self handleDuration:[self getLiveTime]];
	}
}

-(void)handleDuration:(CGFloat)newValue {
	
	if (newValue != _duration) {
		
		_duration = newValue;

		[self notify:MAVRPlayerNotificationDurationChange];
	}
}

-(void)handleError {
	
	if (_state == MAVRPlayerStateBuffering)
		[self notify:MAVRPlayerNotificationBufferingEnd];
	
	_state = MAVRPlayerStateError;
	[self notify:MAVRPlayerNotificationError];
}

#pragma mark M3U8 methods

-(NSString*)getStreamUrlForIndex:(NSUInteger)index {
	
	if (self.streamsCount == 0)
		return nil;
	
	if (self.streamsCount < index)
		index = self.streamsCount - 1;
	
	
	M3U8ExtXStreamInf* streamInfo = [_playlist.xStreamList xStreamInfAtIndex:index];
	
	return [streamInfo URI];
	
}

-(void)setIsZoomed:(BOOL)zoomed {
	_layer.videoGravity = zoomed ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResizeAspect;
}

-(BOOL)getIsZoomed {
	return _layer.videoGravity == AVLayerVideoGravityResizeAspectFill;
}

-(NSUInteger)streamsCount {
	
	if (!_playlist)
		return 0;
	
	return _playlist.xStreamList.count;
}

-(NSString*)lowestQualityUrl {
	
	return [self getStreamUrlForIndex:0];
}


#pragma mark Debug methods

-(NSString*)stringifyState:(MAVRPlayerState)state {
	NSString* s = @"";
	switch (state) {
		case MAVRPlayerStateBuffering:
			s = @"MAVRPlayerStateBuffering";
			break;
		case MAVRPlayerStateError:
			s = @"MAVRPlayerStateError";
			break;
		case MAVRPlayerStateCompleted:
			s = @"MAVRPlayerStateCompleted";
			break;
		case MAVRPlayerStateLoading:
			s = @"MAVRPlayerStateLoading";
			break;
		case MAVRPlayerStatePaused:
			s = @"MAVRPlayerStatePaused";
			break;
		case MAVRPlayerStatePlaying:
			s = @"MAVRPlayerStatePlaying";
			break;
		case MAVRPlayerStateReady:
			s = @"MAVRPlayerStateReady";
			break;
			
		default:
			break;
	}
	return s;
}

-(NSString*)stringifyNotification:(MAVRPlayerNotificationType)notification {
	NSString* s = @"";
	switch (notification) {
		case MAVRPlayerNotificationBufferChange:
			s = @"MAVRPlayerNotificationBufferChange ";
			s = [s stringByAppendingString:NSStringFromCGSize(_bufferRange)];
			break;
		case MAVRPlayerNotificationBufferingEnd:
			s = @"MAVRPlayerNotificationBufferingEnd";
			break;
		case MAVRPlayerNotificationBufferingStart:
			s = @"MAVRPlayerNotificationBufferingStart";
			break;
		case MAVRPlayerNotificationCompleted:
			s = @"MAVRPlayerNotificationCompleted";
			break;
		case MAVRPlayerNotificationCurrentTimeChange:
			s = @"MAVRPlayerNotificationCurrentTimeChange ";
			s = [s stringByAppendingString:[[NSNumber numberWithDouble:_currentTime] stringValue]];
			break;
		case MAVRPlayerNotificationDurationChange:
			s = @"MAVRPlayerNotificationDurationChange ";
			s = [s stringByAppendingString:[[NSNumber numberWithDouble:_duration] stringValue]];
			break;
		case MAVRPlayerNotificationError:
			s = @"MAVRPlayerNotificationError";
			break;
		case MAVRPlayerNotificationExternalPlaybackActive:
			s = @"MAVRPlayerNotificationExternalPlaybackActive";
			break;
		case MAVRPlayerNotificationLoading:
			s = @"MAVRPlayerNotificationLoading";
			break;
		case MAVRPlayerNotificationPaused:
			s = @"MAVRPlayerNotificationPaused";
			break;
		case MAVRPlayerNotificationPlaying:
			s = @"MAVRPlayerNotificationPlaying";
			break;
		case MAVRPlayerNotificationReady:
			s = @"MAVRPlayerNotificationReady";
			break;
		case MAVRPlayerNotificationStarted:
			s = @"MAVRPlayerNotificationStarted";
			break;
		case MAVRPlayerNotificationSwitchQualityEnd:
			s = @"MAVRPlayerNotificationSwitchQualityEnd";
			break;
		case MAVRPlayerNotificationSwitchQualityStart:
			s = @"MAVRPlayerNotificationSwitchQualityStart";
			break;
		case MAVRPlayerNotificationVideoSizeChange:
			s = @"MAVRPlayerNotificationVideoSizeChange";
			break;
		case MAVRPlayerNotificationSeekingEnd:
			s = @"MAVRPlayerNotificationSeekingEnd";
			break;
		case MAVRPlayerNotificationSeekingStart:
			s = @"MAVRPlayerNotificationSeekingStart";
			break;
			
		default:
			break;
	}
	return s;
}

-(NSString*)getFlagsString {
	return [NSString stringWithFormat:@"ready=%@ started=%@ completed=%@ seeking=%@ waitForResume=%@ switching=%@ waitForComplete=%@",
			[[NSNumber numberWithBool:ready] stringValue],
			[[NSNumber numberWithBool:started] stringValue],
			[[NSNumber numberWithBool:completed] stringValue],
			[[NSNumber numberWithBool:seeking] stringValue],
			[[NSNumber numberWithBool:waitForResume] stringValue],
			[[NSNumber numberWithBool:switching] stringValue],
			[[NSNumber numberWithBool:waitForComplete] stringValue]
			];
}

-(NSString*)stringifyAVPlayerItemStatus:(AVPlayerItemStatus)status {
	NSString* s = @"";
	switch (status) {
		case AVPlayerItemStatusFailed: {
			
			s = @"AVPlayerItemStatusFailed";
			break;
		}
		case AVPlayerItemStatusReadyToPlay: {
			
			s = @"AVPlayerItemStatusReadyToPlay";
			break;
		}
		case AVPlayerItemStatusUnknown: {
			
			s = @"AVPlayerItemStatusUnknown";
			break;
		}
	}
	return s;
}

#pragma mark - Pip delegate

-(BOOL) pipActive {
	
#if TARGET_OS_TV
	return NO;
#else
	return _pipController && _pipController.isPictureInPictureActive;
#endif
	
}

-(BOOL) pipAvailable {
#if TARGET_OS_TV
	return NO;
#else
	return [AVPictureInPictureController isPictureInPictureSupported];
#endif
	
}

-(BOOL)startPictureInPicture {
#if TARGET_OS_TV
	return NO;
#else
	if( _pipController.isPictureInPicturePossible && !_pipController.isPictureInPictureActive) {
		[_pipController startPictureInPicture];
		return YES;
	}
	
	return NO;
#endif
	
	
}

-(BOOL)stopPictureInPicture {
#if TARGET_OS_TV
	return NO;
#else
	if( _pipController.isPictureInPictureActive ) {
		[_pipController stopPictureInPicture];
		return YES;
	}
	
	return NO;
#endif
	
	
}

#ifndef TARGET_OS_TV

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
	
	UIApplicationState state = [[UIApplication sharedApplication] applicationState];
	
	if ( ( pictureInPictureController.isPictureInPictureSuspended || !pictureInPictureController.isPictureInPictureActive ) &&
		( state == UIApplicationStateBackground || state == UIApplicationStateInactive ) )
	{
		autoPlayAfterReturnToForeground = NO;
		[self pause];
	}
	
	
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
	
	_layer.zPosition = 1;
	
	completionHandler(YES);
	
}
#endif


@end
