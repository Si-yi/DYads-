#import "DYYYTabBarMetrics.h"
#import <math.h>

@implementation DYYYTabBarMetrics
+ (double)capsuleWidthForCount:(NSUInteger)count reference:(NSUInteger)reference barWidth:(double)barWidth buttonWidth:(double)buttonWidth padding:(double)padding accessory:(double)accessory inset:(double)inset {
    if (!count || !isfinite(barWidth) || barWidth <= 0 || !isfinite(buttonWidth) || buttonWidth <= 0 ||
        !isfinite(padding) || padding < 0 || !isfinite(accessory) || accessory < 0 || !isfinite(inset) || inset < 0) return 0;
    double available = MAX(0.0, barWidth - accessory - 2 * inset);
    double single = MIN(available, buttonWidth + 2 * padding);
    double naturalPitch = MAX(0.0, buttonWidth - 2 * padding);
    reference = MAX(count, reference);
    if (count <= 1 || reference <= 1) return single;
    double referenceWidth = MIN(available, single + (reference - 1) * naturalPitch);
    double pitch = MIN(MAX((referenceWidth - single) / (reference - 1), 0.0), naturalPitch);
    return single + (count - 1) * pitch;
}
@end
