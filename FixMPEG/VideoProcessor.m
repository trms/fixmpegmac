//
//  VideoProcessor.m
//  FixMPEG
//
//  Created by Scott Jann on 6/25/13.
//  Copyright (c) 2013 trms.com. All rights reserved.
//

#import "VideoProcessor.h"

@implementation VideoProcessor

- (id)init {
	if(self = [super init]) {
		[self setPath:@""];
		[self setVideo:@""];
		[self setAudio:@""];
		[self setWidth:0];
		[self setHeight:0];
		[self setAudioRate:0];
		[self setAudioChannels:0];
		[self setFrameRate:0.0];
		[self setCallback:nil];
		[self setErrorCallback:nil];
	}
	return self;
}

- (VideoProcessor*)initWithFile:(NSString *)path {
	if(self = [self init]) {
		[self setPath:path];
	}
	return self;
}

// the system library won't break at a \r, so here's
// my own implementation of fgets() that will
char *fgetl(char *buf, int bsize, FILE *fp) {
	int i, c, done = 0;
	if (buf == 0 || bsize <= 0 || fp == 0)
		return 0;
	for (i = 0; !done && i < bsize - 1; i++) {
		c = fgetc(fp);
		if (feof(fp)) {
			done = 1;
			i--;
		} else {
			buf[i] = c;
			if (c == '\n' || c == '\r')
				done = 1;
		}
	}
	buf[i] = '\0';
	if (i == 0)
		return 0;
	else
		return buf;
}

