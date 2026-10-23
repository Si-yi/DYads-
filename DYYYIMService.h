#import <Foundation/Foundation.h>

/// 只连接抖音自己的 IM 实例，不加载或调用 AutoMessagePlugin。
@interface DYYYIMService : NSObject
+ (void)captureService:(id)service role:(NSString *)role;
+ (id)contactDatabase;
+ (NSString *)accountID;
+ (void)observeTextModel:(id)model sender:(id)sender;
+ (void)observeHistoryQuery:(id)conversation manager:(id)manager;
+ (void)observeMessage:(id)message conversation:(id)conversation error:(id)error;
+ (void)sendText:(NSString *)text toUserID:(NSString *)userID completion:(void (^)(BOOL success, NSString *reason))completion;
+ (NSString *)dailyStateForUserID:(NSString *)userID;
+ (NSArray<NSDictionary *> *)unreadSharesForUsers:(NSArray<NSString *> *)userIDs error:(NSString **)error;
@end

