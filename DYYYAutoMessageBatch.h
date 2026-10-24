#import <Foundation/Foundation.h>

/// 已添加好友的批量文字配置；按账户及 UID 匹配，不触发发送。
@interface DYYYAutoMessageBatch : NSObject
+ (NSArray<NSDictionary *> *)configuredFriends:(NSArray<NSDictionary *> *)configs ownerID:(NSString *)ownerID contacts:(NSArray<NSDictionary *> *)contacts;
+ (NSArray<NSDictionary *> *)configsByUpdatingText:(NSString *)text randomText:(BOOL)randomText
                                        configs:(NSArray<NSDictionary *> *)configs ownerID:(NSString *)ownerID selectedUserIDs:(NSSet<NSString *> *)selectedIDs;
@end
