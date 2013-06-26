//
//  VideoProcessor.h
//  FixMPEG
//
//  Created by Scott Jann on 6/25/13.
//  Copyright (c) 2013 trms.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum OutputVideoFormat
{
	copyVideo,
	mpeg2,
	mpeg4,
	h264,
	flv,
	wm7,
	wm9
}
OutputVideoFormat;

typedef enum OutputAudioFormat
{
	copyAudio,
	mp2,
	mp3
}
OutputAudioFormat;

typedef void (^ProgressBlock)(double progress);
typedef void (^ErrorBlock)(NSError *error);

@interface VideoProcessor : NSObject

-(VideoProcessor*)initWithFile:(NSString*)path;
-(void)loadInformation;
-(void)transcode:(NSString*)output videoFormat:(OutputVideoFormat)videoFormat audioFormat:(OutputAudioFormat)audioFormat bitrate:(NSInteger)bitrate;

@property () NSString *path;
@property () NSString *video;
@property () NSString *audio;
@property (assign) NSInteger width;
@property (assign) NSInteger height;
@property (assign) NSInteger audioRate;
@property () NSString *audioChannels;
@property (assign) double frameRate;
@property (strong) ProgressBlock callback;
@property (strong) ErrorBlock errorCallback;

@end
