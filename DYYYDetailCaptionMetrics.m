#import "DYYYDetailCaptionMetrics.h"
#import <math.h>

@implementation DYYYDetailCaptionMetrics
+ (double)pageInputTopForViewportInputTop:(double)inputTop viewportMinY:(double)viewportMinY
                         viewportHeight:(double)viewportHeight pageMinY:(double)pageMinY pageHeight:(double)pageHeight {
    // 页内坐标不包含 table 的滚动位移；仅映射尺寸一致的整页，不能猜未知布局。
    if (!isfinite(inputTop) || !isfinite(viewportMinY) || !isfinite(viewportHeight) ||
        !isfinite(pageMinY) || !isfinite(pageHeight) || viewportHeight <= 0 || pageHeight <= 0 ||
        fabs(pageHeight - viewportHeight) > 1 || inputTop <= viewportMinY || inputTop > viewportMinY + viewportHeight) return NAN;
    return pageMinY + inputTop - viewportMinY;
}
+ (double)captionBottomForRowBottom:(double)rowBottom plainTextBottom:(double)textBottom {
    // 时间/IP 的 UILabel 可在原生行内上移；行尾空白不能当成文字。
    if (isfinite(textBottom) && textBottom > 0 && isfinite(rowBottom) && fabs(textBottom - rowBottom) <= 64)
        return textBottom;
    return rowBottom;
}
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
