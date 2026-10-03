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
BOOL SJDockTargetStillValid(SJDockTarget *target) {
    NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:target.pid];
    NSArray *spaces=spacesForWindow(target.window);
    return app && !app.terminated && spaces.count==1 && [spaces.firstObject isEqual:@(target.space)];
}
SJDockTarget *SJDockTargetAtPoint(CGPoint point) {
    CFAbsoluteTime deadline=CFAbsoluteTimeGetCurrent()+0.08;
    Boolean exists=false;
    Boolean swoosh=CFPreferencesGetAppBooleanValue(CFSTR("workspaces-auto-swoosh"),CFSTR("com.apple.dock"),&exists);
    if(exists && !swoosh) return nil;
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
    AXUIElementRef application=AXUIElementCreateApplication(app.processIdentifier);
    AXUIElementSetMessagingTimeout(application,0.04);
    // Some apps omit off-Space windows from AXWindows on macOS 27. Their
    // focused/main window still identifies the last app window. WindowServer
    // also lists app rendering surfaces, so use AX windows for ambiguity checks.
    id window=attribute(application,kAXFocusedWindowAttribute)?:attribute(application,kAXMainWindowAttribute);
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
    (void)element;
    if(!destination || CFAbsoluteTimeGetCurrent()>deadline) return nil;
    SJDockTarget *target=[SJDockTarget new];
    target.pid=app.processIdentifier; target.window=selected; target.space=destination; target.bounds=bounds;
    return target;
}
