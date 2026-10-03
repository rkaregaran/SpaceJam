// SPDX-License-Identifier: MIT
#import <AppKit/AppKit.h>

@interface SJDockTarget : NSObject
@property(nonatomic) pid_t pid;
@property(nonatomic) CGWindowID window;
@property(nonatomic) int64_t space;
@property(nonatomic) CGRect bounds;
@end

// Called off the event-tap thread. Uses the app's focused/main window and
// refuses conflicting desktops reported by its accessible window list.
SJDockTarget *SJDockTargetAtPoint(CGPoint point);
BOOL SJDockTargetStillValid(SJDockTarget *target);