- (void)runFFMPEG:(NSString*)args {
	NSString *ffmpeg = [[NSBundle mainBundle] pathForResource:@"ffmpeg" ofType:@""];
	NSString *command = [NSString stringWithFormat:@"%@ %@", ffmpeg, args];
	NSError *error = nil;
	NSRegularExpression *durationRegex = [NSRegularExpression regularExpressionWithPattern:@"Duration:\\s+(\\d+):(\\d+):(\\d+)\\.(\\d+)" options:0 error:&error];
	if(error) {
		if([self errorCallback])
			[self errorCallback](error);
		return;
	}
	NSRegularExpression *frameRegex = [NSRegularExpression regularExpressionWithPattern:@"frame=\\s+(\\d+)" options:0 error:&error];
	if(error) {
		if([self errorCallback])
			[self errorCallback](error);
		return;
	}
	NSRegularExpression *videoARegex = [NSRegularExpression regularExpressionWithPattern:@"Video: ([^,\\s]*)\\s*[^,]*, [^,]*, (\\d+)x(\\d+)" options:0 error:&error];
	if(error) {
		if([self errorCallback])
			[self errorCallback](error);
		return;
	}
	NSRegularExpression *videoBRegex = [NSRegularExpression regularExpressionWithPattern:@"Video: ([^,]*), (\\d+)x(\\d+)" options:0 error:&error];
	if(error) {
		if([self errorCallback])
			[self errorCallback](error);
		return;
	}
	NSRegularExpression *frameRateRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\d+\\.\\d+)\\s+fps" options:0 error:&error];
	if(error) {
		if([self errorCallback])
			[self errorCallback](error);
		return;
	}
	NSRegularExpression *audioRegex = [NSRegularExpression regularExpressionWithPattern:@"Audio: ([^,]*), ([^\\s]*)\\s\\w*, ([^,\\r\\n]*)" options:0 error:&error];
	if(error) {
		if([self errorCallback])
			[self errorCallback](error);
		return;
	}

	int outfd[2];
	int infd[2];
	pipe(outfd); /* Where the parent is going to write to */
	pipe(infd); /* From where parent is going to read */
	
	if(!fork())
	{
		close(STDOUT_FILENO);
		close(STDIN_FILENO);
		dup2(outfd[0], STDIN_FILENO);
		dup2(infd[1], STDOUT_FILENO);
		dup2(infd[1], STDERR_FILENO);
		close(outfd[0]); /* Not required for the child */
		close(outfd[1]);
		close(infd[0]);
		close(infd[1]);
		
		system([command UTF8String]);
	}
	else
	{
		close(outfd[0]); /* These are being used by the child */
		close(infd[1]);
		
		char buf[1024];
		NSInteger totalFrames = 0;
		FILE *f = fdopen(infd[0], "r");

		while(fgetl(buf, sizeof(buf), f)) {
			NSString *buffer = [NSString stringWithUTF8String:buf];
			if([buffer rangeOfString:@"format is not supported" options:NSCaseInsensitiveSearch].location != NSNotFound || [buffer rangeOfString:@"could not find codec parameters" options:NSCaseInsensitiveSearch].location != NSNotFound || [buffer rangeOfString:@"unknown format" options:NSCaseInsensitiveSearch].location != NSNotFound || [buffer rangeOfString:@"invalid data" options:NSCaseInsensitiveSearch].location != NSNotFound) {
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not a recognized file format: %@", [[self path] lastPathComponent]] forKey:NSLocalizedDescriptionKey];
				NSError *error = [NSError errorWithDomain:@"FFMPEG" code:-1 userInfo:errorInfo];
				if([self errorCallback])
					[self errorCallback](error);
				break;
			}
			
			/*
			 Input #0, mpeg, from 'file.mpg':
			 Duration: 00:01:01.0, start: 1.186233, bitrate: 11788 kb/s
			 Stream #0.0[0x1e0]: Video: mpeg2video, yuv420p, 1280x720 [PAR 1:1 DAR 16:9],
			 12877 kb/s, 59.94 tb(r)
			 Stream #0.1[0x80]: Audio: liba52, 48000 Hz, stereo, 384 kb/s
			 */
			
			if(totalFrames == 0) {
				NSTextCheckingResult *match = [durationRegex firstMatchInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
				if(match && [match numberOfRanges] == 5) {
					NSInteger hours = [[buffer substringWithRange:[match rangeAtIndex:1]] integerValue];
					NSInteger minutes = [[buffer substringWithRange:[match rangeAtIndex:2]] integerValue];
					NSInteger seconds = [[buffer substringWithRange:[match rangeAtIndex:3]] integerValue];
					NSInteger frames = [[buffer substringWithRange:[match rangeAtIndex:4]] integerValue];
					double total = hours * 3600.0;
					total += minutes * 60.0;
					total += seconds;
					total *= 29.97;
					total += frames;
					totalFrames = (NSInteger)total;
				}
			}

			NSTextCheckingResult *match = [frameRegex firstMatchInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
			if(totalFrames > 0 && match && [match numberOfRanges] == 2) {
				double progress = [[buffer substringWithRange:[match rangeAtIndex:1]] doubleValue];
				if([self callback])
					[self callback](progress / totalFrames);
			}

			match = [videoARegex firstMatchInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
			if(match == nil || [match numberOfRanges] != 4)
				match = [videoBRegex firstMatchInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
			if(match && [match numberOfRanges] == 4) {
				[self setVideo:[buffer substringWithRange:[match rangeAtIndex:1]]];
				[self setWidth:[[buffer substringWithRange:[match rangeAtIndex:2]] integerValue]];
				[self setHeight:[[buffer substringWithRange:[match rangeAtIndex:3]] integerValue]];
			}

			match = [frameRateRegex firstMatchInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
			if(match && [match numberOfRanges] == 2)
				[self setFrameRate:[[buffer substringWithRange:[match rangeAtIndex:1]] doubleValue]];

			match = [audioRegex firstMatchInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
			if(match && [match numberOfRanges] == 4) {
				[self setAudio:[buffer substringWithRange:[match rangeAtIndex:1]]];
				[self setAudioRate:[[buffer substringWithRange:[match rangeAtIndex:2]] integerValue]];
				[self setAudioChannels:[buffer substringWithRange:[match rangeAtIndex:3]]];
			}
		}
		
		close(outfd[1]);
		close(infd[0]);
	}
}

- (void)loadInformation {
	[self runFFMPEG:[NSString stringWithFormat:@"-i \"%@\"", [self path]]];
}

-(void)transcode:(NSString*)output videoFormat:(OutputVideoFormat)videoFormat audioFormat:(OutputAudioFormat)audioFormat bitrate:(NSInteger)bitrate {
	NSString *vcodec = @"-vcodec copy";
	if(videoFormat != copyVideo)
		vcodec = [NSString stringWithFormat:@"-vcodec mpeg2video -b %ldk -flags ildct -r 29.97 -s 720x480 -aspect 4:3", bitrate];
	int outputChannels = 2;
	if ([[self audioChannels] isEqualToString:@"mono"])
		outputChannels = 1;
	NSString *acodec = @"-acodec copy";
	if (audioFormat != copyAudio)
		acodec = [NSString stringWithFormat:@"-acodec mp2 -ab 192k -ar 48000 -ac %d", outputChannels];
	[self runFFMPEG:[NSString stringWithFormat:@"-y -i \"%@\" %@ %@ \"%@\"", [self path], vcodec, acodec, output]];
}

@end
