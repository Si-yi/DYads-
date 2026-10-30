#import <Foundation/Foundation.h>

/// 只连接抖音自己的 IM 实例，不加载或调用 AutoMessagePlugin。
@interface DYYYIMService : NSObject
+ (void)captureService:(id)service role:(NSString *)role;
+ (id)contactDatabase;
+ (NSDictionary *)diagnostics;
+ (NSString *)accountID;
/// 仅从抖音已创建的账户实例取值，自动检查不可唤起服务容器。
+ (NSString *)capturedAccountID;
+ (void)observeTextModel:(id)model sender:(id)sender;
+ (void)observeConversationSend:(id)model conversation:(id)conversation;
+ (void)observeHistoryQuery:(id)conversation manager:(id)manager;
+ (void)observeHistoryResults:(id)results manager:(id)manager;
+ (void)observeMessage:(id)message conversation:(id)conversation error:(id)error;
+ (void)sendText:(NSString *)text toUserID:(NSString *)userID completion:(void (^)(BOOL success, NSString *reason))completion;
+ (void)sendText:(NSString *)text toUserID:(NSString *)userID manualTest:(BOOL)manualTest completion:(void (^)(BOOL success, NSString *reason))completion;
+ (NSString *)dailyStateForUserID:(NSString *)userID;
+ (void)unreadSharesForUsers:(NSArray<NSString *> *)userIDs revalidatingRows:(NSArray<NSDictionary *> *)rows
                 completion:(void (^)(NSArray<NSDictionary *> *shares, NSArray<NSDictionary *> *rejectedRows, NSString *warning))completion;
@end

