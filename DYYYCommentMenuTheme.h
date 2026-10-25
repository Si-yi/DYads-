#import <UIKit/UIKit.h>

// 仅管理评论长按菜单自身的主题，不修改窗口或评论输入框。
@interface DYYYCommentMenuTheme : NSObject
+ (UIUserInterfaceStyle)prepareController:(UIViewController *)controller;
+ (UIUserInterfaceStyle)styleForController:(UIViewController *)controller;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (UIViewController *)controllerForView:(UIView *)view;
+ (UIViewController *)menuControllerForController:(UIViewController *)controller;
@end

@interface DYYYCommentMenuTheme (Hooks)
+ (void)installHooks;
+ (void)installLayoutHooksForController:(UIViewController *)controller;
@end
