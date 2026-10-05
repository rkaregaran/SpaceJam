// SPDX-License-Identifier: Apache-2.0
// Gesture switching adapted from FasterSwiper, Copyright 2026 Matthew Bowen.
// Modified for SpaceJam: bounded queue, permission-aware listener, commit polling,
// native fallback, lifecycle cancellation, and a window-free engine.
// Upstream notices and license: ../THIRD_PARTY_NOTICES.md and ../LICENSES/.
#import "SwitchEngine.h"
#import "DockTarget.h"
#import "SpaceRoute.h"
#import <QuartzCore/QuartzCore.h>
#include <deque>
#include "ThirdParty/GestureEvents.h"
extern "C" int SLSMainConnectionID(void);
extern "C" CFArrayRef SLSCopyManagedDisplaySpaces(int);
extern "C" int64_t SLSManagedDisplayGetCurrentSpace(int,CFStringRef);

struct SpaceState {
    NSString *display;
    NSArray<NSDictionary*> *spaces;
    NSUInteger index;
    CGPoint point;
};

static bool naturalScrolling() {
    Boolean exists=false;
    Boolean natural=CFPreferencesGetAppBooleanValue(CFSTR("com.apple.swipescrolldirection"),kCFPreferencesAnyApplication,&exists);
    return exists?natural:true;
}
static bool overviewVisible() {
    NSArray *windows=CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,kCGNullWindowID));
    if(!windows) throw std::runtime_error("Cannot read the desktop state");
    for(NSDictionary *window in windows) {
        if(![window[(id)kCGWindowOwnerName] isEqualToString:@"WindowManager"]) continue;
        NSInteger layer=[window[(id)kCGWindowLayer] integerValue];
        if(layer!=14 && layer!=19 && layer!=18) continue;
        CGRect rect;
        if(!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(id)kCGWindowBounds],&rect)) continue;
        for(NSScreen *screen in NSScreen.screens) {
            NSNumber *identifier=screen.deviceDescription[@"NSScreenNumber"];
            CGRect bounds=CGDisplayBounds(identifier.unsignedIntValue);
            if(rect.size.width+1>=bounds.size.width && rect.size.height+1>=bounds.size.height) return true;
        }
    }
    return false;
}
static SpaceState loadStateAtPoint(CGPoint point) {
    if(overviewVisible()) throw std::runtime_error("Mission Control is open; using native switching");
    CGDirectDisplayID displays[16]; uint32_t count=0;
    if(CGGetDisplaysWithPoint(point,16,displays,&count)!=kCGErrorSuccess || !count)
        throw std::runtime_error("Cannot find display under mouse");
    NSMutableArray<NSString*> *identifiers=[NSMutableArray array];
    for(uint32_t i=0;i<count;i++) {
        CFUUIDRef uuid=CGDisplayCreateUUIDFromDisplayID(displays[i]);
        if(uuid) { [identifiers addObject:CFBridgingRelease(CFUUIDCreateString(nullptr,uuid))]; CFRelease(uuid); }
    }
    int cid=SLSMainConnectionID();
    NSArray *managed=CFBridgingRelease(SLSCopyManagedDisplaySpaces(cid));
    if(![managed isKindOfClass:NSArray.class]) throw std::runtime_error("Cannot read native desktop list");
    for(NSDictionary *display in managed) {
        NSString *identifier=display[@"Display Identifier"];
        bool matches=[identifiers containsObject:identifier];
        if(managed.count==1 && [identifier isEqualToString:@"Main"]) matches=true;
        if(!matches) continue;
        NSArray *spaces=display[@"Spaces"];
        if(![spaces isKindOfClass:NSArray.class] || spaces.count<2) throw std::runtime_error("This display needs at least two desktops");
        int64_t current=SLSManagedDisplayGetCurrentSpace(cid,(__bridge CFStringRef)identifier);
        for(NSUInteger i=0;i<spaces.count;i++) {
            NSDictionary *space=spaces[i];
            if(![space[@"ManagedSpaceID"] isKindOfClass:NSNumber.class]) throw std::runtime_error("Unexpected desktop metadata");
            if([space[@"ManagedSpaceID"] longLongValue]==current) return {identifier,spaces,i,point};
        }
    }
    throw std::runtime_error("Cannot identify the active desktop under the mouse");
}
static SpaceState loadState() {
    CGEventRef pointer=CGEventCreate(nullptr);
    if(!pointer) throw std::runtime_error("Cannot read mouse display");
    CGPoint point=CGEventGetLocation(pointer); CFRelease(pointer);
    return loadStateAtPoint(point);
}

