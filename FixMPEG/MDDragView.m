//
//  MDDragView.m
//  FixMPEG
//
//  Created by Scott Jann on 6/19/12.
//  Copyright (c) 2012 Scott Jann. All rights reserved.
//

#import "MDDragView.h"
#import "AppDelegate.h"

@implementation MDDragView

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	
    if([[pboard types] containsObject:NSFilenamesPboardType] ) {
        [self setFiles:[pboard propertyListForType:NSFilenamesPboardType]];
		return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
	[self setFiles:nil];
}

- (void)draggingEnded:(id<NSDraggingInfo>)sender {
	if([self files])
		[[self appDelegate] application:nil openFiles:[self files]];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

@end
