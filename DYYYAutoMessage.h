#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class AWESettingSectionModel;

/// 自动消息与好友分享进推荐的设置、配置和运行入口。
@interface DYYYAutoMessage : NSObject
+ (NSMutableArray<NSMutableDictionary *> *)messageConfigs;
+ (void)saveMessageConfigs:(NSArray *)configs;
+ (void)editConfigFrom:(UIViewController *)root existing:(NSMutableDictionary *)existing completion:(void (^)(void))completion;
+ (BOOL)openNativeChatForUserID:(NSString *)userID message:(NSString *)message;
+ (void)loadMutualFriends:(void (^)(NSArray<NSDictionary *> *friends))completion;

+ (NSArray<AWESettingSectionModel *> *)settingsSectionsWithRootViewController:(UIViewController *)rootViewController;
+ (void)runDailyMessageCheckIfNeeded;
+ (void)scanFriendSharesWithToast:(BOOL)showToast;

@end

