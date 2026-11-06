#import <UIKit/UIKit.h>
@interface DYYYMessageListStyle : NSObject
+ (void)preparePreferences;
+ (BOOL)cardsEnabled;
+ (BOOL)topEnabled;
+ (BOOL)usesCardsForCell:(UITableViewCell *)cell;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)synchronizeCell:(UITableViewCell *)cell;
+ (void)resetCell:(UITableViewCell *)cell;
+ (void)synchronizeBar:(UIView *)bar;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
