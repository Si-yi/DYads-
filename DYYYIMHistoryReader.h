#import <Foundation/Foundation.h>

/// 本地消息只读查询的结果校验与窗口选择，不修改会话或已读状态。
@interface DYYYIMHistoryReader : NSObject
+ (NSArray *)messageArray:(id)result;
/// 已验证的原生未读结果无需再加载完整历史；旧凭据反证和确切边界回退才查询历史。
+ (NSArray *)historyForConversation:(NSString *)identifier latestMessage:(id)latest firstUnreadID:(NSString *)boundary
                      nativeUnread:(NSArray *)incoming revalidating:(BOOL)revalidating observedResult:(id (^)(void))observed
                       recentQuery:(id (^)(NSTimeInterval, NSUInteger))recentQuery
                     earliestQuery:(id (^)(NSUInteger))earliestQuery diagnostics:(NSMutableDictionary *)diagnostics;
+ (NSArray *)historyForConversation:(NSString *)identifier
                     latestMessage:(id)latest
                    observedResult:(id)observed
                       recentQuery:(id (^)(NSTimeInterval before, NSUInteger limit))recentQuery
                     earliestQuery:(id (^)(NSUInteger limit))earliestQuery
                       diagnostics:(NSMutableDictionary *)diagnostics;
+ (NSArray *)historyForConversation:(NSString *)identifier latestMessage:(id)latest firstUnreadID:(NSString *)boundary
                    observedResult:(id)observed recentQuery:(id (^)(NSTimeInterval before, NSUInteger limit))recentQuery
                     earliestQuery:(id (^)(NSUInteger limit))earliestQuery diagnostics:(NSMutableDictionary *)diagnostics;
+ (NSArray *)unreadIncomingMessages:(NSArray *)history peerID:(long long)peer
                       unreadCount:(NSUInteger)count firstUnreadID:(NSString *)boundary;
+ (NSArray *)unreadIncomingMessages:(NSArray *)history peerID:(long long)peer
                       unreadCount:(NSUInteger)count firstUnreadID:(NSString *)boundary diagnostics:(NSMutableDictionary *)diagnostics;
/// 原生 unread 查询本身提供未读依据，不依赖可能为空的 firstUnreadMessageID。
/// 返回 nil 表示结果不可验证，空数组表示原生确认没有该好友的未读消息。
+ (NSArray *)nativeUnreadIncomingMessages:(id)result conversation:(NSString *)identifier
                                  peerID:(long long)peer unreadCount:(NSUInteger)count
                             diagnostics:(NSMutableDictionary *)diagnostics;
@end
