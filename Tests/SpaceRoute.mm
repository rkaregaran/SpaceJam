// SPDX-License-Identifier: MIT
#import "../Sources/SpaceRoute.h"
static void require(BOOL condition, const char *message) { if(!condition) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
int main() { @autoreleasepool {
    NSArray *ordinary=@[@{@"ManagedSpaceID":@4,@"type":@0},@{@"ManagedSpaceID":@5,@"type":@0},@{@"ManagedSpaceID":@9,@"type":@0}];
    require(SJDockDirection(ordinary,0,5)==1,"adjacent destination to right");
    require(SJDockDirection(ordinary,2,4)==-1,"distant destination to left");
    require(SJDockDirection(ordinary,0,9)==1,"distant destination to right");
    require(SJDockDirection(ordinary,1,5)==0,"same desktop stays native");
    require(SJDockDirection(ordinary,0,12)==0,"destination on another display stays native");
    require(SJDockDirection(ordinary,99,5)==0,"invalid current index stays native");
    require(SJDockDirection(@[],0,5)==0,"empty desktop list stays native");
    NSArray *fullscreen=@[@{@"ManagedSpaceID":@4,@"type":@0},@{@"ManagedSpaceID":@5,@"type":@4},@{@"ManagedSpaceID":@9,@"type":@0}];
    require(SJDockDirection(fullscreen,0,9)==0,"cannot traverse fullscreen desktop");
    require(SJDockDirection(fullscreen,0,5)==0,"fullscreen destination stays native");
    require(SJDockDirection(fullscreen,1,9)==0,"fullscreen source stays native");
    require(SJDockDirection(@[@{@"ManagedSpaceID":@4,@"type":@0},@{@"ManagedSpaceID":@5}],0,5)==0,"missing type stays native");
    require(SJDockDirection(@[@{@"ManagedSpaceID":@4,@"type":@0},@{@"ManagedSpaceID":@4,@"type":@0}],0,4)==0,"duplicate identifiers stay native");
    require(SJDockDirection((id)@[@4],0,4)==0,"malformed metadata stays native");
    printf("PASS: 13 Dock route cases; adjacent/distant, same/other display, fullscreen, malformed metadata. No events posted.\n");
} }
