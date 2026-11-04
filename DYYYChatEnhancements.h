#import <UIKit/UIKit.h>
@class AWESettingItemModel;

@interface DYYYChatEnhancements : NSObject
+ (BOOL)enabled:(NSString *)key;
+ (void)installHooks;
+ (void)cellChanged:(UIView *)cell;
+ (void)controllerAppeared:(UIViewController *)controller;
+ (void)recordCapability:(NSString *)name available:(BOOL)available;
+ (void)recordEvent:(NSString *)name;
+ (NSArray<AWESettingItemModel *> *)settingsItems;
+ (NSDictionary *)diagnostics;
@end
