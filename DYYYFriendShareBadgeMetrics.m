#import "DYYYFriendShareBadgeMetrics.h"
#include <math.h>

@implementation DYYYFriendShareBadgeMetrics
+ (double)topForCaptionTop:(double)captionTop badgeX:(double)x width:(double)width height:(double)height
           occupiedFrames:(NSArray<NSDictionary<NSString *, NSNumber *> *> *)frames {
    if (!isfinite(captionTop) || !isfinite(x) || !isfinite(width) || !isfinite(height) || width <= 0 || height <= 0 || !isfinite(x + width)) return NAN;
    double top = captionTop;
    for (id value in frames) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *rect = value;
        BOOL valid = YES;
        for (NSString *key in @[@"x", @"y", @"width", @"height"])
            if (![rect[key] isKindOfClass:NSNumber.class] || !isfinite([rect[key] doubleValue])) { valid = NO; break; }
        if (!valid) continue;
        double left = [rect[@"x"] doubleValue], y = [rect[@"y"] doubleValue];
        double w = [rect[@"width"] doubleValue], h = [rect[@"height"] doubleValue];
        if (w <= 0 || h <= 0 || !isfinite(left + w) || !isfinite(y + h)) continue;
        // 只避让昵称上方、与来源提示在水平方向相交的实际标签；不计右侧按钮/正文。
        if (left >= x + width || left + w <= x || y + h > captionTop + 0.5) continue;
        top = MIN(top, y);
    }
    return top - height - 6;
}
@end
