#import <UIKit/UIKit.h>

@interface DYYYChatInputGlass : NSObject
+ (void)beginUpdate:(UIViewController *)controller;
+ (void)endUpdate:(UIViewController *)controller;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)repairController:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (NSDictionary *)diagnostics;
@end

@interface DYYYChatInputGlass (Hooks)
+ (void)installHooks;
@end
