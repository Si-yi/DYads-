#import "DYYYVideoPageMetrics.h"
#include <math.h>

@implementation DYYYVideoPageMetrics
+ (NSDictionary *)paintExtensionForWidth:(double)width height:(double)height pageWidth:(double)pageWidth pageHeight:(double)pageHeight replyTop:(double)replyTop replyHeight:(double)replyHeight enabled:(BOOL)enabled {
    if (!enabled || !isfinite(width) || !isfinite(height) || !isfinite(pageWidth) || !isfinite(pageHeight) ||
        !isfinite(replyTop) || !isfinite(replyHeight) || width <= 0 || pageWidth <= 0 || pageHeight <= 0 || height <= width || pageHeight <= pageWidth ||
        fabs(width - pageWidth) > 0.5 || replyHeight <= 0 || replyHeight > 150 ||
        fabs(replyTop - height) > 0.5 || fabs(replyTop + replyHeight - pageHeight) > 0.5) return @{};
    double gap = pageHeight - height, scale = pageHeight / height;
    if (gap <= 0.5 || gap > 160 || scale > 1.25) return @{};
    // 仅变换视频子图层的绘制，原生 frame/bounds、表高、行高与偏移均不参与。
    return @{@"scale":@(scale), @"translateY":@(gap / 2), @"height":@(pageHeight)};
}
+ (double)tableHeight:(double)native target:(double)target enabled:(BOOL)enabled nativePaging:(BOOL)nativePaging {
    if (nativePaging || !enabled || !isfinite(native) || !isfinite(target) || native <= 0 ||
        target <= native + 0.5 || native < target * 0.5 || target - native > 160) return native;
    return target;
}
+ (double)rowHeight:(double)native original:(double)original viewport:(double)viewport enabled:(BOOL)enabled nativePaging:(BOOL)nativePaging {
    if (nativePaging || !enabled || !isfinite(native) || !isfinite(original) || !isfinite(viewport) ||
        native <= 0 || original <= 0 || viewport <= original + 0.5) return native;
    if (fabs(native - original) > 0.5 && fabs(native - viewport) > 0.5) return native;
    return viewport;
}
@end
