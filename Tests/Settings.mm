// SPDX-License-Identifier: MIT
#import "../Sources/Settings.h"
static void require(BOOL condition, const char *message) { if(!condition) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
int main() {
    @autoreleasepool {
        NSString *suite=[@"dev.rzkr.SpaceJam.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
        SJSettings *first=[[SJSettings alloc] initWithDefaults:defaults];
        require(first.milliseconds==100 && first.enabled && first.showMenuBar && first.dockClicks,"first launch defaults");
        first.milliseconds=75; first.enabled=NO; first.showMenuBar=NO; first.dockClicks=NO; first.hasOpened=YES;
        SJSettings *reopened=[[SJSettings alloc] initWithDefaults:defaults];
        require(reopened.milliseconds==75 && !reopened.enabled && !reopened.showMenuBar && !reopened.dockClicks && reopened.hasOpened,"settings survive reopening");
        [defaults setInteger:-500 forKey:@"durationMS"]; require(reopened.milliseconds==50,"corrupt low duration is bounded");
        [defaults setInteger:NSIntegerMax forKey:@"durationMS"]; require(reopened.milliseconds==1000,"corrupt high duration is bounded");
        [defaults removePersistentDomainForName:suite];
        printf("PASS: first launch, persistence, and invalid-duration bounds. No input posted.\n");
    }
    return 0;
}
