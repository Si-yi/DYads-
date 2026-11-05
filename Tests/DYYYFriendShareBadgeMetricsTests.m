#import <Foundation/Foundation.h>
#import "DYYYFriendShareBadgeMetrics.h"
#include <math.h>

@interface DYYYFriendShareBadgeMetricsTests : NSObject
+ (void)check:(BOOL)condition reason:(NSString *)reason;
@end
@implementation DYYYFriendShareBadgeMetricsTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    // 173155A2 / 39.5.0 实际坐标：昵称789.1667，原生标签753.1667，旧来源提示也在753.1667。
    double caption = 789.1666691700617;
    NSDictionary *native = @{ @"x":@12, @"y":@753.1666691700617, @"width":@114.3, @"height":@25.2 };
    double (^top)(NSArray *) = ^double(NSArray *frames) {
        return [DYYYFriendShareBadgeMetrics topForCaptionTop:caption badgeX:12 width:123 height:30 occupiedFrames:frames];
    };
    [self check:fabs(top(@[]) - 753.1666691700617) < 0.001 reason:@"没有可见原生标签时保留昵称上方6pt"];
    [self check:fabs(top(@[native]) - 717.1666691700617) < 0.001 reason:@"按已缩放坐标避开实际我推荐标签"];
    [self check:fabs([native[@"y"] doubleValue] - (top(@[native]) + 30) - 6) < 0.001 reason:@"两个标签保留6pt实际间距"];
    NSDictionary *higher = @{ @"x":@12, @"y":@719, @"width":@150, @"height":@28 };
    [self check:fabs(top(@[native, higher]) - 683) < 0.001 && top(@[higher, native]) == top(@[native, higher]) reason:@"多个原生标签顺序不同也不互相覆盖"];
    NSDictionary *right = @{ @"x":@364, @"y":@700, @"width":@76, @"height":@50 };
    NSDictionary *description = @{ @"x":@12, @"y":@800, @"width":@300, @"height":@30 };
    [self check:top(@[right, description]) == top(@[]) reason:@"右侧按钮和昵称下方文案不能把来源标签顶高"];
    [self check:top(@[@{ @"x":@12, @"y":@600, @"width":@0, @"height":@28 }, @{ @"x":@12 }, (id)NSNull.null]) == top(@[]) reason:@"空框及未知矩形不参与定位"];
    double afterRecommend = top(@[native]);
    for (NSUInteger i = 0; i < 100; i++) [self check:top(@[native]) == afterRecommend reason:@"重复布局不累加上移"];
    [self check:top(@[]) > afterRecommend reason:@"取消推荐或复用到无标签页面恢复原位置"];
    [self check:isnan([DYYYFriendShareBadgeMetrics topForCaptionTop:NAN badgeX:12 width:123 height:30 occupiedFrames:@[]]) reason:@"无效昵称几何不写入Frame"];
    NSLog(@"DYYYFriendShareBadgeMetrics regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYFriendShareBadgeMetricsTests run]; } return 0; }
