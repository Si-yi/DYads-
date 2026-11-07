#import <Foundation/Foundation.h>
#import "DYYYMessageListUpdateState.h"
int main(void) {
    @autoreleasepool {
        DYYYMessageListUpdateState *state=[DYYYMessageListUpdateState new];
        NSUInteger frame=[state beginUpdate],bounds=[state beginUpdate],center=[state beginUpdate];
        NSCAssert(![state endUpdate:center] && ![state endUpdate:bounds] && state.depth==1,@"原生 frame 内嵌 bounds/center 不得提前重复缩放");
        NSCAssert([state endUpdate:frame] && state.depth==0,@"只有最外层结束恢复内容缩放");
        NSCAssert(![state endUpdate:frame],@"重复结束不能再应用一次");
        NSUInteger old=[state beginUpdate];[state invalidate];NSUInteger reused=[state beginUpdate];
        NSCAssert(![state endUpdate:old] && state.depth==1,@"复用前的回调不能递减新会话布局深度");
        NSCAssert([state endUpdate:reused],@"新实例更新仍正常完成");
        for(NSUInteger i=0;i<1000;i++){
            NSUInteger outer=[state beginUpdate],inner=[state beginUpdate];
            NSCAssert(![state endUpdate:inner] && [state endUpdate:outer] && !state.depth,@"反复刷新不积累更新深度或二次缩放");
        }
        NSLog(@"DYYYMessageListUpdateState regression tests passed");
    }
    return 0;
}
