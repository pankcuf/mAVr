//
//  MAVRPlayer.m
//  mAVr
//
//  Created by Vladimir Pirogov on 14/02/15.
//  Copyright (c) 2015 Vladimir Pirogov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAudioSession.h>
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

@interface MAVRPlayer() <MAVRPlayerDelegate, AVAudioPlayerDelegate>
-(void)notify:(MAVRPlayerNotificationType)notificationType;
-(void)callHandlers:(NSMutableArray*)blocks forType:(MAVRPlayerNotificationType)type;
-(void)bufferFullHandler;
-(void)bufferEmptyHandler;
-(void)playbackLikelyToKeepUpHandler;
-(void)durationChangeHandler;
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
-(void)removeEndObserver;
-(void)handleReady;
-(void)handleComplete;

#pragma mark M3U8 methods
-(NSString*)getStreamUrlForIndex:(NSUInteger)index;

#pragma mark Debug methods
-(NSString*)stringifyState:(MAVRPlayerState)state;
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
	
	id observerCurrentTime;
	id observerStart;
	id observerEnd;
	
	BOOL started;
	BOOL completed;
	BOOL seeking;
	BOOL waitForResume;
	BOOL waitForComplete;
	BOOL switching;
	BOOL readdAfterReturnToForeground;
	BOOL ready;
	
	double seekToTime;
	double marginBeforeEnd;
}

#pragma mark lifecycle

-(id)initWithView:(UIView*)parent {
	self = [super init];
	
	if (self) {
		started = switching = seeking = completed = waitForResume = waitForComplete = ready = NO;
		
		marginBeforeEnd = 0.6;
		
		registeredHandlers = [NSMutableDictionary dictionaryWithCapacity:1];
		
		_player = [[AVPlayer alloc] init];
		_player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
		_layer = [AVPlayerLayer playerLayerWithPlayer:_player];
		_layer.frame = parent.bounds;
		_layer.videoGravity = AVLayerVideoGravityResizeAspect;
		[parent.layer addSublayer:_layer];
		
		NSNotificationCenter* dispatcher = [NSNotificationCenter defaultCenter];
		
		[dispatcher addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
		[dispatcher addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		//[dispatcher addObserver:self selector:@selector(handlePlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
		[dispatcher addObserver:self selector:@selector(handleFailedToPlayToEndTime:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player];
		[dispatcher addObserver:self selector:@selector(handlePlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:_player];
		
		NSError *setCategoryError = nil;
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error: &setCategoryError];
		
		[_player addObserver:self forKeyPath:kMAVR_CURRENT_ITEM	options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:kPlayerItemContext];
		[_player addObserver:self forKeyPath:kMAVR_RATE			options:NSKeyValueObservingOptionNew	context:kPlayerRateContext];
		[_player addObserver:self forKeyPath:kMAVR_EXTERNAL_PLAYBACK_ACTIVE options:NSKeyValueObservingOptionNew context:kPlayerExternalPlaybackContext];
	}

	return self;
}

-(void)setFrame:(CGRect)frame {
	
	_layer.frame = frame;
}

-(void)resetPlayer {
	
	if (_player.currentItem) {
		
		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_STATUS context:kPlayerItemStatusContext];
		} @catch (id anException) {}
		
		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_LOADED_TIME_RANGES context:kPlayerBufferChangeContext];
		} @catch (id anException) {}
		
		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_BUFFER_EMPTY context:kPlayerBufferEmptyContext];
		} @catch (id anException) {}
		
		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_PLAYBACK_LIKELY_KEEP_UP context:kPlaybackLikelyToKeepUpContext];
		} @catch (id anException) {}

		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_BUFFER_FULL context:kPlayerBufferFullContext];
		} @catch (id anException) {}
		
		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_PRESENTATION_SIZE context:kPlayerVideoSizeContext];
		} @catch (id anException) {}
		
		@try {
			[_player.currentItem removeObserver:self forKeyPath:kMAVR_DURATION context:kPlayerDurationContext];
		} @catch (id anException) {}
	}
	
	[self removeBoundaryObservers];
	
	_currentStreamIndex = 0;
	_playlist = nil;
	started = NO;
	completed = NO;
}