@interface SJSwitchEngine ()
@property(nonatomic, readwrite) BOOL running;
@property(nonatomic, readwrite) BOOL animating;
@property(nonatomic, copy, readwrite) NSString *message;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) BOOL gestureOpen;
@property(nonatomic) BOOL physicalGesture;
@property(nonatomic) BOOL natural;
@property(nonatomic) int direction;
@property(nonatomic) NSUInteger count;
@property(nonatomic) CGPoint pointer;
@property(nonatomic) CFTimeInterval started;
@property(nonatomic) double seconds;
@property(nonatomic, copy) NSString *display;
@property(nonatomic) int64_t target;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) NSUInteger roundTripRemaining;
@property(nonatomic) BOOL leftHeld;
@property(nonatomic) BOOL rightHeld;
@property(nonatomic) NSUInteger clickGeneration;
@property(nonatomic) SJDockTarget *dockCandidate;
@property(nonatomic) CGPoint dockPoint;
@property(nonatomic) CFTimeInterval clickStarted;
@property(nonatomic) int64_t dockSpace;
@property(nonatomic) BOOL dockLookupBusy;
@property(nonatomic) BOOL commandTabOpen;
@property(nonatomic) BOOL commandLookupBusy;
@property(nonatomic) SJDockTarget *commandCandidate;
@property(nonatomic) NSUInteger commandGeneration;
@property(nonatomic) int64_t commandSpace;
@property(nonatomic) CGPoint commandPoint;
- (CGEventRef)handle:(CGEventType)type event:(CGEventRef)event proxy:(CGEventTapProxy)proxy;
@end

static CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    @autoreleasepool { return [(__bridge SJSwitchEngine *)context handle:type event:event proxy:proxy]; }
}

