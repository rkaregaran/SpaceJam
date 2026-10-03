// SPDX-License-Identifier: MIT
#import "../Sources/SwitchEngine.h"
#import "../Sources/ThirdParty/GestureEvents.h"
@interface SJSwitchEngine (TestRouting)
- (CGEventRef)process:(CGEventType)type event:(CGEventRef)event;
- (CGEventRef)handleCommandRelease:(CGEventRef)event;
- (BOOL)move:(int)direction;
@end
@interface RoutingEngine : SJSwitchEngine
@property(nonatomic) NSUInteger releases;
@end
@implementation RoutingEngine
- (CGEventRef)handleCommandRelease:(CGEventRef)event {
    [self setValue:@NO forKey:@"commandTabOpen"]; self.releases++; return nullptr;
}
- (BOOL)move:(int)direction { return NO; }
@end
static void require(BOOL condition,const char *message) { if(!condition) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static CGEventRef input(CGEventType type,CGKeyCode key,CGEventFlags flags) {
    CGEventRef event=CGEventCreateKeyboardEvent(nullptr,key,type==kCGEventKeyDown);
    CGEventSetType(event,type); CGEventSetFlags(event,flags); return event;
}
static BOOL send(RoutingEngine *engine,CGEventType type,CGKeyCode key,CGEventFlags flags) {
    CGEventRef event=input(type,key,flags); BOOL passed=[engine process:type event:event]==event; CFRelease(event); return passed;
}
static void tab(RoutingEngine *engine,CGEventFlags flags=kCGEventFlagMaskCommand) {
    require(send(engine,kCGEventKeyDown,48,flags),"native switcher gets Tab down");
    require(send(engine,kCGEventKeyUp,48,flags),"native switcher gets Tab up");
}
static void release(RoutingEngine *engine,NSUInteger expected,CGKeyCode key=55,CGEventFlags flags=0) {
    send(engine,kCGEventFlagsChanged,key,flags); require(engine.releases==expected,"only supported final Command release is held");
}
int main() { @autoreleasepool {
    RoutingEngine *engine=[RoutingEngine new]; [engine setValue:@YES forKey:@"running"];
    tab(engine); release(engine,1); release(engine,1);
    tab(engine,kCGEventFlagMaskCommand|kCGEventFlagMaskShift); release(engine,2,54);
    tab(engine); send(engine,kCGEventKeyDown,123,kCGEventFlagMaskCommand); release(engine,3);
    tab(engine); send(engine,kCGEventKeyDown,124,kCGEventFlagMaskCommand); release(engine,4);
    tab(engine); release(engine,4,54,kCGEventFlagMaskCommand); release(engine,5);
    tab(engine); send(engine,kCGEventKeyDown,53,kCGEventFlagMaskCommand); release(engine,5);
    tab(engine); send(engine,kCGEventKeyDown,12,kCGEventFlagMaskCommand); release(engine,5);
    tab(engine); send(engine,kCGEventLeftMouseDown,0,kCGEventFlagMaskCommand); release(engine,5);
    tab(engine); send(engine,kCGEventRightMouseDown,0,kCGEventFlagMaskCommand); release(engine,5);
    tab(engine); send(engine,kCGEventScrollWheel,0,kCGEventFlagMaskCommand); release(engine,5);
    tab(engine,0); release(engine,5);
    tab(engine,kCGEventFlagMaskCommand|kCGEventFlagMaskAlternate); release(engine,5);
    tab(engine,kCGEventFlagMaskCommand|kCGEventFlagMaskControl); release(engine,5);
    tab(engine); release(engine,5,55,kCGEventFlagMaskAlternate);
    tab(engine); engine.commandTabs=NO; release(engine,5); tab(engine); release(engine,5);
    engine.commandTabs=YES;
    CGEventRef tagged=input(kCGEventKeyDown,48,kCGEventFlagMaskCommand);
    CGEventSetIntegerValueField(tagged,kCGEventSourceUserData,gesture::sourceTag);
    require([engine process:kCGEventKeyDown event:tagged]==tagged,"own event passes through"); CFRelease(tagged); release(engine,5);
    [engine setValue:@NO forKey:@"running"]; tab(engine); release(engine,5);
    SJSwitchEngine *nativeFallback=[SJSwitchEngine new]; [nativeFallback setValue:@YES forKey:@"running"];
    CGEventRef unresolved=input(kCGEventFlagsChanged,55,0);
    require([nativeFallback handleCommandRelease:unresolved]==unresolved,"unresolved quick tap keeps the original release");
    nativeFallback.commandTabs=NO;
    require([nativeFallback handleCommandRelease:unresolved]==unresolved,"disabled feature keeps the original release"); CFRelease(unresolved);
    printf("PASS: Command–Tab routing; forward/reverse, arrows, both Command keys, Escape, other keys, mouse, modifiers, disabled and tagged events. No input posted.\n");
} }
