#import "DYYYMessageListMetrics.h"
#include <math.h>
@implementation DYYYMessageListMetrics
+ (NSString *)kindForNotice:(BOOL)notice pinned:(BOOL)pinned { return notice ? @"notice" : pinned ? @"pinned" : @"regular"; }
+ (NSDictionary *)segmentForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next width:(double)width height:(double)height {
    if (![@[@"notice",@"pinned",@"regular"] containsObject:kind ?: @""] || !isfinite(width) || !isfinite(height) || width < 160 || height < 40) return @{};
    BOOL first = [kind isEqual:@"notice"] || ![kind isEqual:previous];
    BOOL last = [kind isEqual:@"notice"] || ![kind isEqual:next];
    double top = first ? 6 : 0, bottom = last ? 6 : 0;
    return @{@"x":@12,@"y":@(top),@"width":@(width-24),@"height":@(height-top-bottom),@"first":@(first),@"last":@(last),@"radius":@18};
}
@end
