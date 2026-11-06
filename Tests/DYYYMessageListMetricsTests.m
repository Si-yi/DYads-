#import <Foundation/Foundation.h>
#import "DYYYMessageListMetrics.h"
int main(void) {
    @autoreleasepool {
        NSArray *kinds = @[@"notice",@"pinned",@"pinned",@"pinned",@"pinned",@"regular",@"regular",@"regular"];
        NSUInteger starts=0,ends=0;
        for (NSUInteger i=0;i<kinds.count;i++) {
            NSDictionary *segment=[DYYYMessageListMetrics segmentForKind:kinds[i] previous:i?kinds[i-1]:nil next:i+1<kinds.count?kinds[i+1]:nil width:440 height:72];
            starts += [segment[@"first"] boolValue]; ends += [segment[@"last"] boolValue];
            NSCAssert([segment[@"x"] doubleValue]==16 && [segment[@"width"] doubleValue]==408,@"面板两侧16pt留白，不改变原生行宽");
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
        // E68EEF19 实际头像、时间、超长摘要和未读数字；内缩后保留比例及尾部空间。
        NSDictionary *avatar=[DYYYMessageListMetrics contentPlacementForX:16 width:56 rowWidth:440 trailing:NO nativeRightLimit:424];
        NSDictionary *time=[DYYYMessageListMetrics contentPlacementForX:375 width:49 rowWidth:440 trailing:YES nativeRightLimit:424];
        NSDictionary *badge=[DYYYMessageListMetrics contentPlacementForX:402 width:22 rowWidth:440 trailing:YES nativeRightLimit:424];
        NSDictionary *subtitle=[DYYYMessageListMetrics contentPlacementForX:84 width:340 rowWidth:440 trailing:NO nativeRightLimit:424];
        NSCAssert(16+[avatar[@"translation"] doubleValue]==32 && [avatar[@"visibleWidth"] doubleValue]==56,@"头像和面板间距16pt，头像不变形");
        NSCAssert(375+[time[@"translation"] doubleValue]+49==408 && 402+[badge[@"translation"] doubleValue]+22==408,@"时间与红点一同内缩，保持原生对齐");
        NSDictionary *withBadge=[DYYYMessageListMetrics contentPlacementForX:84 width:306 rowWidth:440 trailing:NO nativeRightLimit:390];
        NSCAssert([withBadge[@"visibleWidth"] doubleValue]==274 && 84+16+274+12==402-16,@"真实22pt未读角标与长摘要内缩后仍保留12pt间距");
        NSCAssert([subtitle[@"visibleWidth"] doubleValue]==308,@"长摘要只在面板内绘制，不能盖住外边距");
        NSCAssert(![DYYYMessageListMetrics contentPlacementForX:438 width:40 rowWidth:440 trailing:YES nativeRightLimit:424].count,@"未知越界组件不强行平移");
        NSCAssert(![DYYYMessageListMetrics contentPlacementForX:0 width:0 rowWidth:440 trailing:NO nativeRightLimit:424].count,@"布局未就绪不能保存零尺寸方案");
        for(NSUInteger i=0;i<100;i++) NSCAssert([only isEqual:[DYYYMessageListMetrics segmentForKind:@"regular" previous:nil next:nil width:440 height:72]],@"复用和重复布局不累加");
        NSLog(@"DYYYMessageListMetrics regression tests passed");
    }
    return 0;
}
