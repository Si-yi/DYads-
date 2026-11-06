#import <Foundation/Foundation.h>
#import "DYYYMessageListMetrics.h"
int main(void) {
    @autoreleasepool {
        NSArray *kinds = @[@"notice",@"pinned",@"pinned",@"pinned",@"pinned",@"regular",@"regular",@"regular"];
        NSUInteger starts=0,ends=0;
        for (NSUInteger i=0;i<kinds.count;i++) {
            NSDictionary *segment=[DYYYMessageListMetrics segmentForKind:kinds[i] previous:i?kinds[i-1]:nil next:i+1<kinds.count?kinds[i+1]:nil width:440 height:72];
            starts += [segment[@"first"] boolValue]; ends += [segment[@"last"] boolValue];
            NSCAssert([segment[@"width"] doubleValue]==416,@"只改变自有背景绘制，不改变行宽");
            if(i==2 || i==3 || i==6) NSCAssert(![segment[@"first"] boolValue] && ![segment[@"last"] boolValue],@"组内聊天连续，不能逐行圆角");
        }
        NSCAssert(starts==3 && ends==3,@"互动、置顶、普通三整块卡片");
        NSCAssert([[DYYYMessageListMetrics kindForNotice:YES pinned:YES] isEqual:@"notice"],@"互动独立，不并入置顶");
        NSDictionary *only=[DYYYMessageListMetrics segmentForKind:@"regular" previous:nil next:nil width:440 height:72];
        NSCAssert([only[@"first"] boolValue] && [only[@"last"] boolValue],@"没有置顶时普通列表也有完整圆角");
        NSDictionary *lastPin=[DYYYMessageListMetrics segmentForKind:@"pinned" previous:@"pinned" next:@"regular" width:440 height:72];
        NSDictionary *firstNormal=[DYYYMessageListMetrics segmentForKind:@"regular" previous:@"pinned" next:@"regular" width:440 height:72];
        NSCAssert(72-[lastPin[@"y"] doubleValue]-[lastPin[@"height"] doubleValue]+[firstNormal[@"y"] doubleValue]==12,@"两个组之间12pt空隙且原行高不变");
        NSCAssert(![DYYYMessageListMetrics segmentForKind:@"unknown" previous:nil next:nil width:440 height:72].count,@"未知业务不猜分组");
        for(NSUInteger i=0;i<100;i++) NSCAssert([only isEqual:[DYYYMessageListMetrics segmentForKind:@"regular" previous:nil next:nil width:440 height:72]],@"复用和重复布局不累加");
        NSLog(@"DYYYMessageListMetrics regression tests passed");
    }
    return 0;
}
