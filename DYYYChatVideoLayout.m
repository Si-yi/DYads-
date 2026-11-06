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
#import "DYYYVideoPageMetrics.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYChatReplyBackgroundKey;
static char kDYYYChatVideoBackdropKey;
static char kDYYYChatVideoPaintKey, kDYYYChatVideoPaintBusyKey;

@interface DYYYChatVideoPaintState : NSObject
@property (nonatomic, weak) UIView *surface;
@property (nonatomic) CATransform3D nativeTransform;
@property (nonatomic) CATransform3D appliedTransform;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *clips;
@property (nonatomic, copy) NSDictionary *plan;
@end
@implementation DYYYChatVideoPaintState
@end

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
    // 回复栏可能晚于播放器挂载；跟随这次原生布局补绘制，不强制新布局或排队轮询。
    UIViewController *detail = [self detailForController:controller];
    NSMutableArray *queue = [NSMutableArray arrayWithArray:detail.childViewControllers ?: @[]];
    for (NSUInteger index = 0; index < queue.count && index < 24; index++) {
        UIViewController *child = queue[index];
        if ([child isKindOfClass:NSClassFromString(@"AWEPlayVideoViewController")]) {
            if (child.viewIfLoaded.window) [self syncPlayerBackdrop:child];
        } else for (UIViewController *next in child.childViewControllers)
            if (queue.count < 24 && ![queue containsObject:next]) [queue addObject:next];
    }
}

