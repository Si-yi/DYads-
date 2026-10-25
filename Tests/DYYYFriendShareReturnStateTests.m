#import <Foundation/Foundation.h>
#import "DYYYFriendShareReturnState.h"

@interface DYYYFriendShareReturnStateTests : NSObject
+ (void)check:(BOOL)value reason:(NSString *)reason;
+ (void)run;
@end
@implementation DYYYFriendShareReturnStateTests
+ (void)check:(BOOL)value reason:(NSString *)reason {
    if (!value) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    DYYYFriendShareReturnState *state = [DYYYFriendShareReturnState new];
    [state beginLeavingItem:@"video-A" playing:YES];
    [state beginLeavingItem:@"video-A" playing:NO];
    [self check:state.wasPlaying reason:@"子播放器先离页、父 Feed 后离页不能被原生暂停覆盖第一次意图"];
    [self check:![state consumeReturnToItem:@"video-A" visible:NO playing:NO] && state.pending
        reason:@"设置/侧边栏/个人页仍可见时保留快照但不抢播"];
    [self check:[state consumeReturnToItem:@"video-A" visible:YES playing:NO] && !state.pending
        reason:@"真正回到同一个已停止的作品时允许恢复一次"];
    [self check:![state consumeReturnToItem:@"video-A" visible:YES playing:NO] reason:@"重复 appearance 不能重复强制播放"];
    [state beginLeavingItem:@"video-A" playing:NO];
    [self check:![state consumeReturnToItem:@"video-A" visible:YES playing:NO] && !state.pending reason:@"手动暂停后返回必须仍然暂停"];
    [state beginLeavingItem:@"video-A" playing:YES];
    [self check:![state consumeReturnToItem:@"video-A" visible:YES playing:YES] && !state.pending reason:@"原生已恢复时不再操作播放器"];
    [state beginLeavingItem:@"video-A" playing:YES];
    [self check:![state consumeReturnToItem:@"video-B" visible:YES playing:NO] && !state.pending reason:@"作品改变不能沿用旧作品播放意图"];
    [state beginLeavingItem:@"video-A" playing:YES]; [state reset];
    [self check:![state consumeReturnToItem:@"video-A" visible:YES playing:NO] reason:@"切账户/后台/用户接管后旧任务失效"];
    [state beginLeavingItem:nil playing:YES];
    [self check:!state.pending reason:@"未能确认实际可见作品时不能创建恢复意图"];
    NSLog(@"DYYYFriendShareReturnState regression tests passed");
}
@end
int main(void) {
    @autoreleasepool { [DYYYFriendShareReturnStateTests run]; }
    return 0;
}
