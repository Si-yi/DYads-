#import <UIKit/UIKit.h>

@class AWESettingItemModel;
@class AWESettingSectionModel;
@class LynxUI;

// 搜索页功能移植自 DYKiller，许可与作者信息保留于实现文件。
@interface DYYYSearchClean : NSObject
+ (NSArray<NSDictionary *> *)rankCatalog;
+ (void)recordRanks:(NSArray<NSDictionary *> *)entries;
+ (NSString *)rankHideKey:(NSString *)rankID;
+ (BOOL)rankHidden:(NSString *)rankID;
+ (NSArray *)visibleRanks:(NSArray *)tabs identifier:(NSString *(^)(id))identifier;
+ (BOOL)templateURL:(NSString *)url matchesBundle:(NSString *)bundle;
+ (NSDictionary *)cleanGlobalProps:(NSDictionary *)props url:(NSString *)url;
+ (NSInteger)cameraMode;
+ (UIView *)existingCameraForOwner:(id)owner;
+ (void)applyCamera:(UIView *)view;
+ (BOOL)removeRankFooter;
+ (BOOL)isFooterTarget:(LynxUI *)ui;
+ (void)updateFooter:(LynxUI *)ui label:(NSString *)label;
+ (void)applyFooter:(LynxUI *)ui;
+ (NSArray<AWESettingItemModel *> *)settingsItemsWithRootViewController:(UIViewController *)rootVC;
@end

@interface DYYYSearchClean (Hooks)
+ (void)installHooks;
@end
