// SPDX-License-Identifier: MIT
#import "AppDelegate.h"
#import "SwitchEngine.h"

int main(int argc, char **argv) {
    @autoreleasepool {
        if(argc==2 && strcmp(argv[1],"--inspect-spaces")==0) return SJInspectSpaces();
        NSApplication *app=NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        SJAppDelegate *delegate=[SJAppDelegate new];
        if(argc==3 && strcmp(argv[1],"--render-screenshots")==0) {
            delegate.preview=YES; delegate.previewFolder=[NSString stringWithUTF8String:argv[2]];
        }
        NSMenu *menu=[NSMenu new]; NSMenuItem *root=[NSMenuItem new]; [menu addItem:root];
        NSMenu *application=[NSMenu new];
        NSMenuItem *settings=[application addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];
        settings.target=delegate;
        NSMenuItem *close=[application addItemWithTitle:@"Close Settings" action:@selector(closeSettings:) keyEquivalent:@"w"];
        close.target=delegate;
        [application addItem:NSMenuItem.separatorItem];
        [application addItemWithTitle:@"Quit SpaceJam" action:@selector(terminate:) keyEquivalent:@"q"];
        root.submenu=application; app.mainMenu=menu; app.delegate=delegate;
        [app run];
    }
    return 0;
}
