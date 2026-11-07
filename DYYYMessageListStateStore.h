#import <Foundation/Foundation.h>
// 同一个原生表格上的两类状态必须使用独立键，不能复用方法 selector。
@interface DYYYMessageListStateStore : NSObject
+ (id)viewportForObject:(id)object;
+ (void)setViewport:(id)viewport forObject:(id)object;
+ (NSNumber *)separatorForObject:(id)object;
+ (void)setSeparator:(NSNumber *)separator forObject:(id)object;
@end
