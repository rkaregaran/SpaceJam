// SPDX-License-Identifier: MIT
#import "DockTarget.h"
#import <ApplicationServices/ApplicationServices.h>
extern "C" int SLSMainConnectionID(void);
extern "C" CFArrayRef SLSCopySpacesForWindows(int, int, CFArrayRef);
extern "C" AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID *);

@implementation SJDockTarget
@end

static id attribute(AXUIElementRef element, CFStringRef name) {
    CFTypeRef value=nullptr;
    if(AXUIElementCopyAttributeValue(element,name,&value)!=kAXErrorSuccess) return nil;
    return CFBridgingRelease(value);
}
static NSArray *spacesForWindow(CGWindowID window) {
    id spaces=CFBridgingRelease(SLSCopySpacesForWindows(SLSMainConnectionID(),7,(__bridge CFArrayRef)@[@(window)]));
    return [spaces isKindOfClass:NSArray.class]?spaces:nil;
}
static SJDockTarget *targetForApplication(NSRunningApplication *app, CFAbsoluteTime deadline, BOOL locateWindow) {
    AXUIElementRef application=AXUIElementCreateApplication(app.processIdentifier);
    AXUIElementSetMessagingTimeout(application,0.04);
    // Some apps omit off-Space windows from AXWindows on macOS 27. Their
    // focused/main window still identifies the last app window. WindowServer
    // also lists app rendering surfaces, so use AX windows for ambiguity checks.
    __attribute__((objc_precise_lifetime)) id window=attribute(application,kAXFocusedWindowAttribute)?:attribute(application,kAXMainWindowAttribute);
    id windows=attribute(application,kAXWindowsAttribute);
    CFRelease(application);
    if(!window || CFGetTypeID((__bridge CFTypeRef)window)!=AXUIElementGetTypeID()) return nil;
    AXUIElementRef ref=(__bridge AXUIElementRef)window;
    AXUIElementSetMessagingTimeout(ref,0.04);
    id minimized=attribute(ref,kAXMinimizedAttribute);
    if(![minimized isKindOfClass:NSNumber.class] || [minimized boolValue]) return nil;
    CGWindowID selected=0;
    if(_AXUIElementGetWindow(ref,&selected)!=kAXErrorSuccess || !selected) return nil;
    NSArray *selectedSpaces=spacesForWindow(selected);
    if(selectedSpaces.count!=1 || ![selectedSpaces.firstObject isKindOfClass:NSNumber.class]) return nil;
    int64_t destination=[selectedSpaces.firstObject longLongValue];
    if(![windows isKindOfClass:NSArray.class] || [windows count]>64) return nil;
    for(id other in windows) {
        if(CFAbsoluteTimeGetCurrent()>deadline) return nil;
        if(CFGetTypeID((__bridge CFTypeRef)other)!=AXUIElementGetTypeID()) return nil;
        AXUIElementRef otherRef=(__bridge AXUIElementRef)other;
        AXUIElementSetMessagingTimeout(otherRef,0.04);
        id isMinimized=attribute(otherRef,kAXMinimizedAttribute);
        if(![isMinimized isKindOfClass:NSNumber.class]) return nil;
        if([isMinimized boolValue]) continue;
        CGWindowID wid=0;
        if(_AXUIElementGetWindow(otherRef,&wid)!=kAXErrorSuccess || !wid) return nil;
        NSArray *spaces=spacesForWindow(wid);
        if(!spaces.count) return nil;
        if(spaces.count!=1 || ![spaces.firstObject isEqual:@(destination)]) return nil;
    }
    if(!destination || CFAbsoluteTimeGetCurrent()>deadline) return nil;
    SJDockTarget *target=[SJDockTarget new];
    target.pid=app.processIdentifier; target.window=selected; target.space=destination;
    if(locateWindow) {
        id position=attribute(ref,kAXPositionAttribute), dimensions=attribute(ref,kAXSizeAttribute);
        CGPoint origin; CGSize size;
        if(position && dimensions && CFGetTypeID((__bridge CFTypeRef)position)==AXValueGetTypeID() &&
           CFGetTypeID((__bridge CFTypeRef)dimensions)==AXValueGetTypeID() &&
           AXValueGetValue((__bridge AXValueRef)position,static_cast<AXValueType>(kAXValueCGPointType),&origin) &&
           AXValueGetValue((__bridge AXValueRef)dimensions,static_cast<AXValueType>(kAXValueCGSizeType),&size))
            target.windowBounds=CGRectMake(origin.x,origin.y,size.width,size.height);
    }
    return CFAbsoluteTimeGetCurrent()<=deadline?target:nil;
}
static BOOL switchesToAppSpace() {
    Boolean exists=false;
    Boolean swoosh=CFPreferencesGetAppBooleanValue(CFSTR("workspaces-auto-swoosh"),CFSTR("com.apple.dock"),&exists);
    return !exists || swoosh;
}
BOOL SJDockTargetStillValid(SJDockTarget *target) {
    NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:target.pid];
    NSArray *spaces=spacesForWindow(target.window);
    return app && !app.terminated && spaces.count==1 && [spaces.firstObject isEqual:@(target.space)];
}
SJDockTarget *SJDockTargetAtPoint(CGPoint point) {
    CFAbsoluteTime deadline=CFAbsoluteTimeGetCurrent()+0.08;
    if(!switchesToAppSpace()) return nil;
    AXUIElementRef system=AXUIElementCreateSystemWide();
    AXUIElementSetMessagingTimeout(system,0.04);
    AXUIElementRef hit=nullptr;
    AXError error=AXUIElementCopyElementAtPosition(system,point.x,point.y,&hit);
    CFRelease(system);
    if(error!=kAXErrorSuccess || !hit) return nil;
    __attribute__((objc_precise_lifetime)) id element=CFBridgingRelease(hit);
    AXUIElementSetMessagingTimeout(hit,0.04);
    pid_t pid=0;
    if(AXUIElementGetPid(hit,&pid)!=kAXErrorSuccess) return nil;
    NSRunningApplication *owner=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if(![owner.bundleIdentifier isEqualToString:@"com.apple.dock"] ||
       ![attribute(hit,kAXSubroleAttribute) isEqual:@"AXApplicationDockItem"]) return nil;
    id url=attribute(hit,kAXURLAttribute);
    if(![url isKindOfClass:NSURL.class] || ![url isFileURL]) return nil;
    NSRunningApplication *app=nil;
    for(NSRunningApplication *candidate in NSWorkspace.sharedWorkspace.runningApplications) {
        if([candidate.bundleURL.URLByStandardizingPath isEqual:[url URLByStandardizingPath]]) { app=candidate; break; }
    }
    if(!app || app.terminated) return nil;
    CGPoint origin; CGSize size;
    id position=attribute(hit,kAXPositionAttribute), dimensions=attribute(hit,kAXSizeAttribute);
    if(!position || CFGetTypeID((__bridge CFTypeRef)position)!=AXValueGetTypeID() ||
       !dimensions || CFGetTypeID((__bridge CFTypeRef)dimensions)!=AXValueGetTypeID() ||
       !AXValueGetValue((__bridge AXValueRef)position,static_cast<AXValueType>(kAXValueCGPointType),&origin) ||
       !AXValueGetValue((__bridge AXValueRef)dimensions,static_cast<AXValueType>(kAXValueCGSizeType),&size)) return nil;
    CGRect bounds={origin,size};
    if(!CGRectContainsPoint(bounds,point)) return nil;
    SJDockTarget *target=targetForApplication(app,deadline,NO);
    target.bounds=bounds;
    (void)element;
    return target;
}

