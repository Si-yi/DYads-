#import <Foundation/Foundation.h>
#import "DYYYDetailCaptionMetrics.h"
#import <math.h>

int main(void) {
    @autoreleasepool {
        // 同一 956pt 作品页在上下滑动时可位于屏幕外；输入胶囊仍固定在视口 y=897。
        // 文案/分页线用页内坐标测量，不能与带滚动位移的屏幕坐标相减。
        double pageInput = [DYYYDetailCaptionMetrics pageInputTopForViewportInputTop:897 viewportMinY:0
            viewportHeight:956 pageMinY:0 pageHeight:956];
        NSCAssert(pageInput == 897, @"Adjacent full-page cells share the unchanged input target before display");
        for (NSNumber *offsetValue in @[@(-956), @(-600), @(-200), @0, @200, @600, @956]) {
            double offset = offsetValue.doubleValue;
            double localCaption = (855.1666667 + offset) - offset;
            double localProgress = (871 + offset) - offset;
            double prepared = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:localCaption inputTop:pageInput
                progressBottom:localProgress progressLimit:881 enabled:YES];
            NSCAssert(fabs(prepared - 10) < 0.001, @"Album offset is identical before, during and after either swipe direction");
            double livePrepared = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:(867.1666667 + offset) - offset inputTop:pageInput
                progressBottom:0 progressLimit:881 enabled:YES];
            NSCAssert(fabs(livePrepared - 13.8333333) < 0.001, @"Live photo preparation cannot wait for the cell to reach the viewport center");
        }
        NSCAssert([DYYYDetailCaptionMetrics pageInputTopForViewportInputTop:917 viewportMinY:20
            viewportHeight:956 pageMinY:10 pageHeight:956] == 907, @"Nonzero bounds origins are normalized without moving the input");
        NSCAssert(isnan([DYYYDetailCaptionMetrics pageInputTopForViewportInputTop:897 viewportMinY:0
            viewportHeight:956 pageMinY:0 pageHeight:881]), @"A partial or differently sized page is not guessed into the full-page layout");
        NSCAssert(isnan([DYYYDetailCaptionMetrics pageInputTopForViewportInputTop:NAN viewportMinY:0
            viewportHeight:956 pageMinY:0 pageHeight:956]), @"Invalid viewport geometry cannot create a transient offset");
        // 1.8.3 动图导出：行底 880.6667，时间 UILabel 因 -11pt 偏移实际底边 867.1667。
        double liveBottom = [DYYYDetailCaptionMetrics captionBottomForRowBottom:880.6666667 plainTextBottom:867.1666667];
        double liveShift = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:liveBottom inputTop:897
            progressBottom:0 progressLimit:881 enabled:YES];
        NSCAssert(fabs(liveShift - 13.8333333) < 0.001 && fabs(897 - liveBottom - liveShift - 16) < 0.001,
            @"Live photo spacing uses the visible timestamp rather than the empty row reservation");
        NSCAssert([DYYYDetailCaptionMetrics captionBottomForRowBottom:880 plainTextBottom:NAN] == 880,
            @"Unknown or composite rows retain their native bounds");
        NSCAssert([DYYYDetailCaptionMetrics captionBottomForRowBottom:880 plainTextBottom:0] == 880 &&
            [DYYYDetailCaptionMetrics captionBottomForRowBottom:880 plainTextBottom:600] == 880,
            @"Missing and unexpected text geometry cannot move a row arbitrarily");
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
