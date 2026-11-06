#import "DYYYVideoPageMetrics.h"
#include <math.h>

@implementation DYYYVideoPageMetrics
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
