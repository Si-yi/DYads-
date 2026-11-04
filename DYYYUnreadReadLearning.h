#import <Foundation/Foundation.h>

// 只保存真实原生调用的参数形状与弱引用；不读取消息、不发起 SDK 调用。
@interface DYYYUnreadReadLearning : NSObject
- (BOOL)recordConversation:(id)conversation receiver:(id)receiver root:(id)root account:(NSString *)account
                     mode:(unsigned long long)mode shape:(NSString *)shape messageClass:(Class)messageClass at:(NSTimeInterval)time;
- (NSArray<NSDictionary *> *)takeForRoot:(id)root account:(NSString *)account at:(NSTimeInterval)time;
- (NSUInteger)pendingCountAt:(NSTimeInterval)time;
@end
