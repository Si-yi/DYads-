#import "DYYYDetailCaptionMetrics.h"
#import <math.h>

@implementation DYYYDetailCaptionMetrics
+ (double)downwardShiftForCaptionBottom:(double)captionBottom inputTop:(double)inputTop
                       progressBottom:(double)progressBottom enabled:(BOOL)enabled {
    if (!enabled || !isfinite(captionBottom) || !isfinite(inputTop) || !isfinite(progressBottom) || captionBottom <= 0) return 0;
    double gap = inputTop - captionBottom;
    if (gap <= 16 || gap > 64) return 0;
    double shift = MIN(32, gap - 16);
    // 多图的分页条跟随文案一起移动，容器仍须停在输入胶囊上方。
    if (progressBottom > 0) shift = MIN(shift, inputTop - 4 - progressBottom);
    return MAX(0, shift);
}
@end
