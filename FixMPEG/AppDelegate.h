//
//  AppDelegate.h
//  FixMPEG
//
//  Created by Scott Jann on 6/6/13.
//  Copyright (c) 2013 trms.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MDDragView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *description;
@property (weak) IBOutlet NSProgressIndicator *progress;
@property () dispatch_queue_t taskQ;
@property (weak) IBOutlet MDDragView *dragView;
@property (weak) IBOutlet NSButton *forceCheck;
@property (weak) IBOutlet NSSlider *bitrateSlider;
@property (weak) IBOutlet NSTextField *bitrateDescription;
@property (weak) IBOutlet NSBox *optionBox;
@property (assign) BOOL dialogDone;
@property (weak) IBOutlet NSMenuItem *quitItem;
@property (weak) IBOutlet NSMenu *appMenu;
@property (weak) IBOutlet NSButton *pathButton;
- (IBAction)bitrateChanged:(NSSlider *)sender;
- (IBAction)forceChanged:(NSButton *)sender;
- (IBAction)pathClicked:(id)sender;

@end
