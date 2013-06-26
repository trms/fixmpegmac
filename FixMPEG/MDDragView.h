//
//  MDDragView.h
//  FixMPEG
//
//  Created by Scott Jann on 6/19/12.
//  Copyright (c) 2012 Scott Jann. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AppDelegate;

@interface MDDragView : NSView

@property (weak) AppDelegate *appDelegate;
@property () NSArray *files;

@end
