#import <UIKit/UIKit.h>

// 调试工具的弹层跟随系统场景主题，不继承抖音窗口固定的浅色设置。
@interface DYYYDebugAppearance : NSObject
+ (void)prepareController:(UIViewController *)controller sourceWindow:(UIWindow *)window;
+ (void)refreshPresentedControllers;
@end
