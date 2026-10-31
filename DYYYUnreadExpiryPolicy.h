#import <Foundation/Foundation.h>

@interface DYYYUnreadExpiryPolicy : NSObject
+ (NSNumber *)daysFromText:(id)text;
+ (NSString *)completionEncoding:(id)block;
+ (BOOL)isNativeMessageClass:(Class)candidate;
+ (NSString *)completionShape:(id)block;
/// 只从完整、同一会话的未读集合选出连续过期前缀；不返回正文或原生对象。
+ (NSDictionary *)planForFacts:(NSArray<NSDictionary *> *)facts nativeCount:(NSUInteger)count
                 conversation:(NSString *)conversation cutoff:(NSDate *)cutoff;
@end
