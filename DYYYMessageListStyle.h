#import <UIKit/UIKit.h>
@interface DYYYMessageListStyle : NSObject
+ (void)preparePreferences;
+ (BOOL)cardsEnabled;
+ (BOOL)topEnabled;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)synchronizeCell:(UITableViewCell *)cell;
+ (void)resetCell:(UITableViewCell *)cell;
+ (BOOL)contentAdapterReady;
+ (CGRect)nativeContentFrame:(CGRect)frame forView:(UIView *)view;
+ (id)beginContentGeometry:(UIView *)view;
+ (void)endContentGeometry:(id)token;
+ (CGAffineTransform)nativeContentTransform:(CGAffineTransform)transform forView:(UIView *)view;
+ (void)didSetContentTransform:(UIView *)view;
+ (void)synchronizeBar:(UIView *)bar;
+ (void)scheduleBarSynchronization:(UIView *)bar;
+ (UIColor *)nativeBackgroundColor:(UIColor *)color forBar:(UIView *)bar;
+ (BOOL)nativeOpaque:(BOOL)opaque forBar:(UIView *)bar;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
