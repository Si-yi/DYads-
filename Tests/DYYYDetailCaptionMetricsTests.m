#import <Foundation/Foundation.h>
#import "DYYYDetailCaptionMetrics.h"
#import <math.h>

int main(void) {
    @autoreleasepool {
        // 39.5 导出：图片文案视觉底边 868.6667，胶囊顶部 897，分页容器底边 881。
        double plain = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 inputTop:897 progressBottom:0 enabled:YES];
        NSCAssert(fabs(plain - 12.3333333) < 0.001, @"Single photos close the extra gap to 16pt without moving the input");
        double album = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 inputTop:897 progressBottom:881 enabled:YES];
        NSCAssert(fabs(album - 12) < 0.001 && 881 + album <= 897 - 4, @"Album indicator stays above the fixed capsule");
        double settled = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 + plain inputTop:897 progressBottom:0 enabled:YES];
        NSCAssert(fabs(settled) < 0.001, @"Already aligned content cannot keep drifting down");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868 inputTop:897 progressBottom:0 enabled:NO] == 0,
            @"Video/home/disabled/editing contexts never receive a shift");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:885 inputTop:897 progressBottom:0 enabled:YES] == 0,
            @"Tighter native spacing is preserved");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868 inputTop:897 progressBottom:896 enabled:YES] == 0,
            @"No room before the input means no movement");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:880 inputTop:940 progressBottom:0 enabled:YES] == 32,
            @"Changes stay within the bounded caption adjustment");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:600 inputTop:897 progressBottom:0 enabled:YES] == 0,
            @"Unknown large layouts are not pulled toward the bottom");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:NAN inputTop:897 progressBottom:0 enabled:YES] == 0,
            @"Invalid geometry preserves native layout");
        NSLog(@"DYYYDetailCaptionMetrics regression tests passed");
    }
    return 0;
}
