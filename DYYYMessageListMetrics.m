#import "DYYYMessageListMetrics.h"
#include <math.h>
@implementation DYYYMessageListMetrics
+ (NSString *)kindForNotice:(BOOL)notice pinned:(BOOL)pinned { return notice ? @"notice" : pinned ? @"pinned" : @"regular"; }
+ (NSDictionary *)segmentForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next width:(double)width height:(double)height {
    if (![@[@"notice",@"pinned",@"regular"] containsObject:kind ?: @""] || !isfinite(width) || !isfinite(height) || width < 160 || height < 40) return @{};
    BOOL first = [kind isEqual:@"notice"] || ![kind isEqual:previous];
    BOOL last = [kind isEqual:@"notice"] || ![kind isEqual:next];
    double top = first ? 6 : 0, bottom = last ? 6 : 0;
    return @{@"x":@16,@"y":@(top),@"width":@(width-32),@"height":@(height-top-bottom),@"first":@(first),@"last":@(last),@"radius":@18};
}
+ (NSDictionary *)contentPlacementForX:(double)x width:(double)width rowWidth:(double)rowWidth trailing:(BOOL)trailing nativeRightLimit:(double)rightLimit {
    if (!isfinite(x) || !isfinite(width) || !isfinite(rowWidth) || !isfinite(rightLimit) || rowWidth<160 || x<0 || width<=0 || x+width>rowWidth+0.5 || rightLimit<0 || rightLimit>rowWidth) return @{};
    double translation=trailing?-16:16;
    double right=trailing?rowWidth-32:MIN(rowWidth-32,rightLimit-16);
    double visibleWidth=MIN(width,right-x-translation);
    if (visibleWidth<=0 || x+translation<16) return @{};
    return @{@"translation":@(translation),@"visibleWidth":@(visibleWidth)};
}
@end
