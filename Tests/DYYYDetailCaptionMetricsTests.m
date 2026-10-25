#import <Foundation/Foundation.h>
#import "DYYYDetailCaptionMetrics.h"
#import <math.h>

int main(void) {
    @autoreleasepool {
        // 39.5 导出：图片文案视觉底边 868.6667，胶囊顶部 897，分页条底边 871、原生 HUD 底边 881。
        double plain = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 inputTop:897 progressBottom:0 progressLimit:0 enabled:YES];
        NSCAssert(fabs(plain - 12.3333333) < 0.001, @"Single photos close the extra gap to 16pt without moving the input");
        double album = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 inputTop:897 progressBottom:871 progressLimit:881 enabled:YES];
        NSCAssert(fabs(album - 10) < 0.001 && 871 + album <= 881 && 871 + album <= 897 - 4, @"Album indicator stays above the fixed capsule");
        double settledAlbum = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 + album inputTop:897
            progressBottom:871 + album progressLimit:881 enabled:YES];
        NSCAssert(fabs(settledAlbum) < 0.001, @"Repeated layouts cannot push the album line beyond its native touch bounds");
        double settled = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868.6666667 + plain inputTop:897 progressBottom:0 progressLimit:0 enabled:YES];
        NSCAssert(fabs(settled) < 0.001, @"Already aligned content cannot keep drifting down");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868 inputTop:897 progressBottom:0 progressLimit:0 enabled:NO] == 0,
            @"Video/home/disabled/editing contexts never receive a shift");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:885 inputTop:897 progressBottom:0 progressLimit:0 enabled:YES] == 0,
            @"Tighter native spacing is preserved");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:868 inputTop:897 progressBottom:896 progressLimit:956 enabled:YES] == 0,
            @"No room before the input means no movement");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:880 inputTop:940 progressBottom:0 progressLimit:0 enabled:YES] == 32,
            @"Changes stay within the bounded caption adjustment");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:600 inputTop:897 progressBottom:0 progressLimit:0 enabled:YES] == 0,
            @"Unknown large layouts are not pulled toward the bottom");
        NSCAssert([DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:NAN inputTop:897 progressBottom:0 progressLimit:0 enabled:YES] == 0,
            @"Invalid geometry preserves native layout");
        NSLog(@"DYYYDetailCaptionMetrics regression tests passed");
    }
    return 0;
}
