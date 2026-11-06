#import <UIKit/UIKit.h>
@interface DYYYMessageListStyle : NSObject
+ (void)preparePreferences;
+ (BOOL)cardsEnabled;
+ (BOOL)topEnabled;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)synchronizeCell:(UITableViewCell *)cell;
+ (void)resetCell:(UITableViewCell *)cell;
+ (void)prepareCellLayout:(UITableViewCell *)cell;
+ (void)synchronizeBar:(UIView *)bar;
+ (void)scheduleBarSynchronization:(UIView *)bar;
+ (UIColor *)nativeBackgroundColor:(UIColor *)color forBar:(UIView *)bar;
+ (BOOL)nativeOpaque:(BOOL)opaque forBar:(UIView *)bar;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
