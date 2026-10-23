#import <UIKit/UIKit.h>

@interface DYYYPanelBlur : NSObject
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)synchronizeView:(UIView *)view;
+ (void)restoreController:(UIViewController *)controller;
+ (void)restoreView:(UIView *)view;
+ (BOOL)isManagedEffectView:(UIView *)view;
+ (void)refreshVisiblePanels;
@end

@interface DYYYPanelBlur (Hooks)
+ (void)installHooks;
@end
