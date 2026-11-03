#import <Foundation/Foundation.h>
#import "DYYYTabBarMetrics.h"
#import <math.h>

@interface DYYYTabBarMetricsTests : NSObject
@end
@implementation DYYYTabBarMetricsTests
+ (void)check:(BOOL)value reason:(NSString *)reason { if (!value) [NSException raise:@"RegressionFailure" format:@"%@", reason]; }
+ (double)width:(NSUInteger)count bar:(double)bar { return [DYYYTabBarMetrics capsuleWidthForCount:count reference:4 barWidth:bar buttonWidth:94 padding:10 accessory:62 inset:16]; }
+ (void)run {
    double portrait = [self width:4 bar:393];
    [self check:portrait > 0 && portrait <= 393 - 62 - 32 reason:@"胶囊和拍摄键不超出可用宽度"];
    double narrow = [self width:4 bar:240];
    [self check:narrow < portrait && [self width:4 bar:393] == portrait reason:@"窄窗口再返回竖屏恢复自然宽度，无测量反馈"];
    [self check:[self width:3 bar:393] < portrait && [self width:2 bar:393] < [self width:3 bar:393] reason:@"移除项目只缩短胶囊，不拉伸按钮"];
    [self check:[self width:1 bar:100] <= 6 && [self width:4 bar:80] == 0 reason:@"极窄窗口连单项也受窗口宽度约束"];
    [self check:[self width:0 bar:393] == 0 && [self width:4 bar:NAN] == 0 reason:@"零项目和无效几何安全退出"];
    NSLog(@"DYYYTabBarMetrics regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYTabBarMetricsTests run]; } return 0; }
