#import <Foundation/Foundation.h>
#import "DYYYVideoPageMetrics.h"
#include <math.h>

int main(void) {
    @autoreleasepool {
        // 聊天页反复换页时：整页行、回复栏预留和原生偏移必须使用同一原生几何。
        for (NSUInteger page = 0; page < 1000; page++) {
            double native = page % 2 ? 858 : 884;
            NSCAssert([DYYYVideoPageMetrics tableHeight:native target:956 enabled:YES nativePaging:YES] == native, @"聊天表格不能套首页补高");
            NSCAssert([DYYYVideoPageMetrics rowHeight:native original:native viewport:956 enabled:YES nativePaging:YES] == native, @"聊天行高与原生分页保持一致");
            NSCAssert([DYYYVideoPageMetrics rowHeight:40 original:native viewport:956 enabled:YES nativePaging:YES] == 40, @"特殊行原样返回");
        }
        NSCAssert([DYYYVideoPageMetrics tableHeight:884 target:956 enabled:YES nativePaging:NO] == 956, @"普通详情仍可补高");
        NSCAssert([DYYYVideoPageMetrics rowHeight:884 original:884 viewport:956 enabled:YES nativePaging:NO] == 956, @"普通详情整页行仍匹配补高表格");
        NSCAssert([DYYYVideoPageMetrics rowHeight:40 original:884 viewport:956 enabled:YES nativePaging:NO] == 40, @"广告等特殊行不能拉伸");
        NSCAssert([DYYYVideoPageMetrics rowHeight:-1 original:884 viewport:956 enabled:YES nativePaging:NO] == -1, @"自动尺寸保留");
        NSCAssert([DYYYVideoPageMetrics tableHeight:884 target:956 enabled:NO nativePaging:NO] == 884, @"关闭全屏保持原生");
        NSCAssert([DYYYVideoPageMetrics tableHeight:100 target:956 enabled:YES nativePaging:NO] == 100, @"未知小容器不能补高");
        NSCAssert([DYYYVideoPageMetrics rowHeight:884 original:NAN viewport:956 enabled:YES nativePaging:NO] == 884, @"未知原始几何安全放行");
        NSLog(@"DYYYVideoPageMetrics regression tests passed");
    }
    return 0;
}
