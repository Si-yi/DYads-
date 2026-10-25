#import "DYYYDetailCaptionMetrics.h"
#import <math.h>

@implementation DYYYDetailCaptionMetrics
+ (double)downwardShiftForCaptionBottom:(double)captionBottom inputTop:(double)inputTop
                       progressBottom:(double)progressBottom progressLimit:(double)progressLimit enabled:(BOOL)enabled {
    if (!enabled || !isfinite(captionBottom) || !isfinite(inputTop) || !isfinite(progressBottom) || !isfinite(progressLimit) || captionBottom <= 0) return 0;
    double gap = inputTop - captionBottom;
    if (gap <= 16 || gap > 64) return 0;
    double shift = MIN(32, gap - 16);
    // 分页条的实际绘制与点击位置不能越过原生 HUD，也不能进入输入胶囊。
    if (progressBottom > 0) {
        if (progressLimit <= 0) return 0;
        shift = MIN(shift, MIN(inputTop - 4, progressLimit) - progressBottom);
    }
    return MAX(0, shift);
}
@end
