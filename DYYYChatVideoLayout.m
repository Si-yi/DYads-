/*
  聊天视频原生背景延伸参考 DYKiller：
  src/Features/PlaybackClean/DKVideoPageChrome.xm
  src/Features/PlaybackClean/DKPlaybackCleanRules.m
  https://github.com/HierarchThurs/DYKiller/tree/bb11ab1d9cba9733d6720f0e2746dec21d6c6fe4

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
#import "DYYYChatVideoLayout.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYChatReplyBackgroundKey;
static char kDYYYChatVideoBackdropKey;

@interface DYYYChatVideoBackdropState : NSObject
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic, weak) UIView *canvas;
@end
@implementation DYYYChatVideoBackdropState
@end

@implementation DYYYChatVideoLayout

+ (UIViewController *)detailForController:(UIViewController *)controller {
    Class detail = NSClassFromString(@"AWEAwemeIMDetailTableViewController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController) {
        if (detail && [controller isKindOfClass:detail]) return controller;
    }
    return nil;
}
+ (BOOL)usesNativePagingForController:(UIViewController *)controller {
    return [self detailForController:controller] != nil;
}
// 聊天视频只管理背景绘制；分页表、Cell、播放器与交互层的尺寸全部交还原生。
+ (BOOL)ownsReplyBackground:(UIView *)view {
    return objc_getAssociatedObject(view, &kDYYYChatReplyBackgroundKey) != nil && [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"];
}
+ (void)updateReplyBackground:(UIViewController *)controller {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self updateReplyBackground:controller]; }); return; }
    if (!controller.isViewLoaded) return;
    UIView *view = controller.view;
    NSDictionary *saved = objc_getAssociatedObject(view, &kDYYYChatReplyBackgroundKey);
    BOOL clear = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"] && [self detailForController:controller];
    if (clear) {
        if (!saved) objc_setAssociatedObject(view, &kDYYYChatReplyBackgroundKey,
            @{ @"color": view.backgroundColor ?: NSNull.null, @"opaque": @(view.opaque) }, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (![view.backgroundColor isEqual:UIColor.clearColor]) view.backgroundColor = UIColor.clearColor;
        if (view.opaque) view.opaque = NO;
    } else if (saved) {
        objc_setAssociatedObject(view, &kDYYYChatReplyBackgroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.backgroundColor = saved[@"color"] == NSNull.null ? nil : saved[@"color"];
        view.opaque = [saved[@"opaque"] boolValue];
    }
}

+ (NSHashTable *)backdropOwners {
    static NSHashTable *owners;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ owners = [NSHashTable weakObjectsHashTable]; });
    return owners;
}
+ (void)removePlayerBackdrop:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYChatVideoBackdropState *state = objc_getAssociatedObject(controller, &kDYYYChatVideoBackdropKey);
    [state.layer removeFromSuperlayer];
    objc_setAssociatedObject(controller, &kDYYYChatVideoBackdropKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (void)syncPlayerBackdrop:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller.isViewLoaded) return;
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"] && [self detailForController:controller];
    Class rich = NSClassFromString(@"RichContentContainerViewController");
    for (UIViewController *parent = controller; parent; parent = parent.parentViewController) {
        if (rich && [parent isKindOfClass:rich]) { enabled = NO; break; }
    }
    if (!enabled || !controller.view.window || controller.view.hidden || controller.view.alpha < 0.01) { [self removePlayerBackdrop:controller]; return; }
    id background = nil;
    @try {
        NSString *key = [controller respondsToSelector:@selector(getPlayerBackgroundView)] ? @"getPlayerBackgroundView" : @"playerBackgroundView";
        background = [controller valueForKey:key];
    } @catch (__unused NSException *e) {}
    UIColor *color = [background isKindOfClass:UIView.class] && ((UIView *)background).superview && !((UIView *)background).hidden ? ((UIView *)background).backgroundColor : nil;
    // 原生播放器智能背景是唯一色源，不按主题硬编码黑色，也不对视频截图取样。
    if (!color || CGColorGetAlpha(color.CGColor) < 0.98) { [self removePlayerBackdrop:controller]; return; }
    UIView *anchor = controller.view;
    UIView *cell = nil;
    UIView *candidate = anchor.superview;
    for (NSUInteger depth = 0; candidate && depth < 12; depth++, candidate = candidate.superview) {
        UIView *parent = candidate;
        if ([parent isKindOfClass:UITableViewCell.class]) { cell = ((UITableViewCell *)parent).contentView; break; }
        if (parent == [self detailForController:controller].view) break;
    }
    if (!cell) { [self removePlayerBackdrop:controller]; return; }
    UIView *canvas = nil;
    CGRect fill = CGRectZero;
    UIView *parent = anchor.superview;
    for (NSUInteger depth = 0; parent && depth < 12; depth++, parent = parent.superview) {
        CGRect content = [anchor convertRect:anchor.bounds toView:parent];
        CGFloat bottom = CGRectGetMaxY(content), end = CGRectGetMaxY(parent.bounds);
        if (isfinite(bottom) && end > bottom + 0.5) {
            canvas = parent;
            fill = CGRectMake(CGRectGetMinX(parent.bounds), MAX(CGRectGetMinY(parent.bounds), bottom), parent.bounds.size.width, end - MAX(CGRectGetMinY(parent.bounds), bottom));
            break;
        }
        if (parent == cell) break;
    }
    if (!canvas || CGRectIsEmpty(fill)) { [self removePlayerBackdrop:controller]; return; }
    DYYYChatVideoBackdropState *state = objc_getAssociatedObject(controller, &kDYYYChatVideoBackdropKey);
    if (!state || state.canvas != canvas) {
        [self removePlayerBackdrop:controller];
        state = [DYYYChatVideoBackdropState new]; state.canvas = canvas; state.layer = [CALayer layer];
        state.layer.name = @"DYYYChatNativeVideoBackdrop";
        [canvas.layer insertSublayer:state.layer atIndex:0];
        objc_setAssociatedObject(controller, &kDYYYChatVideoBackdropKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self backdropOwners] addObject:controller];
    }
    UIColor *resolved = [color resolvedColorWithTraitCollection:canvas.traitCollection];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!CGRectEqualToRect(state.layer.frame, fill)) state.layer.frame = fill;
    if (!state.layer.backgroundColor || !CGColorEqualToColor(state.layer.backgroundColor, resolved.CGColor)) state.layer.backgroundColor = resolved.CGColor;
    [CATransaction commit];
}
+ (void)refresh {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; }); return; }
    for (UIViewController *owner in [self backdropOwners].allObjects) [self syncPlayerBackdrop:owner];
}
@end
