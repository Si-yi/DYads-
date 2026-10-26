#import <UIKit/UIKit.h>

@interface DYYYDetailCaptionLayout : NSObject
+ (void)synchronizeStack:(UIView *)stack;
+ (void)beginStackLayout:(UIView *)stack;
+ (void)endStackLayout:(UIView *)stack;
+ (void)restoreStack:(UIView *)stack;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)beginControllerLayout:(UIViewController *)controller;
+ (void)endControllerLayout:(UIViewController *)controller;
+ (void)synchronizePageController:(UIViewController *)page;
+ (void)restoreController:(UIViewController *)controller;
+ (void)synchronizeInputRoot:(UIView *)root;
+ (NSDictionary *)diagnostics;
@end