-(void)dealloc {
	
	registeredHandlers = nil;
	
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
	
	[self notify:MAVRPlayerNotificationLoading];
	
	_asset = [AVAsset assetWithURL:[NSURL URLWithString:url]];
	
	AVPlayerItem* item = [[AVPlayerItem alloc] initWithAsset:_asset];
	
	[_player replaceCurrentItemWithPlayerItem:item];
}

-(void)loadWithContent:(NSString *)content {
	
	_currentStreamIndex = 0;
	
	ready = NO;
	
	_playlist = [[M3U8MasterPlaylist alloc] initWithContent:content baseURL:nil];
	
	if (self.streamsCount <= 0) {
		
		_state = MAVRPlayerStateError;

		[self notify:MAVRPlayerNotificationError];
		
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
	
	[_player replaceCurrentItemWithPlayerItem:item];
}


-(void)play {

	_player.rate = 1.0;
}

-(void)pause {

	_player.rate = 0.0;
}

-(void)seek:(double)time {
	
	if (ready && !started)
		return;
	
	if (!completed && !switching && !seeking) {
		
		waitForResume = _player.rate != 0.0;
		
		seeking = YES;

		if (waitForResume)
			[self pause];
		
		[self notify:MAVRPlayerNotificationSeekingStart];
	}
	
	int32_t timeScale = _player.currentItem.asset.duration.timescale;
	
	if (time >= _duration - marginBeforeEnd) {
		
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
			
			if (_state == MAVRPlayerStateCompleted)
				started = NO;
		}
	}];
}

-(void)stop {
	
	if (_player.rate != 0.0)
		_player.rate = 0.0;

	[_player replaceCurrentItemWithPlayerItem:nil];
	
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
}

-(void)applicationWillResignActive:(NSNotification*)notify {

	[self externalPlaybackActiveHandler];

	if (_player.isExternalPlaybackActive/* && _player.rate != 0.0*/) {
		
		[_layer setPlayer:nil];
		readdAfterReturnToForeground = YES;
	
	} else {

		NSError *activationError = nil;
		if (_player.rate != 0.0)
			[self pause];
		[[AVAudioSession sharedInstance] setActive:NO error:&activationError];
	}
}

/*-(void)handlePlayToEndTime:(NSNotification*)notify {
	NSLog(@"handlePlayToEndTime");
	completed = YES;
	
	_state = MAVRPlayerStateCompleted;

	[self notify:MAVRPlayerNotificationCompleted];
}*/

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
		else if (context == kPlayerRateContext)
			[self rateChanged:_player.rate];
		else if (context == kPlayerBufferChangeContext)
			[self bufferChanged:_player.currentItem.loadedTimeRanges];
		else if (context == kPlayerBufferEmptyContext)
			[self bufferEmptyHandler];
		else if (context == kPlayerBufferFullContext)
			[self bufferFullHandler];
		else if (context == kPlayerExternalPlaybackContext)
			[self externalPlaybackActiveHandler];
		else if (context == kPlayerDurationContext)
			[self durationChangeHandler];
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
		
		[oldItem removeObserver:self forKeyPath:kMAVR_STATUS		context:kPlayerItemStatusContext];
		[oldItem removeObserver:self forKeyPath:kMAVR_LOADED_TIME_RANGES context:kPlayerBufferChangeContext];
		[oldItem removeObserver:self forKeyPath:kMAVR_BUFFER_EMPTY context:kPlayerBufferEmptyContext];
		[oldItem removeObserver:self forKeyPath:kMAVR_PLAYBACK_LIKELY_KEEP_UP context:kPlaybackLikelyToKeepUpContext];
		[oldItem removeObserver:self forKeyPath:kMAVR_BUFFER_FULL context:kPlayerBufferFullContext];
		[oldItem removeObserver:self forKeyPath:kMAVR_PRESENTATION_SIZE context:kPlayerVideoSizeContext];
		[oldItem removeObserver:self forKeyPath:kMAVR_DURATION		context:kPlayerDurationContext];
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

	if (started && !completed) {
		
		if (newRate == 0.0) {
			
			if (_state == MAVRPlayerStateBuffering)
				[self notify:MAVRPlayerNotificationBufferingEnd];
			
			if (!seeking) {
				
				_state = MAVRPlayerStatePaused;
			
				[self notify:MAVRPlayerNotificationPaused];
			}
			
		} else if (!seeking) {
			
			MAVRPlayerState oldState = _state;
			
			_state = MAVRPlayerStatePlaying;
			
			if (waitForResume) {
				
				waitForResume = NO;
				
				if (oldState == MAVRPlayerStateBuffering)
					[self notify:MAVRPlayerNotificationBufferingEnd];
			}
			
			[self notify:MAVRPlayerNotificationPlaying];
		}
		
	} else if (!started && completed) {
		
		if (newRate == 1.0) {
			
			completed = NO;
			[self addBoundaryObservers];
		}
	}
}