+ (NSHashTable *)backdropOwners {
    static NSHashTable *owners;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ owners = [NSHashTable weakObjectsHashTable]; });
    return owners;
}
+ (void)removePlayerBackdrop:(UIViewController *)controller {
    [self restoreVideoPaint:controller];
    [self removeBackdropOnly:controller];
}
+ (void)restoreVideoPaint:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYChatVideoPaintState *state = objc_getAssociatedObject(controller, &kDYYYChatVideoPaintKey);
    if (!state) return;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    CALayer *surfaceLayer = state.surface.layer;
    if (surfaceLayer && CATransform3DEqualToTransform(surfaceLayer.sublayerTransform, state.appliedTransform))
        surfaceLayer.sublayerTransform = state.nativeTransform;
    for (UIView *view in state.clips.keyEnumerator.allObjects)
        if (!view.layer.masksToBounds) view.layer.masksToBounds = [[state.clips objectForKey:view] boolValue];
    [CATransaction commit];
    objc_setAssociatedObject(controller, &kDYYYChatVideoPaintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (void)synchronizeVideoPaint:(UIViewController *)controller {
    UIViewController *detail = [self detailForController:controller];
    UIView *root = controller.viewIfLoaded;
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"];
    if (!enabled || !detail || !root.window || root.hidden || root.alpha <= 0.01) { [self restoreVideoPaint:controller]; return; }
    for (UIViewController *parent = controller; parent; parent = parent.parentViewController)
        if ([parent isKindOfClass:NSClassFromString(@"RichContentContainerViewController")]) { [self restoreVideoPaint:controller]; return; }
    UIView *surface = nil, *page = nil;
    for (UIView *view in root.subviews) if ([NSStringFromClass(view.class) isEqual:@"TTPlayerView"]) { surface = view; break; }
    UIView *ancestor = root;
    for (NSUInteger depth = 0; ancestor && depth < 12; depth++, ancestor = ancestor.superview)
        if ([ancestor isKindOfClass:UITableViewCell.class]) { page = ((UITableViewCell *)ancestor).contentView; break; }
    UIView *reply = nil;
    for (UIViewController *child in detail.childViewControllers)
        if ([child isKindOfClass:NSClassFromString(@"AWEIMFeedVideoQuickReplayInputViewController")]) { reply = child.viewIfLoaded; break; }
    BOOL metal = NO;
    for (UIView *view in surface.subviews) {
        NSString *name = NSStringFromClass(view.class);
        if (([name isEqual:@"TTMetalView"] || [name isEqual:@"TTMetalViewNew"] || [name isEqual:@"TTMetalViewVP"]) &&
            !view.hidden && view.alpha > 0.01 && [view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")] && fabs(view.bounds.size.height - surface.bounds.size.height) <= 0.5 &&
            view.bounds.size.width >= surface.bounds.size.width - 0.5 && CGAffineTransformIsIdentity(view.transform)) metal = YES;
    }
    CGRect rect = surface && page ? [surface convertRect:surface.bounds toView:page] : CGRectNull;
    BOOL aligned = page && surface && reply.superview == detail.viewIfLoaded && !reply.hidden && reply.alpha > 0.01 && metal &&
        surface.subviews.count == 1 && CGAffineTransformIsIdentity(surface.transform) &&
        fabs(surface.bounds.origin.x) < 0.5 && fabs(surface.bounds.origin.y) < 0.5 &&
        fabs(surface.layer.anchorPoint.x - 0.5) < 0.001 && fabs(surface.layer.anchorPoint.y - 0.5) < 0.001 &&
        fabs(rect.origin.x - page.bounds.origin.x) < 0.5 && fabs(rect.origin.y - page.bounds.origin.y) < 0.5 &&
        fabs(page.bounds.size.height - detail.viewIfLoaded.bounds.size.height) < 0.5;
    NSDictionary *plan = aligned ? [DYYYVideoPageMetrics paintExtensionForWidth:surface.bounds.size.width height:surface.bounds.size.height
        pageWidth:page.bounds.size.width pageHeight:page.bounds.size.height replyTop:reply.frame.origin.y
        replyHeight:reply.bounds.size.height enabled:enabled] : @{};
    if (!plan.count) { [self restoreVideoPaint:controller]; return; }
    NSMutableArray<UIView *> *path = [NSMutableArray array];
    ancestor = surface;
    for (NSUInteger depth = 0; ancestor && ancestor != page && depth < 12; depth++, ancestor = ancestor.superview) {
        if (ancestor.layer.mask || ancestor.layer.cornerRadius > 0 || !CGAffineTransformIsIdentity(ancestor.transform)) { [self restoreVideoPaint:controller]; return; }
        [path addObject:ancestor];
    }
    if (ancestor != page) { [self restoreVideoPaint:controller]; return; }
    DYYYChatVideoPaintState *state = objc_getAssociatedObject(controller, &kDYYYChatVideoPaintKey);
    if (state && state.surface != surface) { [self restoreVideoPaint:controller]; state = nil; }
    CATransform3D current = surface.layer.sublayerTransform;
    if ((state && !CATransform3DEqualToTransform(current, state.appliedTransform)) || (!state && !CATransform3DIsIdentity(current))) {
        [self restoreVideoPaint:controller]; return;
    }
    if (!state) {
        state = [DYYYChatVideoPaintState new]; state.surface = surface; state.nativeTransform = current;
        state.clips = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(controller, &kDYYYChatVideoPaintKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self backdropOwners] addObject:controller];
    }
    CATransform3D transform = CATransform3DMakeScale([plan[@"scale"] doubleValue], [plan[@"scale"] doubleValue], 1);
    transform.m42 = [plan[@"translateY"] doubleValue];
    state.appliedTransform = transform; state.plan = plan;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!CATransform3DEqualToTransform(surface.layer.sublayerTransform, transform)) surface.layer.sublayerTransform = transform;
    for (UIView *view in path) if (view.layer.masksToBounds) {
        if (![state.clips objectForKey:view]) [state.clips setObject:@YES forKey:view];
        view.layer.masksToBounds = NO;
    }
    [CATransaction commit];
}
+ (void)removeBackdropOnly:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYChatVideoBackdropState *state = objc_getAssociatedObject(controller, &kDYYYChatVideoBackdropKey);
    [state.layer removeFromSuperlayer];
    objc_setAssociatedObject(controller, &kDYYYChatVideoBackdropKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (void)syncPlayerBackdrop:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller.isViewLoaded) return;
    if ([objc_getAssociatedObject(controller, &kDYYYChatVideoPaintBusyKey) boolValue]) return;
    objc_setAssociatedObject(controller, &kDYYYChatVideoPaintBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        [self synchronizeVideoPaint:controller];
        [self synchronizeBackdropOnly:controller];
    } @finally {
        objc_setAssociatedObject(controller, &kDYYYChatVideoPaintBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
+ (void)synchronizeBackdropOnly:(UIViewController *)controller {
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"] && [self detailForController:controller];
    Class rich = NSClassFromString(@"RichContentContainerViewController");
    for (UIViewController *parent = controller; parent; parent = parent.parentViewController) {
        if (rich && [parent isKindOfClass:rich]) { enabled = NO; break; }
    }
    if (!enabled || !controller.view.window || controller.view.hidden || controller.view.alpha < 0.01) { [self removeBackdropOnly:controller]; return; }
    id background = nil;
    @try {
        NSString *key = [controller respondsToSelector:@selector(getPlayerBackgroundView)] ? @"getPlayerBackgroundView" : @"playerBackgroundView";
        background = [controller valueForKey:key];
    } @catch (__unused NSException *e) {}
    UIColor *color = [background isKindOfClass:UIView.class] && ((UIView *)background).superview && !((UIView *)background).hidden ? ((UIView *)background).backgroundColor : nil;
    // 原生播放器智能背景是唯一色源，不按主题硬编码黑色，也不对视频截图取样。
    if (!color || CGColorGetAlpha(color.CGColor) < 0.98) { [self removeBackdropOnly:controller]; return; }
    UIView *anchor = controller.view;
    UIView *cell = nil;
    UIView *candidate = anchor.superview;
    for (NSUInteger depth = 0; candidate && depth < 12; depth++, candidate = candidate.superview) {
        UIView *parent = candidate;
        if ([parent isKindOfClass:UITableViewCell.class]) { cell = ((UITableViewCell *)parent).contentView; break; }
        if (parent == [self detailForController:controller].view) break;
    }
    if (!cell) { [self removeBackdropOnly:controller]; return; }
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
    if (!canvas || CGRectIsEmpty(fill)) { [self removeBackdropOnly:controller]; return; }
    DYYYChatVideoBackdropState *state = objc_getAssociatedObject(controller, &kDYYYChatVideoBackdropKey);
    if (!state || state.canvas != canvas) {
        [self removeBackdropOnly:controller];
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
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSMutableArray *states = [NSMutableArray array];
    for (UIViewController *owner in [self backdropOwners].allObjects) {
        if (!owner.viewIfLoaded.window || states.count >= 8) continue;
        DYYYChatVideoPaintState *paint = objc_getAssociatedObject(owner, &kDYYYChatVideoPaintKey);
        [states addObject:@{@"paintActive":@(paint != nil), @"plan":paint.plan ?: @{},
            @"nativeSurfaceFrame":NSStringFromCGRect(paint.surface ? paint.surface.frame : CGRectZero),
            @"nativePlayerBounds":NSStringFromCGRect(owner.viewIfLoaded.bounds),
            @"overflowLayers":@(paint.clips.count)}];
    }
    return @{@"nativePagingGeometry":@YES, @"viewGeometryWrites":@NO, @"states":states};
}
@end
