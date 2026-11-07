#import <Foundation/Foundation.h>
#import "DYYYMessageListMetrics.h"
#include <math.h>
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
        double total=0,previousCenter=-1;NSString *previousKind=nil;
        for(NSUInteger i=0;i<kinds.count;i++){
            NSDictionary *padding=[DYYYMessageListMetrics paddingForKind:kinds[i] previous:i?kinds[i-1]:nil next:i+1<kinds.count?kinds[i+1]:nil nativeHeight:72];
            double height=[padding[@"height"] doubleValue],top=[padding[@"top"] doubleValue],bottom=[padding[@"bottom"] doubleValue];
            double center=total+(top+height-bottom)/2;
            if([previousKind isEqual:kinds[i]] && ![kinds[i] isEqual:@"notice"])NSCAssert(fabs(center-previousCenter-72)<0.001,@"只增加组边缘留白，组内头像中心间距保持72pt");
            double gap=[kinds[i] isEqual:@"notice"]?10.24:16.24;
            if(top)NSCAssert(fabs((top+height-bottom)/2-56*0.92/2-6-gap)<0.001,@"互动入口收紧，会话组仍保持首行留白");
            if(bottom)NSCAssert(fabs(height-6-((top+height-bottom)/2+56*0.92/2)-gap)<0.001,@"互动入口收紧，会话组仍保持末行留白");
            total+=height;previousCenter=center;previousKind=kinds[i];
        }
        NSCAssert(total==636,@"互动入口仅加12pt，会话组各保留24pt边缘空间");
        NSCAssert([[DYYYMessageListMetrics paddingForKind:@"notice" previous:nil next:@"pinned" nativeHeight:72][@"height"] doubleValue]==84,@"独立互动入口更紧凑且仍有上下留白");
        NSCAssert(![DYYYMessageListMetrics paddingForKind:@"regular" previous:nil next:nil nativeHeight:-1].count,@"未知自动行高保留原生");
        NSCAssert([[DYYYMessageListMetrics kindForNotice:YES pinned:YES] isEqual:@"notice"],@"互动独立，不并入置顶");
        NSDictionary *only=[DYYYMessageListMetrics segmentForKind:@"regular" previous:nil next:nil width:440 height:72];
        NSCAssert([only[@"first"] boolValue] && [only[@"last"] boolValue],@"没有置顶时普通列表也有完整圆角");
        NSDictionary *lastPin=[DYYYMessageListMetrics segmentForKind:@"pinned" previous:@"pinned" next:@"regular" width:440 height:72];
        NSDictionary *firstNormal=[DYYYMessageListMetrics segmentForKind:@"regular" previous:@"pinned" next:@"regular" width:440 height:72];
        NSCAssert(72-[lastPin[@"y"] doubleValue]-[lastPin[@"height"] doubleValue]+[firstNormal[@"y"] doubleValue]==12,@"两个组之间保留12pt空隙");
        NSCAssert(![DYYYMessageListMetrics segmentForKind:@"unknown" previous:nil next:nil width:440 height:72].count,@"未知业务不猜分组");
        NSDictionary *viewport=[DYYYMessageListMetrics viewportForListTop:106 headerBottom:106 tableY:0 width:440 height:850 rootHeight:956];
        NSCAssert([viewport[@"y"] doubleValue]==-106 && [viewport[@"height"] doubleValue]==956,@"列表绘制范围确实延伸到顶栏，而不是只清空颜色");
        double delta=[viewport[@"extension"] doubleValue];
        for(NSUInteger i=0;i<1000;i++){
            double offset=173,cellY=432;
            NSCAssert(fabs(106+cellY-offset-(-delta+106+cellY-(offset-delta)))<0.001,@"扩展与滚动偏移补偿后，当前消息屏幕位置不跳变");
            NSDictionary *base=@{@"x":@0,@"y":@0,@"width":@440,@"height":@850};
            NSDictionary *shown=@{@"x":@0,@"y":@(-delta),@"width":@440,@"height":@(850+delta)};
            NSCAssert([[DYYYMessageListMetrics nativeFrameForRequest:shown previousNative:base previousDisplayed:shown] isEqual:base],@"原生重复写当前frame不叠加顶部扩展");
        }
        NSCAssert(![DYYYMessageListMetrics viewportForListTop:106 headerBottom:106 tableY:0 width:956 height:334 rootHeight:440].count,@"横屏与特殊布局保留原生");
        NSCAssert(![DYYYMessageListMetrics viewportForListTop:106 headerBottom:90 tableY:0 width:440 height:850 rootHeight:956].count,@"导航栏和列表边界不匹配时不猜");
        NSCAssert(![DYYYMessageListMetrics viewportForListTop:NAN headerBottom:106 tableY:0 width:440 height:850 rootHeight:956].count,@"非法布局跳过");
        // 4BFF6DCA 两套导航栏：父栏标签仍17pt，只平移原生标签组让出子页按钮。
        NSDictionary *header=[DYYYMessageListMetrics noticeHeaderShiftForBackRight:64.333 titleLeft:101.333 selectedCenter:300 glassWidth:116 actionsLeft:346 width:440];
        double shift=[header[@"translationX"] doubleValue];
        NSCAssert(shift== -20 && 300+shift+58+8==346,@"选中玻璃与原生右按钮之间留8pt，不再重叠");
        NSCAssert(101.333+shift>64.333+8,@"互动标签不挤到返回角标");
        for(NSUInteger i=0;i<1000;i++)NSCAssert([[DYYYMessageListMetrics noticeHeaderShiftForBackRight:64.333 titleLeft:101.333 selectedCenter:300 glassWidth:116 actionsLeft:346 width:440] isEqual:header],@"标签整体只平移一次，字体与宽度不缩放");
        NSCAssert(![DYYYMessageListMetrics noticeHeaderShiftForBackRight:90 titleLeft:100 selectedCenter:280 glassWidth:116 actionsLeft:300 width:320].count,@"空间不足不把标题移进返回区域");
        NSCAssert(![DYYYMessageListMetrics noticeHeaderShiftForBackRight:64 titleLeft:NAN selectedCenter:300 glassWidth:116 actionsLeft:346 width:440].count,@"未知标题位置不猜");
        // 透明顶栏露出原生空闲 Header：106pt inset 抵消 -106pt offset，不能当成下拉。
        NSCAssert(![DYYYMessageListMetrics showRefreshIndicator:NO dragging:NO offsetY:-106 insetTop:106],@"空闲时加载图不可常驻顶栏");
        NSCAssert(![DYYYMessageListMetrics showRefreshIndicator:NO dragging:YES offsetY:-106 insetTop:106],@"仅按住列表不算下拉");
        NSCAssert([DYYYMessageListMetrics showRefreshIndicator:NO dragging:YES offsetY:-118 insetTop:106],@"真实下拉仍显示原生提示");
        NSCAssert([DYYYMessageListMetrics showRefreshIndicator:YES dragging:NO offsetY:-106 insetTop:106],@"松手后的真实刷新仍显示，不能一律隐藏");
        NSCAssert(![DYYYMessageListMetrics showRefreshIndicator:NO dragging:NO offsetY:-118 insetTop:106],@"刷新结束后即使还在回弹也收起");
        NSCAssert(![DYYYMessageListMetrics showRefreshIndicator:NO dragging:YES offsetY:-106.333 insetTop:106],@"亚像素抖动不误判刷新");
        NSCAssert(![DYYYMessageListMetrics showRefreshIndicator:NO dragging:YES offsetY:NAN insetTop:106],@"非法几何不判定有效下拉");
        NSCAssert(![DYYYMessageListMetrics showRefreshIndicator:NO dragging:NO offsetY:0 insetTop:0],@"互动页无顶部inset时同样空闲隐藏");
        NSCAssert([DYYYMessageListMetrics showRefreshIndicator:NO dragging:YES offsetY:-12 insetTop:0],@"互动页下拉提示保持");
        // 80C4F15D 真实平铺行：头像、时间、摘要与角标都由相同映射保留相对间距。
        NSDictionary *avatar=[DYYYMessageListMetrics contentTransformForX:16 y:8 width:56 height:56 rowWidth:440 rowHeight:72];
        NSDictionary *time=[DYYYMessageListMetrics contentTransformForX:363 y:16 width:61 height:15 rowWidth:440 rowHeight:72];
        NSDictionary *subtitle=[DYYYMessageListMetrics contentTransformForX:84 y:40 width:306 height:17 rowWidth:440 rowHeight:72];
        NSDictionary *badge=[DYYYMessageListMetrics contentTransformForX:402 y:40.5 width:22 height:16 rowWidth:440 rowHeight:72];
        double leftGap=[avatar[@"x"] doubleValue]-16;
        double rightGap=424-[time[@"x"] doubleValue]-[time[@"width"] doubleValue];
        NSCAssert(fabs(leftGap-16.32)<0.001 && fabs(rightGap-leftGap)<0.001,@"头像与时间到卡片边缘均留约16pt，不再贴边");
        NSCAssert(fabs([avatar[@"width"] doubleValue]-[avatar[@"height"] doubleValue])<0.001,@"头像等比缩小，保持圆形");
        NSCAssert([avatar[@"y"] doubleValue]>10 && [avatar[@"y"] doubleValue]+[avatar[@"height"] doubleValue]<62,@"头像上下也留出更多空白");
        double textGap=[badge[@"x"] doubleValue]-[subtitle[@"x"] doubleValue]-[subtitle[@"width"] doubleValue];
        NSCAssert(fabs(textGap-11.04)<0.001,@"摘要与角标原有12pt间距同步缩放，保留分离");
        NSDictionary *prefix=[DYYYMessageListMetrics contentTransformForX:84 y:40 width:53 height:17 rowWidth:440 rowHeight:72];
        NSDictionary *sender=[DYYYMessageListMetrics contentTransformForX:137 y:40 width:259 height:17 rowWidth:440 rowHeight:72];
        NSCAssert(fabs([prefix[@"x"] doubleValue]+[prefix[@"width"] doubleValue]-[sender[@"x"] doubleValue])<0.001,@"群聊条数与摘要仍连续对齐");
        NSCAssert(![DYYYMessageListMetrics contentTransformForX:438 y:8 width:40 height:56 rowWidth:440 rowHeight:72].count,@"未知越界组件不接管");
        NSCAssert(![DYYYMessageListMetrics contentTransformForX:0 y:0 width:0 height:0 rowWidth:440 rowHeight:72].count,@"未完成布局不接管");
        NSCAssert(![DYYYMessageListMetrics contentTransformForX:NAN y:8 width:56 height:56 rowWidth:440 rowHeight:72].count,@"非法几何安全跳过");
        // 统一容器：UIKit 可能传入绝对原生 frame，侧滑也可能从当前显示 frame 派生移动。
        NSDictionary *native=@{@"x":@0,@"y":@0,@"width":@440,@"height":@72};
        NSDictionary *displayed=[DYYYMessageListMetrics contentTransformForX:0 y:0 width:440 height:72 rowWidth:440 rowHeight:72];
        NSCAssert([native isEqual:[DYYYMessageListMetrics nativeFrameForRequest:native previousNative:native previousDisplayed:displayed]],@"原生绝对布局原样处理，不能把92%当作原生宽度");
        NSMutableDictionary *swipe=[displayed mutableCopy];swipe[@"x"]=@([displayed[@"x"] doubleValue]-100);
        NSDictionary *unscaled=[DYYYMessageListMetrics nativeFrameForRequest:swipe previousNative:native previousDisplayed:displayed];
        NSCAssert(fabs([unscaled[@"x"] doubleValue]+100)<0.001 && [unscaled[@"width"] doubleValue]==440 && [unscaled[@"height"] doubleValue]==72,@"侧滑只移动100pt，不把显示宽度写成下一轮原生宽度");
        swipe[@"width"]=@405;swipe[@"height"]=@66;
        NSDictionary *rounded=[DYYYMessageListMetrics nativeFrameForRequest:swipe previousNative:native previousDisplayed:displayed];
        NSCAssert([rounded[@"width"] doubleValue]==440 && [rounded[@"height"] doubleValue]==72,@"显示 frame 的半点内像素取整不能导致下一轮继续缩小");
        NSMutableDictionary *resized=[native mutableCopy];resized[@"width"]=@400;resized[@"height"]=@80;
        NSCAssert([resized isEqual:[DYYYMessageListMetrics nativeFrameForRequest:resized previousNative:native previousDisplayed:displayed]],@"原生真实尺寸更新保留");
        for(NSUInteger i=0;i<1000;i++){
            NSDictionary *again=[DYYYMessageListMetrics nativeFrameForRequest:displayed previousNative:native previousDisplayed:displayed];
            NSCAssert([again[@"width"] doubleValue]==440 && [again[@"height"] doubleValue]==72,@"原生刷新复用不积累92%缩放");
        }
        for(NSUInteger i=0;i<1000;i++) NSCAssert([avatar isEqual:[DYYYMessageListMetrics contentTransformForX:16 y:8 width:56 height:56 rowWidth:440 rowHeight:72]],@"始终用原生center/bounds映射，反复布局不继续缩小");
        for(NSUInteger i=0;i<100;i++) NSCAssert([only isEqual:[DYYYMessageListMetrics segmentForKind:@"regular" previous:nil next:nil width:440 height:72]],@"复用和重复布局不累加");
        NSLog(@"DYYYMessageListMetrics regression tests passed");
    }
    return 0;
}
