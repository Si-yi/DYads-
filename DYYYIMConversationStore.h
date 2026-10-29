#import <Foundation/Foundation.h>

/// 只保留抖音自然创建的会话弱引用，不主动触发 SDK 会话工厂/数据库读取。
@interface DYYYIMConversationStore : NSObject
+ (void)capture:(id)conversation root:(id)root identifier:(NSString *)identifier;
+ (id)conversationForRoot:(id)root identifier:(NSString *)identifier;
+ (void)observeNativeConversation:(id)conversation root:(id)root identifier:(NSString *)identifier;
+ (NSDictionary *)diagnostics;
@end