SJDockTarget *SJCommandTabTarget(void) {
    CFAbsoluteTime deadline=CFAbsoluteTimeGetCurrent()+0.08;
    if(!switchesToAppSpace()) return nil;
    NSRunningApplication *dock=nil;
    NSArray<NSRunningApplication *> *apps=NSWorkspace.sharedWorkspace.runningApplications;
    for(NSRunningApplication *app in apps) if([app.bundleIdentifier isEqual:@"com.apple.dock"]) { dock=app; break; }
    if(!dock) return nil;
    AXUIElementRef application=AXUIElementCreateApplication(dock.processIdentifier);
    AXUIElementSetMessagingTimeout(application,0.04);
    __attribute__((objc_precise_lifetime)) id owner=CFBridgingRelease(application);
    id lists=attribute(application,kAXChildrenAttribute);
    if(![lists isKindOfClass:NSArray.class] || [lists count]>32) return nil;
    for(id list in lists) {
        if(CFAbsoluteTimeGetCurrent()>deadline || CFGetTypeID((__bridge CFTypeRef)list)!=AXUIElementGetTypeID()) return nil;
        AXUIElementRef ref=(__bridge AXUIElementRef)list;
        AXUIElementSetMessagingTimeout(ref,0.04);
        if(![attribute(ref,kAXSubroleAttribute) isEqual:@"AXProcessSwitcherList"] ||
           ![attribute(ref,kAXFocusedAttribute) isEqual:@YES]) continue;
        id selection=attribute(ref,kAXSelectedChildrenAttribute);
        if(![selection isKindOfClass:NSArray.class] || [selection count]!=1) return nil;
        id selected=[selection firstObject];
        if(CFGetTypeID((__bridge CFTypeRef)selected)!=AXUIElementGetTypeID()) return nil;
        AXUIElementRef button=(__bridge AXUIElementRef)selected;
        AXUIElementSetMessagingTimeout(button,0.04);
        if(![attribute(button,kAXRoleAttribute) isEqual:@"AXButton"] || ![attribute(button,kAXFocusedAttribute) isEqual:@YES]) return nil;
        id title=attribute(button,kAXTitleAttribute);
        if(![title isKindOfClass:NSString.class] || ![title length]) return nil;
        // Switcher buttons expose a display name, not an app URL or PID. Only
        // use an exact, unique match; guessing an MRU order can activate the
        // wrong app after native navigation, hiding, quitting, or launching.
        NSRunningApplication *match=nil;
        for(NSRunningApplication *app in apps) {
            if(app.terminated || app.activationPolicy!=NSApplicationActivationPolicyRegular || ![app.localizedName isEqual:title]) continue;
            if(match) return nil;
            match=app;
        }
        if(!match || CFAbsoluteTimeGetCurrent()>deadline) return nil;
        SJDockTarget *target=targetForApplication(match,deadline,YES);
        if(CGRectIsEmpty(target.windowBounds) || CGRectIsInfinite(target.windowBounds)) return nil;
        (void)owner;
        return target;
    }
    (void)owner;
    return nil;
}
