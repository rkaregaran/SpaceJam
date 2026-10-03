// SPDX-License-Identifier: MIT
#import <AppKit/AppKit.h>
@interface SJAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate>
- (void)showSettings:(id)sender;
- (void)closeSettings:(id)sender;
@property(nonatomic) BOOL preview;
@property(nonatomic, copy) NSString *previewFolder;
@end
