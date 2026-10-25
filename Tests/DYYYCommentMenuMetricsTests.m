#import <Foundation/Foundation.h>
#import "DYYYCommentMenuMetrics.h"
#import <math.h>

int main(void) {
    @autoreleasepool {
        double content = 387.2, inset = 16, firstRow = 199.3333333333;
        double normal = [DYYYCommentMenuMetrics compactHeightForContent:content inset:inset firstRowBottom:0 composerHeight:0 maximum:574];
        double selected = [DYYYCommentMenuMetrics compactHeightForContent:content inset:inset firstRowBottom:firstRow composerHeight:160 maximum:574];
        double cancelled = [DYYYCommentMenuMetrics compactHeightForContent:content inset:inset firstRowBottom:0 composerHeight:0 maximum:684];
        NSCAssert(normal == 404 && selected == 376 && cancelled == normal, @"Select/cancel must restore the compact normal height");
        // Keyboard movement may change viewport/composer origins, but their positions are not size inputs.
        for (NSNumber *nativeMaximum in @[ @574, @684, @860 ]) {
            double height = [DYYYCommentMenuMetrics compactHeightForContent:content inset:inset firstRowBottom:firstRow composerHeight:160 maximum:nativeMaximum.doubleValue];
            NSCAssert(height == selected, @"Keyboard-driven native height must not grow the selected panel");
        }
        for (NSUInteger cycle = 0; cycle < 20; cycle++) {
            double a = [DYYYCommentMenuMetrics compactHeightForContent:content inset:inset firstRowBottom:firstRow composerHeight:160 maximum:684];
            double b = [DYYYCommentMenuMetrics compactHeightForContent:content inset:inset firstRowBottom:0 composerHeight:0 maximum:684];
            NSCAssert(a == 376 && b == 404, @"Repeated selection must not accumulate height");
        }
        NSCAssert([DYYYCommentMenuMetrics compactHeightForContent:800 inset:16 firstRowBottom:0 composerHeight:0 maximum:500] == 500, @"Respect native screen-height limits");
        NSCAssert([DYYYCommentMenuMetrics compactHeightForContent:NAN inset:16 firstRowBottom:0 composerHeight:0 maximum:500] == 0, @"Reject invalid geometry");
        NSLog(@"DYYYCommentMenuMetrics regression tests passed");
    }
    return 0;
}
