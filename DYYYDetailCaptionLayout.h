#import <UIKit/UIKit.h>

@interface DYYYDetailCaptionLayout : NSObject
+ (void)beginStackLayout:(UIView *)stack;
+ (void)endStackLayout:(UIView *)stack;
+ (void)restoreStack:(UIView *)stack;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (void)synchronizeInputRoot:(UIView *)root;
+ (NSDictionary *)diagnostics;
@end
