// SPDX-License-Identifier: MIT
#import <Foundation/Foundation.h>

static inline NSInteger SJDuration(NSInteger value) {
    return MAX(50, MIN(1000, value));
}

@interface SJSettings : NSObject
@property(nonatomic) NSInteger milliseconds;
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL showMenuBar;
@property(nonatomic) BOOL dockClicks;
@property(nonatomic) BOOL commandTabs;
@property(nonatomic) BOOL hasOpened;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
@end
