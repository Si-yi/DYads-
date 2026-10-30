#import <UIKit/UIKit.h>

@interface DYYYChatChrome : NSObject
+ (UIColor *)nativeBackgroundColor:(UIColor *)color forBar:(UIView *)bar;
+ (BOOL)nativeOpaque:(BOOL)opaque forBar:(UIView *)bar;
+ (void)preparePreferences;
+ (id)beginTopUpdate:(UIView *)view;
+ (void)endTopUpdate:(id)token;
+ (void)synchronizeTopForView:(UIView *)view;
+ (void)scheduleTopSynchronization:(UIView *)view;
+ (void)synchronizeBar:(UIView *)bar;
+ (void)synchronizePanel:(UIView *)panel;
+ (void)synchronizeInput:(UIViewController *)input;
+ (void)synchronizeHost:(UIViewController *)host;
+ (void)restoreHost:(UIViewController *)host;
+ (void)refreshVisibleViews;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYChatChrome (Hooks)
+ (void)installHooks;
@end
