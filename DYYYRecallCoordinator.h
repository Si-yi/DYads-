#import <UIKit/UIKit.h>
@class AWESettingItemModel;

@interface DYYYRecallCoordinator : NSObject
+ (void)installHooks;
+ (BOOL)enabled;
+ (void)settingsChanged;
+ (void)bindModel:(id)model root:(id)root;
+ (void)captureContent:(id)content model:(id)model;
+ (void)observeRecalled:(BOOL)recalled model:(id)model;
+ (BOOL)protectModel:(id)model;
+ (NSDictionary *)protectedContentForModel:(id)model;
+ (id)replacementForUIMessage:(id)message;
+ (id)mediaPathForUIMessage:(id)message original:(id)original;
+ (id)mediaPathsForUIMessage:(id)message original:(id)original;
+ (void)mediaDownloadCompleted:(id)model;
+ (void)captureCell:(UITableViewCell *)cell;
+ (void)resetCell:(UITableViewCell *)cell;
+ (void)controllerAppeared:(UIViewController *)controller;
+ (void)recordHook:(NSString *)name installed:(BOOL)installed;
+ (NSArray<AWESettingItemModel *> *)settingsItems;
+ (NSDictionary *)diagnostics;
@end
