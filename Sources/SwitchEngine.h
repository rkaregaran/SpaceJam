// SPDX-License-Identifier: MIT
#import <AppKit/AppKit.h>

@interface SJSwitchEngine : NSObject
@property(nonatomic) NSInteger milliseconds;
@property(nonatomic, readonly) BOOL running;
@property(nonatomic, readonly) BOOL animating;
@property(nonatomic, copy, readonly) NSString *message;
@property(nonatomic, copy) void (^didChange)(void);
- (BOOL)start;
- (void)stop;
- (void)testRoundTrip;
@end

int SJInspectSpaces(void);
