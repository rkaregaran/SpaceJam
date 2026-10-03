// SPDX-License-Identifier: MIT
// Copyright 2026 Reza Karegaran
#import "AppDelegate.h"
#import "Settings.h"
#import "SwitchEngine.h"
#import <ServiceManagement/ServiceManagement.h>
#import <Carbon/Carbon.h>

static NSTextField *label(NSString *text, CGFloat size, NSFontWeight weight, NSRect frame) {
    NSTextField *view=[NSTextField wrappingLabelWithString:text];
    view.font=[NSFont systemFontOfSize:size weight:weight]; view.frame=frame;
    return view;
}
static NSButton *button(NSString *title, id target, SEL action, NSRect frame) {
    NSButton *view=[NSButton buttonWithTitle:title target:target action:action];
    view.frame=frame; view.bezelStyle=NSBezelStyleRounded; return view;
}
static NSBox *card(NSRect frame) {
    NSBox *view=[[NSBox alloc] initWithFrame:frame]; view.boxType=NSBoxCustom;
    view.titlePosition=NSNoTitle; view.borderType=NSNoBorder;
    view.cornerRadius=14; view.contentViewMargins=NSZeroSize;
    view.fillColor=NSColor.controlBackgroundColor; return view;
}

@interface SJDragApp : NSView <NSDraggingSource>
@property(nonatomic) NSImage *icon;
@end
@implementation SJDragApp
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.wantsLayer=YES; self.layer.cornerRadius=10; self.layer.borderWidth=1;
        self.layer.borderColor=NSColor.separatorColor.CGColor;
        self.icon=NSApp.applicationIconImage;
        self.accessibilityElement=YES; self.accessibilityLabel=@"SpaceJam.app: drag this app into the Accessibility list";
        self.accessibilityRole=NSAccessibilityImageRole;
    }
    return self;
}
- (void)drawRect:(NSRect)dirty {
    [NSColor.quaternaryLabelColor setFill]; [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:10 yRadius:10] fill];
    [self.icon drawInRect:NSMakeRect(10,10,36,36)];
    [@"SpaceJam.app" drawAtPoint:NSMakePoint(56,31) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor}];
    [@"Drag to Settings →" drawAtPoint:NSMakePoint(56,13) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
}
- (void)mouseDown:(NSEvent *)event {
    NSURL *url=NSBundle.mainBundle.bundleURL;
    NSDraggingItem *item=[[NSDraggingItem alloc] initWithPasteboardWriter:url];
    [item setDraggingFrame:NSMakeRect(0,0,56,56) contents:self.icon];
    NSDraggingSession *session=[self beginDraggingSessionWithItems:@[item] event:event source:self];
    session.animatesToStartingPositionsOnCancelOrFail=YES;
}
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context { return NSDragOperationCopy; }
- (BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session { return YES; }
@end

@interface SJAppDelegate ()
@property(nonatomic) SJSettings *settings;
@property(nonatomic) SJSwitchEngine *engine;
@property(nonatomic) NSWindow *window;
@property(nonatomic) NSPanel *onboarding;
@property(nonatomic) NSStatusItem *statusItem;
@property(nonatomic) NSMenuItem *enabledMenu;
@property(nonatomic) NSMenuItem *testMenu;
@property(nonatomic) NSTextField *permissionState;
@property(nonatomic) NSTextField *permissionHelp;
@property(nonatomic) NSImageView *permissionIcon;
@property(nonatomic) SJDragApp *dragApp;
@property(nonatomic) NSButton *verifyButton;
@property(nonatomic) NSTextField *durationField;
@property(nonatomic) NSSlider *durationSlider;
@property(nonatomic) NSSwitch *enabledSwitch;
@property(nonatomic) NSTextField *enabledLabel;
@property(nonatomic) NSTextField *statusLabel;
@property(nonatomic) NSButton *menuCheckbox;
@property(nonatomic) NSButton *dockCheckbox;
@property(nonatomic) NSButton *loginCheckbox;
@property(nonatomic) NSTimer *permissionTimer;
@property(nonatomic) BOOL trusted;
@property(nonatomic) BOOL didReadPermission;
@property(nonatomic) NSInteger previewPermission;
@property(nonatomic) NSUInteger pollCount;
@end

@implementation SJAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if(!self.preview) {
        for(NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier]) {
            if(app.processIdentifier==NSProcessInfo.processInfo.processIdentifier) continue;
            NSWorkspaceOpenConfiguration *config=NSWorkspaceOpenConfiguration.configuration; config.activates=YES;
            [NSWorkspace.sharedWorkspace openApplicationAtURL:app.bundleURL configuration:config completionHandler:nil];
            [NSApp terminate:nil]; return;
        }
    }
    NSUserDefaults *defaults=self.preview?[[NSUserDefaults alloc] initWithSuiteName:@"dev.rzkr.SpaceJam.preview"]:NSUserDefaults.standardUserDefaults;
    self.settings=[[SJSettings alloc] initWithDefaults:defaults];
    self.engine=[SJSwitchEngine new]; self.engine.milliseconds=self.settings.milliseconds;
    self.engine.dockClicks=self.settings.dockClicks;
    __weak SJAppDelegate *weakSelf=self;
    self.engine.didChange=^{ [weakSelf refreshUI]; };
    [self buildWindow];
    if(self.preview) { [self renderPreviews]; [NSApp terminate:nil]; return; }
    [self updateMenuBar]; [self reconcile:YES];
    self.permissionTimer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        SJAppDelegate *app=weakSelf; if(!app) return;
        app.pollCount++;
        if(app.window.visible || app.onboarding.visible || app.pollCount%10==0) [app reconcile:NO];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.permissionTimer forMode:NSRunLoopCommonModes];
    NSNotificationCenter *workspace=NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:self selector:@selector(willSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [workspace addObserver:self selector:@selector(didWake:) name:NSWorkspaceDidWakeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(displayChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    NSAppleEventDescriptor *event=NSAppleEventManager.sharedAppleEventManager.currentAppleEvent;
    BOOL login=[event paramDescriptorForKeyword:keyAELaunchedAsLogInItem].booleanValue;
    BOOL background=[NSProcessInfo.processInfo.arguments containsObject:@"--background"];
    if(!self.settings.hasOpened || (!login && !background)) [self showSettings:nil];
    self.settings.hasOpened=YES;
}
- (void)buildWindow {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,640,628)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"SpaceJam"; self.window.delegate=self;
    self.window.releasedWhenClosed=NO; self.window.backgroundColor=NSColor.windowBackgroundColor;
    self.window.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces;
    NSView *root=self.window.contentView;
    NSImageView *brand=[[NSImageView alloc] initWithFrame:NSMakeRect(28,554,48,48)];
    brand.image=NSApp.applicationIconImage; [root addSubview:brand];
    [root addSubview:label(@"SpaceJam",30,NSFontWeightBold,NSMakeRect(90,564,310,40))];
    NSTextField *subtitle=label(@"Your desktops. At your speed.",13,NSFontWeightRegular,NSMakeRect(90,543,350,22));
    subtitle.textColor=NSColor.secondaryLabelColor; [root addSubview:subtitle];
    self.enabledSwitch=[[NSSwitch alloc] initWithFrame:NSMakeRect(565,570,48,28)];
    self.enabledSwitch.target=self; self.enabledSwitch.action=@selector(toggleEnabled:); [root addSubview:self.enabledSwitch];
    self.enabledLabel=label(@"Enabled",12,NSFontWeightMedium,NSMakeRect(486,574,72,22)); [root addSubview:self.enabledLabel];

    NSBox *permission=card(NSMakeRect(24,326,592,192)); [root addSubview:permission]; NSView *p=permission.contentView;
    self.permissionIcon=[[NSImageView alloc] initWithFrame:NSMakeRect(20,143,24,24)]; [p addSubview:self.permissionIcon];
    [p addSubview:label(@"Accessibility",17,NSFontWeightSemibold,NSMakeRect(54,145,270,28))];
    self.permissionState=label(@"Required",12,NSFontWeightSemibold,NSMakeRect(410,147,160,24));
    self.permissionState.alignment=NSTextAlignmentRight; [p addSubview:self.permissionState];
    self.permissionHelp=label(@"Drag SpaceJam into the list, then turn on its switch.",13,NSFontWeightRegular,NSMakeRect(20,91,552,45));
    self.permissionHelp.textColor=NSColor.secondaryLabelColor; [p addSubview:self.permissionHelp];
    self.dragApp=[[SJDragApp alloc] initWithFrame:NSMakeRect(20,20,194,56)]; [p addSubview:self.dragApp];
    self.verifyButton=button(@"Verify switching",self,@selector(verify:),NSMakeRect(20,29,194,36));
    self.verifyButton.hidden=YES; [p addSubview:self.verifyButton];
    [p addSubview:button(@"Open Settings…",self,@selector(openAccessibility:),NSMakeRect(366,29,206,36))];

    NSBox *speed=card(NSMakeRect(24,152,592,156)); [root addSubview:speed]; NSView *s=speed.contentView;
    [s addSubview:label(@"Animation duration",17,NSFontWeightSemibold,NSMakeRect(20,112,300,28))];
    self.durationField=[[NSTextField alloc] initWithFrame:NSMakeRect(462,108,74,32)];
    self.durationField.font=[NSFont monospacedDigitSystemFontOfSize:17 weight:NSFontWeightMedium];
    self.durationField.alignment=NSTextAlignmentCenter; self.durationField.delegate=self;
    self.durationField.target=self; self.durationField.action=@selector(durationTyped:);
    self.durationField.bezelStyle=NSTextFieldRoundedBezel; self.durationField.accessibilityLabel=@"Animation duration in milliseconds";
    [s addSubview:self.durationField]; [s addSubview:label(@"ms",13,NSFontWeightRegular,NSMakeRect(544,112,26,25))];
    self.durationSlider=[[NSSlider alloc] initWithFrame:NSMakeRect(20,62,552,28)];
    self.durationSlider.minValue=50; self.durationSlider.maxValue=1000;
    self.durationSlider.target=self; self.durationSlider.action=@selector(durationSlid:); self.durationSlider.continuous=YES;
    self.durationSlider.accessibilityLabel=@"Animation duration"; [s addSubview:self.durationSlider];
    [s addSubview:label(@"50 ms",11,NSFontWeightRegular,NSMakeRect(20,38,70,20))];
    NSTextField *slow=label(@"1,000 ms",11,NSFontWeightRegular,NSMakeRect(477,38,95,20)); slow.alignment=NSTextAlignmentRight; [s addSubview:slow];
    NSTextField *hint=label(@"Smaller number, quicker desktop slide.",12,NSFontWeightRegular,NSMakeRect(20,12,552,23));
    hint.textColor=NSColor.secondaryLabelColor; [s addSubview:hint];
    self.dockCheckbox=[NSButton checkboxWithTitle:@"Speed up Dock app clicks" target:self action:@selector(dockPreference:)];
    self.dockCheckbox.frame=NSMakeRect(28,110,552,26); [root addSubview:self.dockCheckbox];
    self.menuCheckbox=[NSButton checkboxWithTitle:@"Show in menu bar" target:self action:@selector(menuPreference:)];
    self.menuCheckbox.frame=NSMakeRect(28,74,260,26); [root addSubview:self.menuCheckbox];
    self.loginCheckbox=[NSButton checkboxWithTitle:@"Open at login" target:self action:@selector(loginPreference:)];
    self.loginCheckbox.frame=NSMakeRect(316,74,280,26); [root addSubview:self.loginCheckbox];
    self.statusLabel=label(@"",12,NSFontWeightRegular,NSMakeRect(28,20,510,42));
    self.statusLabel.textColor=NSColor.secondaryLabelColor; [root addSubview:self.statusLabel];
    NSString *version=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"0.1.0";
    NSTextField *versionLabel=label(version,11,NSFontWeightRegular,NSMakeRect(550,28,64,22));
    versionLabel.textColor=NSColor.tertiaryLabelColor; versionLabel.alignment=NSTextAlignmentRight; [root addSubview:versionLabel];
    [self.window center]; [self refreshUI];
}
- (void)reconcile:(BOOL)retry {
    BOOL trusted=AXIsProcessTrusted(); BOOL changed=!self.didReadPermission || trusted!=self.trusted;
    self.trusted=trusted; self.didReadPermission=YES;
    self.engine.milliseconds=self.settings.milliseconds;
    self.engine.dockClicks=self.settings.dockClicks;
    if(!trusted || !self.settings.enabled) { if(self.engine.running) [self.engine stop]; }
    else if((changed || retry) && !self.engine.running) [self.engine start];
    if(trusted && self.onboarding.visible) [self.onboarding close];
    [self refreshUI];
}
- (void)refreshUI {
    if(!self.window) return;
    BOOL allowed=self.preview?self.previewPermission==1:self.trusted;
    self.permissionState.stringValue=allowed?@"On":@"Required";
    self.permissionState.textColor=allowed?NSColor.systemGreenColor:NSColor.systemOrangeColor;
    self.permissionIcon.image=[NSImage imageWithSystemSymbolName:allowed?@"checkmark.circle.fill":@"lock.circle.fill" accessibilityDescription:allowed?@"Accessibility enabled":@"Accessibility required"];
    self.permissionIcon.contentTintColor=self.permissionState.textColor;
    self.permissionHelp.stringValue=allowed?@"SpaceJam has permission to listen for your shortcuts and switch desktops.":@"Open Settings, drag SpaceJam into the list, then turn on its switch.";
    self.dragApp.hidden=allowed; self.verifyButton.hidden=!allowed;
    self.verifyButton.enabled=self.engine.running && !self.engine.animating;
    self.enabledSwitch.state=self.settings.enabled?NSControlStateValueOn:NSControlStateValueOff;
    self.enabledLabel.stringValue=self.settings.enabled?@"Enabled":@"Paused";
    if(self.window.firstResponder!=self.durationField.currentEditor) self.durationField.integerValue=self.settings.milliseconds;
    self.durationSlider.integerValue=self.settings.milliseconds;
    self.dockCheckbox.state=self.settings.dockClicks?NSControlStateValueOn:NSControlStateValueOff;
    self.menuCheckbox.state=self.settings.showMenuBar?NSControlStateValueOn:NSControlStateValueOff;
    self.loginCheckbox.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled?NSControlStateValueOn:NSControlStateValueOff;
    if(!allowed) self.statusLabel.stringValue=@"Enable Accessibility above to get started.";
    else if(!self.settings.enabled) self.statusLabel.stringValue=@"Paused. Your usual desktop shortcuts are active.";
    else self.statusLabel.stringValue=self.preview?@"Ready for Control–Left/Right and Dock app clicks.":self.engine.message;
    self.enabledMenu.state=self.settings.enabled?NSControlStateValueOn:NSControlStateValueOff;
    self.testMenu.enabled=self.engine.running;
    self.statusItem.button.toolTip=self.engine.running?@"SpaceJam · enabled":@"SpaceJam · paused";
    if(SMAppService.mainAppService.status==SMAppServiceStatusRequiresApproval)
        self.statusLabel.stringValue=@"Allow SpaceJam under System Settings → Login Items to finish opening at login.";
}
- (void)updateMenuBar {
    if(!self.settings.showMenuBar) {
        if(self.statusItem) [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
        self.statusItem=nil; self.enabledMenu=nil; self.testMenu=nil; return;
    }
    if(self.statusItem) return;
    self.statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *image=[NSImage imageWithSystemSymbolName:@"rectangle.2.swap" accessibilityDescription:@"SpaceJam"];
    if(!image) image=[NSImage imageWithSystemSymbolName:@"rectangle.2" accessibilityDescription:@"SpaceJam"];
    [image setTemplate:YES]; self.statusItem.button.image=image;
    NSMenu *menu=[NSMenu new];
    NSMenuItem *title=[[NSMenuItem alloc] initWithTitle:@"SpaceJam" action:nil keyEquivalent:@""]; title.enabled=NO; [menu addItem:title];
    self.enabledMenu=[[NSMenuItem alloc] initWithTitle:@"Enabled" action:@selector(toggleEnabled:) keyEquivalent:@""];
    self.enabledMenu.target=self; [menu addItem:self.enabledMenu];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings=[[NSMenuItem alloc] initWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];
    settings.target=self; [menu addItem:settings];
    self.testMenu=[[NSMenuItem alloc] initWithTitle:@"Verify switching" action:@selector(verify:) keyEquivalent:@""];
    self.testMenu.target=self; [menu addItem:self.testMenu];
    NSMenuItem *hide=[[NSMenuItem alloc] initWithTitle:@"Hide menu bar icon" action:@selector(hideMenu:) keyEquivalent:@""];
    hide.target=self; [menu addItem:hide]; [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[[NSMenuItem alloc] initWithTitle:@"Quit SpaceJam" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target=NSApp; [menu addItem:quit]; self.statusItem.menu=menu; [self refreshUI];
}
- (void)showSettings:(id)sender { [self reconcile:NO]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES]; }
- (void)closeSettings:(id)sender { [self.window orderOut:nil]; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible { [self showSettings:nil]; return NO; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return NO; }
- (BOOL)windowShouldClose:(NSWindow *)window { [window orderOut:nil]; return NO; }
- (void)toggleEnabled:(id)sender {
    self.settings.enabled=!self.settings.enabled; [self reconcile:YES];
    if(self.settings.enabled && !self.trusted) [self showSettings:nil];
}
- (void)durationSlid:(NSSlider *)sender { self.settings.milliseconds=(NSInteger)llround(sender.doubleValue); self.engine.milliseconds=self.settings.milliseconds; [self refreshUI]; }
- (void)durationTyped:(id)sender {
    NSString *text=[self.durationField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSScanner *scanner=[NSScanner scannerWithString:text]; NSInteger value=0;
    if([scanner scanInteger:&value] && scanner.isAtEnd && value>=50 && value<=1000) {
        self.settings.milliseconds=value; self.engine.milliseconds=value;
    } else { NSBeep(); self.statusLabel.stringValue=@"Choose a duration from 50 to 1,000 milliseconds."; }
    self.durationField.integerValue=self.settings.milliseconds; self.durationSlider.integerValue=self.settings.milliseconds;
}
- (void)controlTextDidEndEditing:(NSNotification *)notification { if(notification.object==self.durationField) [self durationTyped:nil]; }
- (void)dockPreference:(NSButton *)sender { self.settings.dockClicks=sender.state==NSControlStateValueOn; self.engine.dockClicks=self.settings.dockClicks; [self refreshUI]; }
- (void)menuPreference:(NSButton *)sender { self.settings.showMenuBar=sender.state==NSControlStateValueOn; [self updateMenuBar]; [self refreshUI]; }
- (void)hideMenu:(id)sender { self.settings.showMenuBar=NO; [self showSettings:nil]; [self updateMenuBar]; [self refreshUI]; }
- (void)loginPreference:(NSButton *)sender {
    NSError *error=nil;
    BOOL success=sender.state==NSControlStateValueOn?[SMAppService.mainAppService registerAndReturnError:&error]:[SMAppService.mainAppService unregisterAndReturnError:&error];
    [self refreshUI];
    if(!success) self.statusLabel.stringValue=error.localizedDescription?:@"Could not change Open at login.";
    else if(SMAppService.mainAppService.status==SMAppServiceStatusRequiresApproval) [SMAppService openSystemSettingsLoginItems];
}
- (void)openAccessibility:(id)sender {
    NSDictionary *options=@{(__bridge NSString *)kAXTrustedCheckOptionPrompt:@YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    if(self.trusted) return;
    [self buildOnboarding]; [self.onboarding orderFrontRegardless];
}
- (void)buildOnboarding {
    if(self.onboarding) return;
    self.onboarding=[[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,350,232)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskUtilityWindow|NSWindowStyleMaskNonactivatingPanel
        backing:NSBackingStoreBuffered defer:NO];
    self.onboarding.title=@"Allow SpaceJam"; self.onboarding.floatingPanel=YES;
    self.onboarding.hidesOnDeactivate=NO; self.onboarding.level=NSFloatingWindowLevel;
    self.onboarding.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces;
    self.onboarding.releasedWhenClosed=NO;
    NSView *root=self.onboarding.contentView;
    [root addSubview:label(@"One permission. Then you're ready.",17,NSFontWeightSemibold,NSMakeRect(20,176,310,34))];
    NSTextField *instructions=label(@"Drag the app below into the list in System Settings, then enable its switch.",13,NSFontWeightRegular,NSMakeRect(20,117,310,50));
    instructions.textColor=NSColor.secondaryLabelColor; [root addSubview:instructions];
    [root addSubview:[[SJDragApp alloc] initWithFrame:NSMakeRect(20,48,310,56)]];
    NSTextField *hint=label(@"Already listed but still off here? Remove the old entry and drag it in again.",11,NSFontWeightRegular,NSMakeRect(20,6,310,37));
    hint.textColor=NSColor.secondaryLabelColor; [root addSubview:hint];
    [self.onboarding center];
}
- (void)verify:(id)sender { [self.engine testRoundTrip]; [self refreshUI]; }
- (void)willSleep:(NSNotification *)notification { [self.engine stop]; }
- (void)didWake:(NSNotification *)notification { [self reconcile:YES]; }
- (void)displayChanged:(NSNotification *)notification { [self.engine stop]; [self reconcile:YES]; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [self.engine stop]; [self.permissionTimer invalidate]; return NSTerminateNow;
}
- (void)saveView:(NSView *)view name:(NSString *)name {
    [view layoutSubtreeIfNeeded]; [view display];
    NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    // Content views do not cache their window's background. Composite onto it
    // so exported previews retain the actual native light appearance.
    NSBitmapImageRep *rendered=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr
        pixelsWide:bitmap.pixelsWide pixelsHigh:bitmap.pixelsHigh bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
        bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:rendered];
    NSAffineTransform *scale=NSAffineTransform.transform;
    [scale scaleBy:bitmap.pixelsWide/view.bounds.size.width]; [scale concat];
    [[NSColor colorWithWhite:1 alpha:1] setFill]; NSRectFill(view.bounds);
    NSImage *foreground=[[NSImage alloc] initWithSize:view.bounds.size];
    [foreground addRepresentation:bitmap];
    [foreground drawInRect:view.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
        fraction:1 respectFlipped:NO hints:nil];
    [NSGraphicsContext restoreGraphicsState];
    NSData *png=[rendered representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString *path=[self.previewFolder stringByAppendingPathComponent:name];
    if(![png writeToFile:path atomically:YES]) { fprintf(stderr,"Could not save %s\n",path.UTF8String); exit(1); }
}
- (void)renderPreviews {
    [NSFileManager.defaultManager createDirectoryAtPath:self.previewFolder withIntermediateDirectories:YES attributes:nil error:nil];
    // Preview only: never starts an event tap, changes permission, or posts input.
    self.settings.milliseconds=100; self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
    self.previewPermission=0; [self refreshUI]; [self saveView:self.window.contentView name:@"onboarding.png"];
    self.previewPermission=1; [self refreshUI]; [self saveView:self.window.contentView name:@"settings.png"];
    [self buildOnboarding]; self.onboarding.appearance=self.window.appearance;
    [self saveView:self.onboarding.contentView name:@"permission-helper.png"];
    printf("Rendered native UI previews to %s. No events posted.\n",self.previewFolder.UTF8String);
}
@end
