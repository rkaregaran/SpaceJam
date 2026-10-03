// SPDX-License-Identifier: MIT
#import "Settings.h"
@implementation SJSettings {
    NSUserDefaults *_defaults;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    if ((self = [super init])) {
        _defaults = defaults;
        [_defaults registerDefaults:@{@"durationMS": @100, @"enabled": @YES,
            @"showMenuBar": @YES, @"hasOpened": @NO}];
    }
    return self;
}
- (NSInteger)milliseconds { return SJDuration([_defaults integerForKey:@"durationMS"]); }
- (void)setMilliseconds:(NSInteger)value { [_defaults setInteger:SJDuration(value) forKey:@"durationMS"]; }
- (BOOL)enabled { return [_defaults boolForKey:@"enabled"]; }
- (void)setEnabled:(BOOL)value { [_defaults setBool:value forKey:@"enabled"]; }
- (BOOL)showMenuBar { return [_defaults boolForKey:@"showMenuBar"]; }
- (void)setShowMenuBar:(BOOL)value { [_defaults setBool:value forKey:@"showMenuBar"]; }
- (BOOL)hasOpened { return [_defaults boolForKey:@"hasOpened"]; }
- (void)setHasOpened:(BOOL)value { [_defaults setBool:value forKey:@"hasOpened"]; }
@end
