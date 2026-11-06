#import <Foundation/Foundation.h>
#import "DYYYChatLifecycle.h"

int main(void) {
    @autoreleasepool {
        DYYYChatLifecycle *chat = [DYYYChatLifecycle new];
        NSCAssert(!chat.active && ![chat acceptsGeneration:chat.generation], @"尚未显示的聊天不能启动玻璃布局");
        [chat resume];
        NSUInteger queuedLayout = chat.generation;
        NSCAssert([chat acceptsGeneration:queuedLayout], @"当前聊天允许一次自然布局任务");
        [chat suspend]; // 点开群视频，导航 visibleViewController 仍可能是聊天。
        NSCAssert(![chat acceptsGeneration:queuedLayout], @"离页前已排队的修复不能重新激活聊天");
        NSCAssert(![chat acceptsGeneration:chat.generation], @"播放视频时新布局也不能启动");
        [chat resume]; // 返回或取消交互式跳转后真实 viewDidAppear。
        NSCAssert(![chat acceptsGeneration:queuedLayout], @"返回后旧任务仍失效");
        NSCAssert([chat acceptsGeneration:chat.generation], @"返回后新任务恢复");
        DYYYChatLifecycle *other = [DYYYChatLifecycle new];
        [other resume];
        [chat suspend];
        NSCAssert(other.active, @"不同聊天的生命周期独立");
        for (NSUInteger i = 0; i < 100; i++) {
            [chat resume]; NSUInteger token = chat.generation;
            [chat suspend]; [chat resume];
            NSCAssert(![chat acceptsGeneration:token], @"连续进出视频不能复活旧任务");
        }
        NSLog(@"DYYYChatLifecycle regression tests passed");
    }
    return 0;
}
