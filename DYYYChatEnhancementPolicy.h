#import <Foundation/Foundation.h>

/// 原生私有接口只按已核对的 ABI 使用，未知签名放行。
@interface DYYYChatEnhancementPolicy : NSObject
+ (BOOL)signature:(NSMethodSignature *)signature result:(char)result arguments:(NSString *)arguments;
+ (BOOL)class:(Class)cls selector:(SEL)selector result:(char)result arguments:(NSString *)arguments;
@end

/// 单个聊天控制器的转写去重，不查询历史，也不影响消息已读。
@interface DYYYChatTranslationLedger : NSObject
- (BOOL)reserveAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message;
@property (nonatomic, readonly) NSUInteger count;
@end
