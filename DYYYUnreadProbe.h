#import <Foundation/Foundation.h>

/// 只观察原生已经发生的 UI 提示处理，记录类型，不读取消息或计数。
@interface DYYYUnreadProbe : NSObject
+ (void)installHooks;
+ (BOOL)canObserveClass:(Class)cls selector:(SEL)selector arguments:(NSUInteger)arguments result:(char)result;
+ (void)didInstall:(NSString *)name;
+ (void)recordReceiver:(id)receiver input:(id)input result:(id)result selector:(SEL)selector;
+ (NSArray<NSString *> *)observedClassNames;
+ (NSDictionary *)diagnostics;
@end
