/*
背景底边取样参考 DYKiller/src/Features/VideoFullscreen/DKFeedCardFit.m。
https://github.com/HierarchThurs/DYKiller

MIT License

Copyright (c) 2026 Hierarch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
#import "DYYYArticleBackdrop.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <stdint.h>

@implementation DYYYArticleBackdropView
@end

@implementation DYYYArticleBackdrop

+ (BOOL)isHomeArticle:(UIViewController *)controller {
    BOOL article = NO, home = NO;
    for (NSUInteger depth = 0; controller && depth < 16; depth++, controller = controller.parentViewController) {
        NSString *name = NSStringFromClass(controller.class);
        if ([name isEqualToString:@"AWEFeedGeneralArticleCellViewController"]) article = YES;
        if ([name isEqualToString:@"AWEFeedRootViewController"]) home = YES;
    }
    return article && home;
}

+ (DYYYArticleBackdropView *)stripInRoot:(UIView *)root {
    for (UIView *view in root.subviews)
        if ([view isKindOfClass:DYYYArticleBackdropView.class]) return (DYYYArticleBackdropView *)view;
    return nil;
}

+ (CGFloat)contentBottomInRoot:(UIView *)root {
    // 外层 AnnieX/Lynx 容器已满高，真正的文章视口仍是内层 UILynxView。
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    CGFloat height = CGRectGetHeight(root.bounds);
    for (NSUInteger index = 0; index < queue.count && index < 32; index++) {
        UIView *view = queue[index];
        if (view.hidden || view.alpha <= 0.01 || [view isKindOfClass:DYYYArticleBackdropView.class]) continue;
        if ([NSStringFromClass(view.class) isEqualToString:@"LynxView"]) {
            for (UIView *content in view.subviews) {
                if (content.hidden || content.alpha <= 0.01 ||
                    ![NSStringFromClass(content.class) isEqualToString:@"UILynxView"]) continue;
                CGRect rect = [content convertRect:content.bounds toView:root];
                CGFloat bottom = CGRectGetMaxY(rect);
                if (fabs(CGRectGetMinX(rect) - CGRectGetMinX(root.bounds)) <= 0.5 &&
                    fabs(CGRectGetWidth(rect) - CGRectGetWidth(root.bounds)) <= 0.5 &&
                    fabs(CGRectGetMinY(rect) - CGRectGetMinY(root.bounds)) <= 0.5 &&
                    CGRectGetHeight(rect) > height * 0.5 && isfinite(bottom)) return bottom;
            }
            continue;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return CGRectGetMaxY(root.bounds);
}

+ (void)sampleRoot:(UIView *)root strip:(DYYYArticleBackdropView *)strip {
    if (!root.window || [self stripInRoot:root] != strip) return;
    CGFloat scale = root.traitCollection.displayScale;
    if (!isfinite(scale) || scale <= 0) return;
    // 文章正文背景可能先于视口结束；向上最多找 160 点，跳过透明行。
    CGFloat end = floor(strip.contentBottom * scale) / scale;
    CGFloat depth = MIN(160.0, end - CGRectGetMinY(root.bounds));
    if (depth <= 0 || CGRectGetWidth(root.bounds) <= 0) return;
    size_t width = (size_t)floor(CGRectGetWidth(root.bounds) * scale);
    size_t height = (size_t)ceil(depth * scale);
    if (!width || !height) return;
    CGFloat top = end - height / scale;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (!space) return;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
        kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return;
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, -scale);
    CGContextTranslateCTM(context, -CGRectGetMinX(root.bounds), -top);
    BOOL hidden = strip.layer.hidden;
    strip.layer.hidden = YES;
    [root.layer renderInContext:context];
    strip.layer.hidden = hidden;
    const uint8_t *pixels = CGBitmapContextGetData(context);
    size_t stride = CGBitmapContextGetBytesPerRow(context);
    UIImage *image = nil;
    CGFloat bottom = end;
    for (size_t row = height; row > 0; row--) {
        const uint8_t *line = pixels + (row - 1) * stride;
        BOOL opaque = YES;
        for (size_t x = 0; x < width; x++) {
            if (line[x * 4 + 3] != UINT8_MAX) { opaque = NO; break; }
        }
        if (!opaque) continue;
        CGImageRef snapshot = CGBitmapContextCreateImage(context);
        CGImageRef sample = snapshot ? CGImageCreateWithImageInRect(snapshot, CGRectMake(0, row - 1, width, 1)) : NULL;
        if (sample) {
            image = [UIImage imageWithCGImage:sample scale:scale orientation:UIImageOrientationUp];
            CGImageRelease(sample);
        }
        if (snapshot) CGImageRelease(snapshot);
        bottom = top + row / scale;
        break;
    }
    CGContextRelease(context);
    strip.image = image;
    strip.hidden = image == nil;
    if (image) strip.frame = CGRectMake(CGRectGetMinX(root.bounds), bottom,
        CGRectGetWidth(root.bounds), CGRectGetMaxY(root.bounds) - bottom);
}

+ (void)scheduleRoot:(UIView *)root strip:(DYYYArticleBackdropView *)strip delayed:(BOOL)delayed {
    if (delayed ? strip.resamplePending : strip.samplePending) return;
    if (delayed) strip.resamplePending = YES;
    else strip.samplePending = YES;
    __weak UIView *weakRoot = root;
    __weak DYYYArticleBackdropView *weakStrip = strip;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delayed ? 0.6 : 0.05) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *host = weakRoot;
        DYYYArticleBackdropView *current = weakStrip;
        if (!host || !current || [self stripInRoot:host] != current) return;
        if (delayed) current.resamplePending = NO;
        else current.samplePending = NO;
        if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"]) {
            [current removeFromSuperview];
            return;
        }
        [self sampleRoot:host strip:current];
    });
}

+ (void)removeFromController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    [[self stripInRoot:controller.viewIfLoaded] removeFromSuperview];
}

+ (void)synchronizeController:(UIViewController *)controller refresh:(BOOL)refresh {
    if (!NSThread.isMainThread) return;
    UIView *root = controller.viewIfLoaded;
    if (!root) return;
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"] ||
        ![self isHomeArticle:controller] || CGRectGetHeight(root.bounds) <= CGRectGetWidth(root.bounds)) {
        [self removeFromController:controller];
        return;
    }
    CGFloat bottom = [self contentBottomInRoot:root];
    CGFloat gap = CGRectGetMaxY(root.bounds) - bottom;
    if (!isfinite(gap) || gap <= 0.5 || gap > 160) {
        [self removeFromController:controller];
        return;
    }
    DYYYArticleBackdropView *strip = [self stripInRoot:root];
    if (!strip) {
        strip = [[DYYYArticleBackdropView alloc] initWithFrame:CGRectZero];
        strip.userInteractionEnabled = NO;
        strip.isAccessibilityElement = NO;
        strip.contentMode = UIViewContentModeScaleToFill;
        strip.hidden = YES;
        [root insertSubview:strip atIndex:0];
        refresh = YES;
    }
    if (root.subviews.firstObject != strip) [root insertSubview:strip atIndex:0];
    if (strip.contentBottom != bottom || !CGRectEqualToRect(strip.sourceBounds, root.bounds)) {
        strip.contentBottom = bottom;
        strip.sourceBounds = root.bounds;
        strip.image = nil;
        strip.hidden = YES;
        strip.frame = CGRectMake(CGRectGetMinX(root.bounds), bottom, CGRectGetWidth(root.bounds), gap);
        refresh = YES;
    }
    if (refresh) {
        [self scheduleRoot:root strip:strip delayed:NO];
        [self scheduleRoot:root strip:strip delayed:YES];
    }
}
@end
