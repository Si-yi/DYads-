#import <UIKit/UIKit.h>

@interface DYYYFeedCardLayout : NSObject
+ (void)rememberFrame:(CGRect)frame table:(UIView *)table;
+ (void)applyFrame:(CGRect)frame table:(UIView *)table;
+ (void)layoutController:(UIViewController *)controller afterLayout:(BOOL)afterLayout;
+ (void)restoreController:(UIViewController *)controller;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
