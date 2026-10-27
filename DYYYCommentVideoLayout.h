#import <UIKit/UIKit.h>

@interface DYYYCommentVideoLayout : NSObject
+ (BOOL)enabled;
+ (CGRect)adjustedFrame:(CGRect)frame view:(UIView *)view;
+ (BOOL)freezeController:(UIViewController *)controller;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)didMagnifyController:(UIViewController *)controller;
+ (void)refreshVisiblePlayers;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYCommentVideoLayout (Hooks)
+ (void)installHooks;
@end
