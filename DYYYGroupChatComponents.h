#import <Foundation/Foundation.h>

@interface DYYYGroupChatComponents : NSObject
// 只替换原生群下拉组件名，交给原组件管理器创建聊天详情按钮及其 action。
+ (id)navigationComponents:(id)components enabled:(BOOL)enabled;
+ (NSDictionary *)diagnostics;
@end