@implementation SJSwitchEngine {
    CFMachPortRef _tap;
    CFRunLoopSourceRef _source;
    std::deque<int> _pending;
    dispatch_queue_t _dockLookup;
    CGEventRef _dockRelease;
    CGEventRef _commandRelease;
    CGEventTapProxy _activeProxy;
}
- (instancetype)init {
    if ((self=[super init])) {
        _milliseconds=100; _dockClicks=YES; _commandTabs=YES; _message=@"Ready";
        _dockLookup=dispatch_queue_create("dev.rzkr.SpaceJam.dock-lookup",DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)setDockClicks:(BOOL)enabled {
    _dockClicks=enabled;
    if(!enabled) {
        self.clickGeneration++; self.dockCandidate=nil;
        if(_dockRelease) [self cancelAnimation];
    }
}
- (void)setCommandTabs:(BOOL)enabled {
    _commandTabs=enabled;
    if(!enabled) {
        self.commandTabOpen=NO; self.commandCandidate=nil; self.commandGeneration++;
        if(_commandRelease) [self cancelAnimation];
    }
}
- (void)note:(NSString *)message { self.message=message; if(self.didChange) self.didChange(); }
- (BOOL)start {
    if(self.running) return YES;
    if(!AXIsProcessTrusted()) { [self note:@"Enable Accessibility to get started."]; return NO; }
    NSInteger major=NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    if(major!=26 && major!=27) {
        [self note:@"This version supports macOS 26 and 27. Native shortcuts are active."]; return NO;
    }
    try {
        CGEventRef check=gesture::create(gesture::began,gesture::epsilon,0,false,naturalScrolling(),CGPointZero);
        CFRelease(check);
    } catch(const std::exception& error) { [self note:[NSString stringWithUTF8String:error.what()]]; return NO; }
    _tap=CGEventTapCreate(kCGSessionEventTap,kCGHeadInsertEventTap,kCGEventTapOptionDefault,
        CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventKeyUp)|CGEventMaskBit(kCGEventFlagsChanged)|CGEventMaskBit(30)|
        CGEventMaskBit(kCGEventMouseMoved)|CGEventMaskBit(kCGEventScrollWheel)|
        CGEventMaskBit(kCGEventRightMouseDown)|CGEventMaskBit(kCGEventRightMouseUp)|CGEventMaskBit(kCGEventRightMouseDragged)|
        CGEventMaskBit(kCGEventOtherMouseDown)|CGEventMaskBit(kCGEventOtherMouseUp)|CGEventMaskBit(kCGEventOtherMouseDragged)|
        CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventLeftMouseUp)|CGEventMaskBit(kCGEventLeftMouseDragged),
        tapCallback,(__bridge void *)self);
    if(!_tap) { [self note:@"macOS denied access. Check Accessibility, then try enabling again."]; return NO; }
    _source=CFMachPortCreateRunLoopSource(nullptr,_tap,0);
    if(!_source) { CFRelease(_tap); _tap=nullptr; [self note:@"Could not start SpaceJam. Native shortcuts are active."]; return NO; }
    CFRunLoopAddSource(CFRunLoopGetMain(),_source,kCFRunLoopCommonModes);
    CGEventTapEnable(_tap,true); self.running=YES;
    [self note:@"Ready for desktop switching."]; return YES;
}
- (void)releaseDockClick {
    if(!_dockRelease) return;
    CGEventSetIntegerValueField(_dockRelease,kCGEventSourceUserData,gesture::sourceTag);
    // During a new physical click, insert the old release through this tap
    // before passing on the new down; timer/lifecycle callbacks post normally.
    if(_activeProxy) CGEventTapPostEvent(_activeProxy,_dockRelease);
    else CGEventPost(kCGSessionEventTap,_dockRelease);
    CFRelease(_dockRelease); _dockRelease=nullptr; self.dockSpace=0;
}
- (void)releaseCommand {
    if(!_commandRelease) return;
    self.commandGeneration++;
    CGEventSetIntegerValueField(_commandRelease,kCGEventSourceUserData,gesture::sourceTag);
    if(_activeProxy) CGEventTapPostEvent(_activeProxy,_commandRelease);
    else CGEventPost(kCGSessionEventTap,_commandRelease);
    CFRelease(_commandRelease); _commandRelease=nullptr; self.commandSpace=0;
}
- (void)prepareCommandTarget:(NSUInteger)generation {
    if(!self.running || !self.commandTabOpen || generation!=self.commandGeneration) return;
    if(!self.commandLookupBusy) {
        self.commandLookupBusy=YES;
        __weak SJSwitchEngine *weakSelf=self;
        dispatch_async(_dockLookup,^{ @autoreleasepool {
            SJDockTarget *candidate=SJCommandTabTarget();
            dispatch_async(dispatch_get_main_queue(),^{
                SJSwitchEngine *engine=weakSelf;
                engine.commandLookupBusy=NO;
                if(engine.running && engine.commandTabOpen && generation==engine.commandGeneration)
                    engine.commandCandidate=candidate;
            });
        } });
    }
    __weak SJSwitchEngine *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [weakSelf prepareCommandTarget:generation];
    });
}
- (void)commandSelectionChanged {
    self.commandCandidate=nil;
    NSUInteger generation=++self.commandGeneration;
    __weak SJSwitchEngine *weakSelf=self;
    // Let Dock process native navigation before reading its new selection.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [weakSelf prepareCommandTarget:generation];
    });
}
- (CGEventRef)handleCommandRelease:(CGEventRef)event {
    SJDockTarget *candidate=self.commandCandidate;
    self.commandCandidate=nil; self.commandTabOpen=NO; self.commandGeneration++;
    // Fast taps can complete before Dock exposes a switcher. Leave the original
    // release untouched in that case; replaying it later can lose activation.
    if(!self.commandTabs || !candidate || self.animating || self.physicalGesture || !SJDockTargetStillValid(candidate)) return event;
    try {
        self.commandPoint=CGPointMake(CGRectGetMidX(candidate.windowBounds),CGRectGetMidY(candidate.windowBounds));
        SpaceState state=loadStateAtPoint(self.commandPoint);
        int direction=SJDockDirection(state.spaces,state.index,candidate.space);
        if(!direction) return event;
        _commandRelease=CGEventCreateCopy(event);
        if(!_commandRelease) return event;
        self.commandSpace=candidate.space;
        if([self move:direction] && self.animating) return nullptr;
    } catch(...) {}
    if(_commandRelease) { CFRelease(_commandRelease); _commandRelease=nullptr; self.commandSpace=0; }
    return event;
}
- (CGEventRef)handleMouse:(CGEventType)type event:(CGEventRef)event {
    if(CGEventGetIntegerValueField(event,kCGEventSourceUserData)==gesture::sourceTag) return event;
    if(type==kCGEventLeftMouseDown || type==kCGEventLeftMouseDragged) {
        self.clickGeneration++; self.dockCandidate=nil;
        if(_dockRelease) [self cancelAnimation];
        if(type==kCGEventLeftMouseDragged || !self.dockClicks || self.animating || self.physicalGesture || self.dockLookupBusy) return event;
        auto modifiers=CGEventGetFlags(event)&(kCGEventFlagMaskControl|kCGEventFlagMaskShift|kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand);
        if(modifiers || CGEventGetIntegerValueField(event,kCGMouseEventClickState)!=1) return event;
        self.dockPoint=CGEventGetLocation(event); self.clickStarted=CACurrentMediaTime();
        CGPoint point=self.dockPoint; NSUInteger click=self.clickGeneration;
        self.dockLookupBusy=YES;
        __weak SJSwitchEngine *weakSelf=self;
        dispatch_async(_dockLookup,^{ @autoreleasepool {
            SJDockTarget *target=SJDockTargetAtPoint(point);
            dispatch_async(dispatch_get_main_queue(),^{
                SJSwitchEngine *engine=weakSelf;
                engine.dockLookupBusy=NO;
                if(engine.running && engine.clickGeneration==click) engine.dockCandidate=target;
            });
        } });
        return event;
    }
    SJDockTarget *candidate=self.dockCandidate; self.dockCandidate=nil; self.clickGeneration++;
    auto modifiers=CGEventGetFlags(event)&(kCGEventFlagMaskControl|kCGEventFlagMaskShift|kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand);
    if(!self.dockClicks || !candidate || self.animating || self.physicalGesture || modifiers ||
       CACurrentMediaTime()-self.clickStarted>0.5 ||
       CGEventGetIntegerValueField(event,kCGMouseEventClickState)!=1 ||
       !CGRectContainsPoint(candidate.bounds,CGEventGetLocation(event)) || !SJDockTargetStillValid(candidate)) return event;
    try {
        SpaceState state=loadStateAtPoint(self.dockPoint);
        int direction=SJDockDirection(state.spaces,state.index,candidate.space);
        if(!direction) return event;
        _dockRelease=CGEventCreateCopy(event);
        if(!_dockRelease) return event;
        self.dockSpace=candidate.space;
        if([self move:direction] && self.animating) return nullptr;
        CFRelease(_dockRelease); _dockRelease=nullptr; self.dockSpace=0;
    } catch(...) {
        if(_dockRelease) { CFRelease(_dockRelease); _dockRelease=nullptr; self.dockSpace=0; }
        // A click that cannot be handled remains native.
    }
    return event;
}
- (CGEventRef)handle:(CGEventType)type event:(CGEventRef)event proxy:(CGEventTapProxy)proxy {
    _activeProxy=proxy;
    CGEventRef result=[self process:type event:event];
    _activeProxy=nullptr;
    return result;
}
- (CGEventRef)process:(CGEventType)type event:(CGEventRef)event {
    if(type==kCGEventTapDisabledByTimeout || type==kCGEventTapDisabledByUserInput) {
        if(_tap && self.running && AXIsProcessTrusted()) CGEventTapEnable(_tap,true);
        return event;
    }
    if(!self.running || CGEventGetIntegerValueField(event,kCGEventSourceUserData)==gesture::sourceTag) return event;
    // Deliver a held release before any new user input so keys and modifiers
    // cannot reach another app with a stale Command state.
    if(_commandRelease && (type==kCGEventKeyDown || type==kCGEventKeyUp || type==kCGEventFlagsChanged ||
       type==kCGEventLeftMouseDown || type==kCGEventLeftMouseDragged || type==kCGEventMouseMoved ||
       type==kCGEventRightMouseDown || type==kCGEventRightMouseUp || type==kCGEventRightMouseDragged ||
       type==kCGEventOtherMouseDown || type==kCGEventOtherMouseUp || type==kCGEventOtherMouseDragged ||
       type==kCGEventScrollWheel)) [self cancelAnimation];
    if(type==kCGEventRightMouseDown || type==kCGEventRightMouseUp || type==kCGEventRightMouseDragged ||
       type==kCGEventOtherMouseDown || type==kCGEventOtherMouseUp || type==kCGEventOtherMouseDragged ||
       type==kCGEventScrollWheel) {
        self.commandTabOpen=NO; self.commandCandidate=nil; self.commandGeneration++; return event;
    }
    if(type==kCGEventLeftMouseDown || type==kCGEventLeftMouseDragged) {
        self.commandTabOpen=NO; self.commandCandidate=nil; self.commandGeneration++;
    }
    if(type==kCGEventMouseMoved) { if(self.commandTabOpen) [self commandSelectionChanged]; return event; }
    if(type==kCGEventLeftMouseDown || type==kCGEventLeftMouseUp || type==kCGEventLeftMouseDragged)
        return [self handleMouse:type event:event];
    if(type==30) {
        if(CGEventGetIntegerValueField(event,kCGEventSourceUserData)==gesture::sourceTag) return event;
        if(CGEventGetIntegerValueField(event,gesture::field(110))!=23) return event;
        auto phase=CGEventGetIntegerValueField(event,gesture::field(132));
        if(phase==gesture::began) { [self cancelAnimation]; self.physicalGesture=YES; }
        else if(phase==gesture::ended || phase==gesture::cancelled) self.physicalGesture=NO;
        return event;
    }
    auto key=CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode);
    auto modifiers=CGEventGetFlags(event)&(kCGEventFlagMaskControl|kCGEventFlagMaskShift|kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand);
    if(type==kCGEventFlagsChanged) {
        if(self.commandTabOpen && !(modifiers&kCGEventFlagMaskCommand)) {
            if((key==54 || key==55) && !(modifiers&(kCGEventFlagMaskControl|kCGEventFlagMaskAlternate)))
                return [self handleCommandRelease:event];
            self.commandTabOpen=NO;
        }
        return event;
    }
    if(type==kCGEventKeyDown) {
        BOOL switcherModifiers=modifiers==kCGEventFlagMaskCommand || modifiers==(kCGEventFlagMaskCommand|kCGEventFlagMaskShift);
        if(key==48 && switcherModifiers && self.commandTabs) {
            self.commandTabOpen=YES; [self commandSelectionChanged];
        } else if(self.commandTabOpen) {
            if(switcherModifiers && (key==123 || key==124)) [self commandSelectionChanged];
            else { self.commandTabOpen=NO; self.commandCandidate=nil; self.commandGeneration++; }
        }
    }
    if(key!=123 && key!=124) return event;
    if(type==kCGEventKeyUp) {
        BOOL held=key==123?self.leftHeld:self.rightHeld;
        if(key==123) self.leftHeld=NO; else self.rightHeld=NO;
        return held?nullptr:event;
    }
    auto flags=CGEventGetFlags(event)&(kCGEventFlagMaskControl|kCGEventFlagMaskShift|kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand);
    if(flags!=kCGEventFlagMaskControl || self.physicalGesture) return event;
    if(CGEventGetIntegerValueField(event,kCGKeyboardEventAutorepeat))
        return (key==123?self.leftHeld:self.rightHeld)?nullptr:event;
    if(![self move:key==123?-1:1]) return event;
    if(key==123) self.leftHeld=YES; else self.rightHeld=YES;
    return nullptr;
}
- (BOOL)move:(int)direction {
    if(self.animating) {
        if(_pending.size()<6) _pending.push_back(direction);
        return YES;
    }
    try {
        SpaceState state=_dockRelease?loadStateAtPoint(self.dockPoint):(_commandRelease?loadStateAtPoint(self.commandPoint):loadState());
        NSInteger target=NSInteger(state.index)+direction;
        if(target<0 || target>=NSInteger(state.spaces.count)) return YES;
        for(NSUInteger i=0;i<state.spaces.count;i++) {
            if(![state.spaces[i] isKindOfClass:NSDictionary.class] ||
               ![state.spaces[i][@"ManagedSpaceID"] isKindOfClass:NSNumber.class])
                throw std::runtime_error("Unexpected desktop metadata; using native switching");
        }
        for(NSUInteger i:{state.index,NSUInteger(target)}) {
            if(![state.spaces[i][@"type"] isKindOfClass:NSNumber.class] || [state.spaces[i][@"type"] intValue]!=0)
                throw std::runtime_error("Fullscreen desktops use native switching.");
        }
        self.direction=direction; self.count=state.spaces.count; self.pointer=state.point;
        self.natural=naturalScrolling(); self.display=state.display;
        self.target=[state.spaces[target][@"ManagedSpaceID"] longLongValue];
        self.seconds=MAX(50,MIN(1000,self.milliseconds))/1000.0;
        CGEventRef begin=gesture::create(gesture::began,gesture::epsilon*direction,0,false,self.natural,self.pointer);
        CGEventPost(kCGSessionEventTap,begin); CFRelease(begin);
        self.gestureOpen=YES; self.animating=YES; self.generation++;
        self.started=CACurrentMediaTime();
        __weak SJSwitchEngine *weakSelf=self;
        self.timer=[NSTimer timerWithTimeInterval:1.0/240 repeats:YES block:^(NSTimer *timer) { [weakSelf tick]; }];
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
        return YES;
    } catch(const std::exception& error) { [self note:[NSString stringWithUTF8String:error.what()]]; return NO; }
}
- (void)post:(int)phase progress:(double)progress velocity:(double)velocity includeVelocity:(BOOL)include {
    CGEventRef event=gesture::create(phase,progress,velocity,include,self.natural,self.pointer);
    CGEventPost(kCGSessionEventTap,event); CFRelease(event);
}
- (void)tick {
    try {
        double fraction=(CACurrentMediaTime()-self.started)/self.seconds;
        [self post:gesture::changed progress:gesture::progress(self.direction,self.count,fraction) velocity:0 includeVelocity:NO];
        if(fraction>=1) {
            [self.timer invalidate]; self.timer=nil;
            [self post:gesture::ended progress:gesture::epsilon*self.direction velocity:gesture::instantVelocity*self.direction includeVelocity:YES];
            self.gestureOpen=NO;
            [self verifyCommit:self.generation deadline:CACurrentMediaTime()+0.3];
        }
    } catch(const std::exception& error) { [self stop]; [self note:[NSString stringWithUTF8String:error.what()]]; }
}
- (void)verifyCommit:(NSUInteger)generation deadline:(CFTimeInterval)deadline {
    if(!self.running || generation!=self.generation) return;
    int64_t actual=SLSManagedDisplayGetCurrentSpace(SLSMainConnectionID(),(__bridge CFStringRef)self.display);
    if(actual==self.target) {
        self.animating=NO;
        if(_dockRelease) {
            if(actual!=self.dockSpace) {
                try {
                    SpaceState state=loadStateAtPoint(self.dockPoint);
                    int next=SJDockDirection(state.spaces,state.index,self.dockSpace);
                    if(next && [self move:next] && self.animating) return;
                } catch(...) {}
            }
            [self releaseDockClick];
        }
        if(_commandRelease) {
            if(actual!=self.commandSpace) {
                try {
                    SpaceState state=loadStateAtPoint(self.commandPoint);
                    int next=SJDockDirection(state.spaces,state.index,self.commandSpace);
                    if(next && [self move:next] && self.animating) return;
                } catch(...) {}
            }
            [self releaseCommand];
        }
        if(self.roundTripRemaining && --self.roundTripRemaining==0)
            [self note:[NSString stringWithFormat:@"Round trip passed · %ld ms per move",(long)self.milliseconds]];
        else [self note:@"Ready for your next switch."];
        if(!_pending.empty()) {
            int next=_pending.front(); _pending.pop_front();
            if(![self move:next]) { _pending.clear(); self.roundTripRemaining=0; }
        }
        return;
    }
    if(CACurrentMediaTime()>=deadline) {
        [self stop]; [self note:@"The desktop did not switch. SpaceJam paused; native shortcuts are active."]; return;
    }
    __weak SJSwitchEngine *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [weakSelf verifyCommit:generation deadline:deadline];
    });
}
- (void)cancelAnimation {
    self.generation++; _pending.clear(); self.roundTripRemaining=0;
    self.clickGeneration++; self.dockCandidate=nil;
    self.commandTabOpen=NO; self.commandCandidate=nil; self.commandGeneration++;
    [self.timer invalidate]; self.timer=nil;
    if(self.gestureOpen) {
        try { [self post:gesture::cancelled progress:-gesture::epsilon*self.direction velocity:gesture::epsilon*self.direction includeVelocity:YES]; }
        catch(...) {}
    }
    self.gestureOpen=NO; self.animating=NO;
    [self releaseDockClick];
    [self releaseCommand];
}
- (void)stop {
    self.running=NO; [self cancelAnimation]; self.physicalGesture=NO;
    self.leftHeld=NO; self.rightHeld=NO;
    if(_tap) { CGEventTapEnable(_tap,false); CFMachPortInvalidate(_tap); }
    if(_source) { CFRunLoopRemoveSource(CFRunLoopGetMain(),_source,kCFRunLoopCommonModes); CFRelease(_source); _source=nullptr; }
    if(_tap) { CFRelease(_tap); _tap=nullptr; }
    [self note:@"Paused. Native desktop switching is active."];
}
- (void)testRoundTrip {
    if(!self.running || self.animating || self.physicalGesture) return;
    try {
        SpaceState state=loadState(); int direction=state.index+1<state.spaces.count?1:-1;
        if([self move:direction] && self.animating) { self.roundTripRemaining=2; _pending.push_back(-direction); }
    } catch(const std::exception& error) { [self note:[NSString stringWithUTF8String:error.what()]]; }
}
@end

int SJInspectSpaces(void) {
    try {
        SpaceState state=loadState();
        printf("Desktop count: %lu; current index: %lu\n",(unsigned long)state.spaces.count,(unsigned long)state.index);
        return 0;
    } catch(const std::exception& error) { fprintf(stderr,"%s\n",error.what()); return 1; }
}
