// SPDX-License-Identifier: Apache-2.0
// Adapted from FasterSwiper's event.cc, gesture-serialization.cc, and
// macos-private.h. Copyright 2026 Matthew Bowen, Apache-2.0.
// See licenses/ for upstream notices. Modified: standalone horizontal-only
// test implementation with Foundation/CoreGraphics and standard C++.
#pragma once
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#include <mach/mach_time.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <map>
#include <stdexcept>
#include <vector>

namespace gesture {
constexpr double epsilon = 0.000016;
constexpr int64_t sourceTag = 0x534A414D;
constexpr double instantVelocity = 500;
constexpr double deferredFraction = 20.0 / 1000000.0;
constexpr int began=1, changed=2, ended=4, cancelled=8;
using Bytes=std::vector<uint8_t>;

struct __attribute__((packed)) QueueHeader {
    uint64_t timestamp, sender;
    uint32_t options, attributeLength, count;
};
struct __attribute__((packed)) Base {
    uint32_t size, type, options;
    uint8_t depth, reserved[3];
};
struct __attribute__((packed)) Fluid {
    Base base;
    int32_t x,y,z;
    uint32_t swipeMask;
    uint16_t motion, flavor;
    int32_t progress;
};
struct __attribute__((packed)) Velocity { Base base; int32_t x,y,z; };
static_assert(sizeof(QueueHeader)==28 && sizeof(Base)==16 && sizeof(Fluid)==40 && sizeof(Velocity)==28);

inline CGEventField field(unsigned number) { return static_cast<CGEventField>(number); }
inline int32_t fixed(double value) {
    if (!std::isfinite(value) || std::abs(value)>32767)
        throw std::runtime_error("Gesture fixed-point value out of range");
    int32_t result=static_cast<int32_t>(value*65536);
    return result==0 && value!=0 ? (value>0?1:-1) : result;
}
inline void be16(Bytes& b,uint16_t value) { b.push_back(value>>8); b.push_back(value&255); }
inline uint16_t read16(const Bytes& b,size_t offset) { return (uint16_t(b.at(offset))<<8)|b.at(offset+1); }
template<class T> inline void raw(Bytes& b,const T& value) {
    auto p=reinterpret_cast<const uint8_t*>(&value); b.insert(b.end(),p,p+sizeof(T));
}

// CoreGraphics serializes scalar fields with big-endian record headers; the
// embedded IOHID blob uses the machine's packed native layout. Preserve all
// original fields and insert/replace only the gesture payload field (4205).
inline std::map<uint16_t,Bytes> records(const Bytes& bytes) {
    if (bytes.size()<4 || bytes[0]!=0 || bytes[1]!=0 || bytes[2]!=0 || bytes[3]!=2)
        throw std::runtime_error("Unsupported CoreGraphics event serialization");
    std::map<uint16_t,Bytes> result;
    for(size_t offset=4;offset<bytes.size();) {
        if(bytes.size()-offset<4) throw std::runtime_error("Truncated event record");
        size_t count=read16(bytes,offset);
        auto tag=read16(bytes,offset+2)>>14;
        auto key=read16(bytes,offset+2)&0x3fff;
        size_t length=0;
        if(tag==0 && count>0) length=count==1?8:count;
        else if(tag==1 && count==1) length=4;
        else if(tag==3 && (count==1 || count==2)) length=count*4;
        else throw std::runtime_error("Unsupported event field encoding");
        if(length>bytes.size()-offset-4) throw std::runtime_error("Truncated event payload");
        if(result.count(key)) throw std::runtime_error("Duplicate event field");
        result[key]=Bytes(bytes.begin()+offset,bytes.begin()+offset+4+length);
        offset+=4+length;
    }
    return result;
}
inline Bytes augment(const Bytes& original,const Bytes& hid) {
    auto fields=records(original);
    if(hid.empty() || hid.size()>65535) throw std::runtime_error("Invalid HID blob size");
    Bytes encoded; be16(encoded,hid.size()); be16(encoded,4205);
    encoded.insert(encoded.end(),hid.begin(),hid.end()); fields[4205]=encoded;
    Bytes out{0,0,0,2};
    for(auto& [key,value]:fields) out.insert(out.end(),value.begin(),value.end());
    return out;
}
inline Bytes hidPayload(CGEventRef event,int phase,double progress,double velocity,bool hasVelocity) {
    QueueHeader header{CGEventGetTimestamp(event),0,0,0,1};
    if(!header.timestamp) header.timestamp=mach_absolute_time();
    bool includeVelocity=(hasVelocity && velocity!=0) || phase==ended;
    if(includeVelocity) header.count=2;
    Fluid fluid{{40,23,uint32_t((phase&255)<<24),0,{0,0,0}},0,0,0,0,1,3,fixed(progress)};
    Bytes out; raw(out,header); raw(out,fluid);
    if(includeVelocity) {
        Velocity data{{28,9,0,1,{0,0,0}},fixed(velocity),0,0}; raw(out,data);
    }
    return out;
}
inline CGEventRef create(int phase,double progress,double velocity,bool hasVelocity,
                         bool natural,CGPoint location,
                         NSInteger systemMajor=NSProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
    // macOS 27 reverses the payload sign when natural scrolling is enabled.
    // Explicit version injection lets non-input tests check both OS formats.
    if(systemMajor>=27 && natural) { progress=-progress; velocity=-velocity; }
    CGEventSourceRef source=CGEventSourceCreate(kCGEventSourceStatePrivate);
    if(!source) throw std::runtime_error("Cannot create CoreGraphics event source");
    CGEventSourceSetUserData(source,sourceTag);
    CGEventRef event=CGEventCreate(source);
    CFRelease(source);
    if(!event) throw std::runtime_error("Cannot create CoreGraphics event");
    try {
        CGEventSetIntegerValueField(event,field(55),30);
        CGEventSetIntegerValueField(event,field(110),23);
        CGEventSetIntegerValueField(event,field(132),phase);
        CGEventSetIntegerValueField(event,field(123),1);
        CGEventSetDoubleValueField(event,field(124),progress);
        if(hasVelocity) CGEventSetDoubleValueField(event,field(129),velocity);
        CGEventSetLocation(event,location);
        CFDataRef serialized=CGEventCreateData(nullptr,event);
        if(!serialized) throw std::runtime_error("Cannot serialize gesture event");
        Bytes bytes(CFDataGetBytePtr(serialized),CFDataGetBytePtr(serialized)+CFDataGetLength(serialized));
        CFRelease(serialized);
        auto out=augment(bytes,hidPayload(event,phase,progress,velocity,hasVelocity));
        CFDataRef data=CFDataCreate(nullptr,out.data(),out.size());
        CGEventRef augmented=CGEventCreateFromData(nullptr,data);
        CFRelease(data);
        if(!augmented) throw std::runtime_error("CoreGraphics rejected augmented gesture");
        // Deserialization drops the source metadata. Restore it so our event
        // tap can distinguish this gesture from a physical trackpad gesture.
        CGEventSourceRef taggedSource=CGEventSourceCreate(kCGEventSourceStatePrivate);
        if(!taggedSource) { CFRelease(augmented); throw std::runtime_error("Cannot tag gesture source"); }
        CGEventSourceSetUserData(taggedSource,sourceTag);
        CGEventSetSource(augmented,taggedSource);
        CFRelease(taggedSource);
        CFRelease(event); return augmented;
    } catch(...) { CFRelease(event); throw; }
}
inline double eased(double fraction) {
    double t=std::clamp(fraction,0.0,1.0); return 1-(1-t)*(1-t);
}
inline double progress(int direction,size_t count,double fraction) {
    if((direction!=1 && direction!=-1) || count<2) throw std::runtime_error("Invalid adjacent-space movement");
    // Keep just short of the destination until the final End event commits it.
    return direction*std::min(eased(fraction),1-deferredFraction)*double(count)/double(count-1);
}
}
