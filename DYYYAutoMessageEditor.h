#import <UIKit/UIKit.h>

/// 自动消息的添加窗口及按好友配置的文字、图片编辑窗口。
@interface DYYYAutoMessageEditor : UIViewController
+ (void)showFrom:(UIViewController *)presenter config:(NSDictionary *)config completion:(void (^)(void))completion;
+ (void)showBatchFrom:(UIViewController *)presenter userIDs:(NSArray<NSString *> *)userIDs ownerID:(NSString *)ownerID completion:(void (^)(void))completion;
+ (void)showHelpFrom:(UIViewController *)presenter;
@end
