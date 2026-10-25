#import <Foundation/Foundation.h>

/// 只接收好友当前消息直接携带的作品，不把回复/引用上下文当作新分享。
@interface DYYYIMShareParser : NSObject
+ (NSUInteger)validationVersion;
+ (BOOL)isCurrentReceipt:(id)row;
+ (NSArray<NSString *> *)directItemIDsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account;
+ (NSDictionary *)receiptForUnreadMessage:(id)message peerID:(NSString *)peer itemID:(NSString *)itemID;
+ (NSDictionary *)reconcileRows:(NSArray<NSDictionary *> *)rows history:(NSArray *)history
                         peerID:(NSString *)peer accountID:(NSString *)account;
/// 只有已确认的未读窗口可升级旧待刷；完整历史仅用于反证/保留，不能批量回灌旧视频。
+ (NSDictionary *)reconcileRows:(NSArray<NSDictionary *> *)rows history:(NSArray *)history unreadMessages:(NSArray *)unread
                         peerID:(NSString *)peer accountID:(NSString *)account;
+ (NSDictionary *)diagnosticsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account;
@end
