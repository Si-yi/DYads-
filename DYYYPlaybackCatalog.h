#import <UIKit/UIKit.h>
@class AWESettingItemModel;

@interface DYYYPlaybackCatalog : NSObject
+ (void)prepareStack:(UIView *)stack;
// -1 表示不接管；0/1/2 为显示、隐藏（保留占位）、移除（收起行）。
+ (NSInteger)cachedModeForRow:(UIView *)row;
+ (void)refresh;
+ (NSArray<AWESettingItemModel *> *)settingsItemsWithRoot:(UIViewController *)root;
+ (NSDictionary *)diagnostics;
@end
