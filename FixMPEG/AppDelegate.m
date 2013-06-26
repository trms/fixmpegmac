//
//  AppDelegate.m
//  FixMPEG
//
//  Created by Scott Jann on 6/6/13.
//  Copyright (c) 2013 trms.com. All rights reserved.
//

#import "AppDelegate.h"
#import "VideoProcessor.h"

#define HEIGHT_DIFF 94

@implementation AppDelegate

- (void)initQueue {
	[[self dragView] setAppDelegate:self];
	if([self taskQ] == nil) {
		[self setTaskQ:dispatch_queue_create("com.trms.createQ", DISPATCH_QUEUE_SERIAL)];
	}
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:false, @"force", [NSNumber numberWithInteger:6], @"bitrate", [@"~/Movies" stringByExpandingTildeInPath], @"path", nil]];
	if([[NSUserDefaults standardUserDefaults] stringForKey:@"path"] == nil) {
		[[NSUserDefaults standardUserDefaults] setObject:[@"~/Movies" stringByExpandingTildeInPath] forKey:@"path"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void)resetUI {
	[[self description] setStringValue:@"Drop a video file here to fix it."];
	[[self progress] setDoubleValue:0];
	
	[[self forceCheck] setState:([[NSUserDefaults standardUserDefaults] boolForKey:@"force"] ? NSOnState : NSOffState)];
	[[self bitrateSlider] setIntegerValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"bitrate"]];
	[[self bitrateDescription] setStringValue:[NSString stringWithFormat:@"%ldMbps", [[self bitrateSlider] integerValue]]];
	[[self pathButton] setTitle:[[[NSUserDefaults standardUserDefaults] stringForKey:@"path"] lastPathComponent]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[MDDragView class];
	[[self progress] setHidden:YES];
	[[self optionBox] setHidden:NO];
	[self setDialogDone:NO];
	
	[self initQueue];
	[self resetUI];
}

-(BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
	[self initQueue];
	dispatch_async(_taskQ, ^{
		[self fixVideo:filename];
	});
	return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
	[self initQueue];
	for(NSString *path in filenames) {
		dispatch_async(_taskQ, ^{
			[self fixVideo:path];
		});
	}
}

- (void)fixVideo:(NSString*)path {
	dispatch_sync(dispatch_get_main_queue(), ^{
		[[self description] setStringValue:[NSString stringWithFormat:@"Analyzing %@...", [path lastPathComponent]]];
		[[self progress] setDoubleValue:0];
		[[self progress] setHidden:NO];
		[[self optionBox] setHidden:YES];
		[[self appMenu] setAutoenablesItems:NO];
		[[self quitItem] setEnabled:NO];
		
		NSRect oldFrame = [[self window] frame];
		oldFrame.size.height -= HEIGHT_DIFF;
		oldFrame.origin.y += HEIGHT_DIFF;
		[[self window] setFrame:oldFrame display:YES animate:YES];
	});
	
	VideoProcessor *vp = [[VideoProcessor alloc] initWithFile:path];
	__block BOOL failed = NO;
	[self setDialogDone:NO];
	[vp setErrorCallback:^(NSError *error) {
		dispatch_sync(dispatch_get_main_queue(), ^{
			failed = YES;
			[[self dragView] presentError:error modalForWindow:[self window] delegate:self didPresentSelector:@selector(dismissedError:contextInfo:) contextInfo:nil];
		});
		while([self dialogDone] == NO)
			usleep(100000);
	}];
	[self setDialogDone:NO];
	[vp loadInformation];

	if(failed == NO) {
		[vp setCallback:^(double progress) {
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[self progress] setDoubleValue:progress];
			});
		}];
		
		OutputVideoFormat video = mpeg2;
		OutputAudioFormat audio = mp2;
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"force"] == NO && [[vp audio] isEqualToString:@"mp2"] && [vp audioRate] == 48000 && ([[vp audioChannels] isEqualToString:@"mono"] || [[vp audioChannels] isEqualToString:@"stereo"]))
			audio = copyAudio;

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"force"] == NO && [vp height] <= 486 && [vp width] <= 720 && [vp frameRate] == 29.97 && [[vp video] isEqualToString:@"mpeg2video"])
			video = copyVideo;
		
		NSString *output = [NSString stringWithFormat:@"%@/%@.mpg", [[NSUserDefaults standardUserDefaults] stringForKey:@"path"], [[[vp path] lastPathComponent] stringByDeletingPathExtension]];
		if(video == copyVideo && audio == copyAudio) {
			NSError *error = nil;
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[self description] setStringValue:[NSString stringWithFormat:@"Copying %@...", [path lastPathComponent]]];
			});
			[[NSFileManager defaultManager] copyItemAtPath:[vp path] toPath:output error:&error];
			if(error) {
				[self setDialogDone:NO];
				dispatch_sync(dispatch_get_main_queue(), ^{
					failed = YES;
					[[self dragView] presentError:error modalForWindow:[self window] delegate:self didPresentSelector:@selector(dismissedError:contextInfo:) contextInfo:nil];
				});
				while([self dialogDone] == NO)
					usleep(100000);
				[self setDialogDone:NO];
			}
		} else {
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[self description] setStringValue:[NSString stringWithFormat:@"Transcoding %@...", [path lastPathComponent]]];
			});
			[vp transcode:output videoFormat:video audioFormat:audio bitrate:(1000 * [[NSUserDefaults standardUserDefaults] integerForKey:@"bitrate"])];
		}
		
		dispatch_sync(dispatch_get_main_queue(), ^{
			[[self progress] setDoubleValue:1.0];
		});	
		
		usleep(500000);
	}
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		[self resetUI];
		[[self progress] setHidden:YES];
		[[self optionBox] setHidden:NO];
		[[self quitItem] setEnabled:YES];
		[[self appMenu] setAutoenablesItems:YES];
		NSRect oldFrame = [[self window] frame];
		oldFrame.size.height += HEIGHT_DIFF;
		oldFrame.origin.y -= HEIGHT_DIFF;
		[[self window] setFrame:oldFrame display:YES animate:YES];
	});
}

- (void)dismissedError:(BOOL)didRecover contextInfo:(void *)contextInfo {
	[self setDialogDone:YES];
}

- (IBAction)bitrateChanged:(NSSlider *)sender {
	[sender setIntegerValue:[sender integerValue]];
	[[NSUserDefaults standardUserDefaults] setInteger:[sender integerValue] forKey:@"bitrate"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[self bitrateDescription] setStringValue:[NSString stringWithFormat:@"%ldMbps", [sender integerValue]]];
}

- (IBAction)forceChanged:(NSButton *)sender {
	[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:@"force"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)pathClicked:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:NO];
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:YES];
	[panel setDirectoryURL:[NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] stringForKey:@"path"]]];
	
	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			[[NSUserDefaults standardUserDefaults] setObject:[[panel URL] path] forKey:@"path"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self resetUI];
		}
	}];
}

@end
