#import <UIKit/UIKit.h>

/// 自动消息配置和互关好友选择共用的玻璃弹窗。
@interface DYYYAutoMessagePanel : UIViewController
+ (void)showConfigsFrom:(UIViewController *)presenter;
+ (void)showFriendsFrom:(UIViewController *)presenter selectedIDs:(NSArray<NSString *> *)ids
             completion:(void (^)(NSArray<NSDictionary *> *friends))completion;
@end