-(void)playbackLikelyToKeepUpHandler {

	if (_player.currentItem && !_player.currentItem.playbackLikelyToKeepUp && _state == MAVRPlayerStatePlaying)
		[self notify:MAVRPlayerNotificationError];
}

-(void)statusChanged:(AVPlayerItemStatus)newStatus {
	//NSLog(@"statusChanged %@ %@ %@", [self stringifyAVPlayerItemStatus:newStatus], [self getFlagsString], [self stringifyState:_state]);
	if (waitForComplete) {
		
		waitForComplete = NO;
		[self handleComplete];
		return;
	}
	
	if (newStatus == AVPlayerItemStatusFailed) {
		
		_state = MAVRPlayerStateError;
		[self notify:MAVRPlayerNotificationError];
		
	} else if (newStatus == AVPlayerItemStatusReadyToPlay) {

		if (!seeking && !started && !completed) {
			
			if (_player.currentItem) {
					
				_currentTime = CMTimeGetSeconds(_player.currentItem.currentTime);
				_duration = CMTimeGetSeconds(_asset.duration);
			}
				
			if (!ready) {
				[self handleReady];
			}
		
		} else if (completed) {
			
			started = NO;
			//completed = NO;
			
			//[self handleReady];
			
		} else if (switching) {
			
			[self seek:seekToTime];
			
		} else if (started && waitForResume && _state == MAVRPlayerStateBuffering) {
			
			[self notify:MAVRPlayerNotificationBufferingEnd];
		}
	}
}

-(void)bufferChanged:(NSArray*)timeRanges {
	
	if (timeRanges && timeRanges.count > 0) {
		
		CMTimeRange range;
		[timeRanges.lastObject getValue:&range];

		_bufferTime = MAX(0, CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration) - _currentTime);
		
		if (_duration != 0.0 && !completed && _state != MAVRPlayerStateCompleted)
			[self notify:MAVRPlayerNotificationBufferChange];
	}
}

-(void)bufferEmptyHandler {

	_bufferTime = 0;

	if (_state == MAVRPlayerStatePlaying) {

		_state = MAVRPlayerStateBuffering;
		[self notify:MAVRPlayerNotificationBufferingStart];
	}
}

-(void)externalPlaybackActiveHandler {

	if (_isExternalPlayback != _player.isExternalPlaybackActive) {

		_isExternalPlayback = _player.externalPlaybackActive;
		[self notify:MAVRPlayerNotificationExternalPlaybackActive];
	}
}

-(void)durationChangeHandler {
	
	_duration = CMTimeGetSeconds(_player.currentItem.duration);
}

