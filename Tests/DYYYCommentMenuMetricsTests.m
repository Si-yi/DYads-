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
        // Real cancellation failure: raw collection size retains a 160pt input reservation.
        double actualBottom = 303.3333333333;
        double initialContent = [DYYYCommentMenuMetrics contentHeightForActionBottom:actualBottom safeAreaBottom:34 rawContent:335.2];
        double staleContent = [DYYYCommentMenuMetrics contentHeightForActionBottom:actualBottom safeAreaBottom:34 rawContent:495.2];
        NSCAssert(initialContent == staleContent, @"A retained 160pt placeholder must not become menu content");
        double before = [DYYYCommentMenuMetrics compactHeightForContent:initialContent inset:16 firstRowBottom:0 composerHeight:0 maximum:574];
        double after = [DYYYCommentMenuMetrics compactHeightForContent:staleContent inset:16 firstRowBottom:0 composerHeight:0 maximum:684];
        NSCAssert(before == 354 && after == before, @"Six actual actions return to their compact height after cancellation");
        for (NSUInteger cycle = 0; cycle < 20; cycle++) {
            double raw = 335.2 + 160 * (cycle + 1);
            double measured = [DYYYCommentMenuMetrics contentHeightForActionBottom:actualBottom safeAreaBottom:34 rawContent:raw];
            NSCAssert(measured == initialContent, @"Repeated stale reservations cannot accumulate blank space");
        }
        NSCAssert([DYYYCommentMenuMetrics needsUpdateForTarget:354 propertyHeight:354 renderedHeight:514], @"Matching stored height must not hide a stale real shell");
        NSCAssert(![DYYYCommentMenuMetrics needsUpdateForTarget:354 propertyHeight:354 renderedHeight:354], @"Settled geometry needs no repeated layout request");
        NSCAssert([DYYYCommentMenuMetrics needsUpdateForTarget:354 propertyHeight:514 renderedHeight:514], @"Both property and rendered height can need correction");
        NSCAssert([DYYYCommentMenuMetrics contentHeightForActionBottom:0 safeAreaBottom:34 rawContent:335.2] == 335.2, @"Unknown action layout preserves native content");
        NSLog(@"DYYYCommentMenuMetrics regression tests passed");
    }
    return 0;
}
