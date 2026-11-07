#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "DYYYMessageListStateStore.h"
int main(void) {
    @autoreleasepool {
        NSObject *table=[NSObject new],*viewport=[NSObject new];
        // 旧版两个组件把不同类型写入同一个 selector；新状态不能再读到这块旧值。
        SEL legacy=NSSelectorFromString(@"synchronizeController:");
        objc_setAssociatedObject(table,legacy,@1,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSCAssert(![DYYYMessageListStateStore viewportForObject:table],@"旧分隔线 NSNumber 不能被当成视口对象");
        [DYYYMessageListStateStore setViewport:viewport forObject:table];
        for(NSUInteger i=0;i<1000;i++){
            [DYYYMessageListStateStore setSeparator:@1 forObject:table];
            NSCAssert([DYYYMessageListStateStore viewportForObject:table]==viewport,@"分隔线样式不能覆盖或释放视口");
            [DYYYMessageListStateStore setSeparator:nil forObject:table];
            NSCAssert([DYYYMessageListStateStore viewportForObject:table]==viewport,@"关闭卡片不能丢失遮罩的恢复凭据");
        }
        [DYYYMessageListStateStore setSeparator:@2 forObject:table];
        [DYYYMessageListStateStore setViewport:nil forObject:table];
        NSCAssert([[DYYYMessageListStateStore separatorForObject:table] isEqual:@2],@"移除视口不影响分隔线的原生状态");
        NSObject *other=[NSObject new];NSCAssert(![DYYYMessageListStateStore separatorForObject:other],@"不同列表状态隔离");
        __weak NSObject *weakState=nil;
        @autoreleasepool {NSObject *state=[NSObject new];weakState=state;[DYYYMessageListStateStore setViewport:state forObject:table];}
        NSCAssert(weakState!=nil,@"表格必须强持有恢复凭据，不能留下孤立遮罩");
        [DYYYMessageListStateStore setViewport:nil forObject:table];NSCAssert(weakState==nil,@"主动移除后释放状态");
        NSLog(@"DYYYMessageListStateStore regression tests passed");
    }return 0;
}
