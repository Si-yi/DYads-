#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class AWESettingSectionModel;

/// 自动消息与好友分享进推荐的设置、配置和运行入口。
@interface DYYYAutoMessage : NSObject
+ (NSMutableArray<NSMutableDictionary *> *)messageConfigs;
+ (void)saveMessageConfigs:(NSArray *)configs;
/// 返回匹配配置数；账户变化或参数无效时返回 NSNotFound。
+ (NSUInteger)updateText:(NSString *)text randomText:(BOOL)randomText userIDs:(NSSet<NSString *> *)userIDs ownerID:(NSString *)ownerID;
+ (NSMutableArray<NSMutableDictionary *> *)noSendTimePeriods;
+ (void)saveNoSendTimePeriods:(NSArray *)periods;
+ (NSString *)noSendTimeSummary;
+ (NSString *)imageDirectory;
+ (void)resolveRecipient:(NSString *)input completion:(void (^)(NSDictionary *recipient, NSString *error))completion;
+ (NSString *)renderMessageForConfig:(NSDictionary *)config;
+ (void)sendConfig:(NSDictionary *)config manualTest:(BOOL)manualTest completion:(void (^)(BOOL success, NSString *reason))completion;
+ (void)sendConfig:(NSDictionary *)config completion:(void (^)(BOOL success, NSString *reason))completion;
+ (void)editConfigFrom:(UIViewController *)root existing:(NSMutableDictionary *)existing completion:(void (^)(void))completion;
+ (BOOL)openNativeChatForUserID:(NSString *)userID message:(NSString *)message;
+ (void)loadMutualFriends:(void (^)(NSArray<NSDictionary *> *friends))completion;

+ (NSArray<AWESettingSectionModel *> *)settingsSectionsWithRootViewController:(UIViewController *)rootViewController;
+ (void)runDailyMessageCheckIfNeeded;
+ (void)scanFriendSharesWithToast:(BOOL)showToast;

@end



