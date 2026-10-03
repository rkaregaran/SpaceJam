// SPDX-License-Identifier: MIT
#import <Foundation/Foundation.h>

// Return the next adjacent direction only when the entire route is ordinary
// desktops on this display. Zero means leave the click to Dock.
static inline int SJDockDirection(NSArray<NSDictionary *> *spaces, NSUInteger current, int64_t destination) {
    if(current>=spaces.count || !destination) return 0;
    NSInteger target=-1;
    NSMutableSet *identifiers=[NSMutableSet set];
    for(NSUInteger i=0;i<spaces.count;i++) {
        id space=spaces[i];
        if(![space isKindOfClass:NSDictionary.class]) return 0;
        id sid=space[@"ManagedSpaceID"];
        if(![sid isKindOfClass:NSNumber.class] || [identifiers containsObject:sid]) return 0;
        [identifiers addObject:sid];
        if([sid longLongValue]==destination) target=i;
    }
    if(target<0 || target==NSInteger(current)) return 0;
    for(NSInteger i=MIN(NSInteger(current),target);i<=MAX(NSInteger(current),target);i++) {
        id type=spaces[i][@"type"];
        if(![type isKindOfClass:NSNumber.class] || [type intValue]!=0) return 0;
    }
    return target>NSInteger(current)?1:-1;
}
