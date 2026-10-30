#import "DYYYChatInputMetrics.h"
#import <math.h>

@implementation DYYYChatInputMetrics
+ (double)bottomExtensionForHostBottom:(double)hostBottom listTop:(double)listTop listBottom:(double)listBottom
                             inputTop:(double)inputTop inputBottom:(double)inputBottom folded:(BOOL)folded {
    if (!folded || !isfinite(hostBottom) || !isfinite(listTop) || !isfinite(listBottom) ||
        !isfinite(inputTop) || !isfinite(inputBottom) || hostBottom <= 0 || listTop < 0 ||
        listBottom - listTop < hostBottom * 0.4 || fabs(listBottom - inputTop) > 1 ||
        inputBottom - inputTop < 32 || inputBottom - inputTop > 120 ||
        inputBottom > hostBottom + 1 || hostBottom - inputBottom > 80) return 0;
    double extension = hostBottom - listBottom;
    return extension >= 1 && extension <= 128 ? extension : 0;
}
+ (BOOL)canReuseTopExtension:(double)top bottomExtension:(double)bottom topWanted:(BOOL)topWanted
               bottomWanted:(BOOL)bottomWanted previousTopWanted:(BOOL)oldTop previousBottomWanted:(BOOL)oldBottom {
    // 扩展是否需要由原生几何决定，不能把零扩展误当关闭开关、每轮拆建另一端。
    return isfinite(top) && isfinite(bottom) && top >= 0 && bottom >= 0 && (top > 0 || bottom > 0) &&
        topWanted == oldTop && bottomWanted == oldBottom;
}
@end
