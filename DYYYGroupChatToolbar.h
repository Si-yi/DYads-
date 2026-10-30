#import <UIKit/UIKit.h>
@interface DYYYGroupChatToolbar : NSObject
+ (UIView *)nativeDetailViewForComponent:(id)component original:(UIView *)view;
+ (void)captureToggle:(UIView *)view component:(id)component;
+ (void)captureZone:(id)component;
+ (BOOL)hiddenForComponent:(id)component;
+ (BOOL)isToggleView:(UIView *)view;
+ (void)synchronizeHost:(UIViewController *)host;
+ (void)synchronizeEntry:(UIView *)view;
+ (BOOL)blocksEntry:(UIView *)view;
+ (void)refreshVisible;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYGroupChatToolbar (Hooks)
+ (void)installHooks;
@end
