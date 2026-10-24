#import <Foundation/Foundation.h>

/// 本地消息只读查询的结果校验与窗口选择，不修改会话或已读状态。
@interface DYYYIMHistoryReader : NSObject
+ (NSArray *)messageArray:(id)result;
+ (NSArray *)historyForConversation:(NSString *)identifier
                     latestMessage:(id)latest
                    observedResult:(id)observed
                       recentQuery:(id (^)(NSTimeInterval before, NSUInteger limit))recentQuery
                     earliestQuery:(id (^)(NSUInteger limit))earliestQuery
                       diagnostics:(NSMutableDictionary *)diagnostics;
+ (NSArray *)unreadIncomingMessages:(NSArray *)history peerID:(long long)peer
                       unreadCount:(NSUInteger)count firstUnreadID:(NSString *)boundary;
@end