-(void)bufferFullHandler {
	
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
			sself->started = YES;
			sself->_state = MAVRPlayerStatePlaying;
			[sself notify:MAVRPlayerNotificationStarted];
		}
	};
	
	void (^endedBlock)() = ^() {
		
		MAVRPlayer *sself = wself;
		
		if (sself)
			[sself handleComplete];
	};
	
	void (^currentTimeBlock)() = ^(CMTime time) {
		
		MAVRPlayer* sself = wself;
		double newTime = CMTimeGetSeconds(time);

		if (sself->_duration > 0 && sself->_duration - sself->_currentTime <= sself->marginBeforeEnd && !sself->completed) {
			
			if (!seeking)
				[sself handleComplete];
			else
				waitForComplete = YES;
			
		} else if (!sself->switching && newTime != sself->_currentTime) {
			
			sself->_currentTime = CMTimeGetSeconds(time);
			
			if (sself->started && sself->_state != MAVRPlayerStatePaused && !sself->seeking && !sself->completed)
				[sself notify:MAVRPlayerNotificationCurrentTimeChange];
		}
	};

	observerCurrentTime = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, NSEC_PER_SEC) queue:nil usingBlock:currentTimeBlock];
	observerStart = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:CMTimeMake(1, 3)]] queue:nil usingBlock:startedBlock];
	observerEnd = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:CMTimeMakeWithSeconds(_duration - marginBeforeEnd, 1.0)]] queue:nil usingBlock:endedBlock];
}

-(void)removeBoundaryObservers {

	[self removeCurrentTimeObserver];
	[self removeStartObserver];
	[self removeEndObserver];
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

-(void)removeEndObserver {
	
	if (observerEnd != nil) {
		
		@try { [_player removeTimeObserver:observerEnd];}
		
		@catch (id anException) {}
		
		observerEnd = nil;
	}
}

-(void)handleReady {
	
	[self addBoundaryObservers];
	
	_state = MAVRPlayerStateReady;
	
	ready = YES;
	
	[self notify:MAVRPlayerNotificationReady];
}

-(void)handleComplete {
	//NSLog(@"handleComplete %@", [self getFlagsString]);
	[self removeBoundaryObservers];

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
	_bufferTime = 0;
	_state = MAVRPlayerStateCompleted;
	
	[self notify:MAVRPlayerNotificationCompleted];
	
	if (started)
		[self pause];
	
	[self seek:0];
}


#pragma mark M3U8 methods

-(NSString*)getStreamUrlForIndex:(NSUInteger)index {
	
	if (self.streamsCount == 0)
		return nil;
	
	if (self.streamsCount < index)
		index = self.streamsCount - 1;
	
	M3U8ExtXStreamInf* streamInfo = [_playlist.xStreamList extXStreamInfAtIndex:index];
	
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
			s = [s stringByAppendingString:[[NSNumber numberWithDouble:_bufferTime] stringValue]];
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
	NSString* s = @"started=";
	s = [s stringByAppendingString:[[NSNumber numberWithBool:started] stringValue]];
	s = [s stringByAppendingString:@" ready="];
	s = [s stringByAppendingString:[[NSNumber numberWithBool:ready] stringValue]];
	s = [s stringByAppendingString:@" completed="];
	s = [s stringByAppendingString:[[NSNumber numberWithBool:completed] stringValue]];
	s = [s stringByAppendingString:@" seeking="];
	s = [s stringByAppendingString:[[NSNumber numberWithBool:seeking] stringValue]];
	s = [s stringByAppendingString:@" waitForResume="];
	s = [s stringByAppendingString:[[NSNumber numberWithBool:waitForResume] stringValue]];
	s = [s stringByAppendingString:@" switching="];
	s = [s stringByAppendingString:[[NSNumber numberWithBool:switching] stringValue]];
	s = [s stringByAppendingString:@" waitForComplete="];
	s = [s stringByAppendingString:[[NSNumber numberWithBool:waitForComplete] stringValue]];
	
	return s;
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
@end
