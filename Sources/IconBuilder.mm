// SPDX-License-Identifier: MIT
#import <AppKit/AppKit.h>
#include <initializer_list>
int main(int argc, char **argv) {
    @autoreleasepool {
        if(argc!=2) return 1;
        NSString *folder=[NSString stringWithUTF8String:argv[1]];
        [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        for(int size:{16,32,128,256,512}) for(int scale:{1,2}) {
            int pixels=size*scale;
            NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr pixelsWide:pixels pixelsHigh:pixels
                bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState]; NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
            NSAffineTransform *transform=NSAffineTransform.transform; [transform scaleBy:pixels/1024.0]; [transform concat];
            NSBezierPath *base=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(40,40,944,944) xRadius:210 yRadius:210];
            NSGradient *gradient=[[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.22 green:0.25 blue:0.92 alpha:1]
                endingColor:[NSColor colorWithSRGBRed:0.10 green:0.75 blue:0.75 alpha:1]];
            [gradient drawInBezierPath:base angle:35];
            [[NSColor colorWithWhite:1 alpha:0.24] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(160,360,580,390) xRadius:48 yRadius:48] fill];
            [[NSColor colorWithWhite:1 alpha:0.96] setStroke];
            NSBezierPath *front=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(284,246,580,390) xRadius:48 yRadius:48];
            front.lineWidth=24; [front stroke];
            NSBezierPath *arrow=NSBezierPath.bezierPath;
            [arrow moveToPoint:NSMakePoint(400,443)]; [arrow lineToPoint:NSMakePoint(724,443)];
            [arrow moveToPoint:NSMakePoint(633,532)]; [arrow lineToPoint:NSMakePoint(724,443)]; [arrow lineToPoint:NSMakePoint(633,354)];
            arrow.lineWidth=38; arrow.lineCapStyle=NSLineCapStyleRound; arrow.lineJoinStyle=NSLineJoinStyleRound; [arrow stroke];
            [NSGraphicsContext restoreGraphicsState];
            NSString *name=[NSString stringWithFormat:@"icon_%dx%d%@.png",size,size,scale==2?@"@2x":@""];
            NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if(![png writeToFile:[folder stringByAppendingPathComponent:name] atomically:YES]) return 1;
        }
        return 0;
    }
}
