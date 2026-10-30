#import <UIKit/UIKit.h>
@interface DYYYGroupChatToolbar : NSObject
+ (id)nativeNavigationComponents:(id)components host:(UIViewController *)host;
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
