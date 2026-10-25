#import <Foundation/Foundation.h>

/// 只接收好友当前消息直接携带的作品，不把回复/引用上下文当作新分享。
@interface DYYYIMShareParser : NSObject
+ (NSArray<NSString *> *)directItemIDsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account;
+ (NSDictionary *)receiptForMessage:(id)message peerID:(NSString *)peer itemID:(NSString *)itemID;
+ (NSDictionary *)reconcileRows:(NSArray<NSDictionary *> *)rows history:(NSArray *)history
                         peerID:(NSString *)peer accountID:(NSString *)account;
+ (NSDictionary *)diagnosticsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account;
@end
