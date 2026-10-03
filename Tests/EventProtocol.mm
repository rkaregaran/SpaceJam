// SPDX-License-Identifier: Apache-2.0
// Adapted from the SpaceJam prototype; FasterSwiper notices apply to the protocol.
#import <AppKit/AppKit.h>
#include "../Sources/ThirdParty/GestureEvents.h"
static int selfTest() {
    int cases=0;
    for(bool natural:{false,true}) for(int direction:{-1,1}) for(int phase:{1,2,4,8}) {
        double progress=phase==2?gesture::progress(direction,3,0.5):gesture::epsilon*direction;
        double velocity=phase==4?gesture::instantVelocity*direction:0;
        CGEventRef event=gesture::create(phase,progress,velocity,phase==4,natural,CGPointZero);
        CFDataRef data=CGEventCreateData(nullptr,event);
        gesture::Bytes bytes(CFDataGetBytePtr(data),CFDataGetBytePtr(data)+CFDataGetLength(data));
        auto fields=gesture::records(bytes);
        auto blob=fields.at(4205); size_t expected=phase==4?100:72;
        if(blob.size()!=expected) throw std::runtime_error("Wrong HID payload length");
        gesture::QueueHeader header; std::memcpy(&header,blob.data()+4,28);
        gesture::Fluid fluid; std::memcpy(&fluid,blob.data()+32,40);
        double signedProgress=progress;
        if(@available(macOS 27.0,*)) { if(natural) signedProgress=-progress; }
        if(header.count!=(phase==4?2:1) || fluid.base.type!=23 || fluid.flavor!=3 || fluid.progress!=gesture::fixed(signedProgress))
            throw std::runtime_error("HID payload mismatch");
        if(CGEventGetIntegerValueField(event,kCGEventSourceUserData)!=gesture::sourceTag ||
           CGEventGetIntegerValueField(event,gesture::field(132))!=phase ||
           std::abs(CGEventGetDoubleValueField(event,gesture::field(124))-signedProgress)>1e-8)
            throw std::runtime_error("Gesture fields failed round trip: source="+std::to_string(CGEventGetIntegerValueField(event,kCGEventSourceUserData))+" phase="+std::to_string(CGEventGetIntegerValueField(event,gesture::field(132)))+" progress="+std::to_string(CGEventGetDoubleValueField(event,gesture::field(124))));
        CFRelease(data); CFRelease(event); cases++;
    }
    for(gesture::Bytes broken: {gesture::Bytes{},gesture::Bytes{0,0,0,3},gesture::Bytes{0,0,0,2,0}}) {
        bool refused=false; try { gesture::records(broken); } catch(...) { refused=true; }
        if(!refused) throw std::runtime_error("Malformed event accepted"); cases++;
    }
    if(gesture::progress(1,2,1)>=2 || gesture::eased(0)!=0 || gesture::eased(1)!=1)
        throw std::runtime_error("Premature gesture commit or bad easing");
    printf("PASS: %d event serialization cases; both directions, natural scrolling, phases, and malformed-data refusal. No events posted.\n",cases);
    printf("Accessibility trusted: %s\n",AXIsProcessTrusted()?"yes":"no");
    return 0;
}

int main() { @autoreleasepool { try { return selfTest(); }
catch(const std::exception& error) { fprintf(stderr,"FAIL: %s\n",error.what()); return 1; } } }
