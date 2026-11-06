#import <Foundation/Foundation.h>

// 聊天离页后，旧布局任务只能丢弃；恢复必须来自真实 appearance 事件。
@interface DYYYChatLifecycle : NSObject
@property (nonatomic, readonly) BOOL active;
@property (nonatomic, readonly) NSUInteger generation;
- (void)resume;
- (void)suspend;
- (BOOL)acceptsGeneration:(NSUInteger)generation;
@end
