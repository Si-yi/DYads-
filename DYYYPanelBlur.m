/*
面板层级识别参考 DYKiller/src/Features/Share/DKSharePanelGlass.xm。
使用与 DYYY 评论区相同的普通 UIBlurEffect，不要求 iOS 26。

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
#import "DYYYPanelBlur.h"
#import "DYYYUtils.h"
#import "DYYYCommentMenuPalette.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

static char kDYYYPanelBlurStateKey;
static char kDYYYPanelBlurChangesKey;
static char kDYYYPanelBlurOwnerKey;

@interface DYYYPanelBlurEffectView : UIVisualEffectView
@end
@implementation DYYYPanelBlurEffectView
@end

@interface DYYYPanelBlurState : NSObject
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UIView *host;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIView *tint;
@property (nonatomic, strong) NSHashTable *objects;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) BOOL dark;
@property (nonatomic, assign) CGFloat transparency;
@end
@implementation DYYYPanelBlurState
@end

@implementation DYYYPanelBlur

+ (BOOL)isManagedEffectView:(UIView *)view {
    return [view isKindOfClass:DYYYPanelBlurEffectView.class];
}

+ (NSHashTable<UIViewController *> *)controllers {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}

+ (BOOL)isComment:(UIViewController *)controller {
    return [NSStringFromClass(controller.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet"];
}

+ (UIViewController *)ownerForController:(UIViewController *)controller {
    Class share = NSClassFromString(@"AWESharePanelContainerViewController");
    Class legacy = NSClassFromString(@"AWESharePanelController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController)
        if ([self isComment:controller] || (share && [controller isKindOfClass:share]) ||
            (legacy && [controller isKindOfClass:legacy])) return controller;
    return nil;
}

+ (BOOL)enabledForController:(UIViewController *)controller {
    NSString *key = [self isComment:controller] ? @"DYYYEnableCommentMenuBlur" : @"DYYYEnableSharePanelBlur";
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}

+ (BOOL)equal:(id)left other:(id)right {
    return left == right || [left isEqual:right];
}

+ (void)write:(id)value key:(NSString *)key object:(id)object state:(DYYYPanelBlurState *)state {
    if (!object || !value) return;
    @try {
        id current = [object valueForKey:key] ?: NSNull.null;
        DYYYPanelBlurState *owner = objc_getAssociatedObject(object, &kDYYYPanelBlurOwnerKey);
        if (owner && owner != state) {
            [owner.objects removeObject:object];
            [state.objects addObject:object];
            objc_setAssociatedObject(object, &kDYYYPanelBlurOwnerKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if ([self equal:current other:value]) return;
        NSMutableDictionary *changes = objc_getAssociatedObject(object, &kDYYYPanelBlurChangesKey);
        if (!changes) {
            changes = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(object, &kDYYYPanelBlurChangesKey, changes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSDictionary *previous = changes[key];
        id original = previous && [self equal:current other:previous[@"applied"]] ? previous[@"original"] : current;
        changes[key] = @{ @"original": original, @"applied": value };
        [state.objects addObject:object];
        objc_setAssociatedObject(object, &kDYYYPanelBlurOwnerKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [object setValue:value == NSNull.null ? nil : value forKey:key];
    } @catch (__unused NSException *exception) {}
}

+ (BOOL)isNeutralFill:(UIColor *)color state:(DYYYPanelBlurState *)state {
    if (!color) return NO;
    UIColor *resolved = [color resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:
        state.dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight]];
    CGFloat r, g, b, a;
    return [resolved getRed:&r green:&g blue:&b alpha:&a] && a > 0.9 &&
        MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) < 0.12;
}

+ (void)clearView:(UIView *)root state:(DYYYPanelBlurState *)state {
    if (!root || state.busy) return;
    state.busy = YES;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try {
        Class card = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
        CGFloat panelWidth = CGRectGetWidth(state.host.bounds);
        for (NSUInteger index = 0; index < queue.count && index < 600; index++) {
            UIView *view = queue[index];
            if (view == state.blur || [DYYYCommentMenuPalette isManagedSelectionOverlay:view] || [view isKindOfClass:UIImageView.class]) continue;
            if ([view isKindOfClass:UILabel.class]) {
                if (state.dark) [DYYYCommentMenuPalette applyLabel:(UILabel *)view controller:state.controller];
                continue;
            }
            if (card && [view isKindOfClass:card]) {
                CALayer *shape = [DYYYCommentMenuPalette cardLayerInCell:view];
                // 保留卡片分组轮廓，但让背后的整块毛玻璃透出来。
                if (shape) [self write:@(state.transparency * 0.25) key:@"opacity" object:shape state:state];
            }
            // 只清面板的大块中性底色，保留彩色发送按钮、徽标和图片。
            if (![view isKindOfClass:UIControl.class] && view.alpha >= 0.95 && CGRectGetWidth(view.bounds) >= panelWidth * 0.5 &&
                CGRectGetHeight(view.bounds) >= 16 && [self isNeutralFill:view.backgroundColor state:state]) {
                [self write:UIColor.clearColor key:@"backgroundColor" object:view state:state];
                [self write:@NO key:@"opaque" object:view state:state];
            }
            if ([view isKindOfClass:UIVisualEffectView.class]) {
                UIVisualEffectView *effect = (UIVisualEffectView *)view;
                [self write:NSNull.null key:@"effect" object:effect state:state];
                [queue addObject:effect.contentView];
                continue;
            }
            [queue addObjectsFromArray:view.subviews];
        }
    } @finally {
        [CATransaction commit];
        state.busy = NO;
    }
}

+ (UIView *)hostForLegacyController:(UIViewController *)controller {
    UIView *root = controller.viewIfLoaded;
    if (!root.window) return nil;
    CGRect windowRect = [root convertRect:root.bounds toView:root.window];
    CGFloat screenHeight = CGRectGetHeight(root.window.bounds);
    // 有些版本的根视图就是半屏内容，另一些版本在全屏根视图里放底部面板。
    if (CGRectGetMinY(windowRect) >= screenHeight * 0.15 &&
        CGRectGetMaxY(windowRect) <= CGRectGetMaxY(root.window.bounds) + 1 &&
        CGRectGetHeight(windowRect) >= 120 && CGRectGetWidth(windowRect) >= CGRectGetWidth(root.window.bounds) * 0.85)
        return root;
    UIView *best = nil;
    CGFloat bestHeight = 0;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger index = 0; index < queue.count && index < 128; index++) {
        UIView *view = queue[index];
        if (view.hidden || view.alpha <= 0.01 || [self isManagedEffectView:view]) continue;
        if ([view isKindOfClass:UIControl.class] || [view isKindOfClass:UIImageView.class] || [view isKindOfClass:UILabel.class]) continue;
        CGRect rect = [view convertRect:view.bounds toView:root];
        CGFloat height = CGRectGetHeight(rect);
        // 仅在已确认的分享控制器内认底部宽面板，不把整屏遮罩或单个按钮当成宿主。
        if (view != root && view.subviews.count && CGRectGetMinY(rect) >= CGRectGetMinY(root.bounds) + CGRectGetHeight(root.bounds) * 0.15 &&
            fabs(CGRectGetMaxY(rect) - CGRectGetMaxY(root.bounds)) <= 1 &&
            fabs(CGRectGetMidX(rect) - CGRectGetMidX(root.bounds)) <= 1 &&
            CGRectGetWidth(rect) >= CGRectGetWidth(root.bounds) * 0.85 && height >= 120 && height > bestHeight) {
            best = [view isKindOfClass:UIVisualEffectView.class] ? ((UIVisualEffectView *)view).contentView : view;
            bestHeight = height;
        }
        if ([view isKindOfClass:UIVisualEffectView.class]) [queue addObject:((UIVisualEffectView *)view).contentView];
        else [queue addObjectsFromArray:view.subviews];
    }
    return best;
}

+ (UIView *)hostForController:(UIViewController *)controller {
    Class legacy = NSClassFromString(@"AWESharePanelController");
    if (legacy && [controller isKindOfClass:legacy]) return [self hostForLegacyController:controller];
    // 分享页的实底在内容控制器里。毛玻璃必须挂在这里，不能放在整套导航外壳后方。
    if (![self isComment:controller]) {
        Class contentClass = NSClassFromString(@"AWESharePanelViewController");
        NSMutableArray<UIViewController *> *queue = [NSMutableArray arrayWithObject:controller];
        for (NSUInteger index = 0; index < queue.count && index < 24; index++) {
            UIViewController *child = queue[index];
            if (contentClass && [child isKindOfClass:contentClass] && child.viewIfLoaded &&
                [child.viewIfLoaded isDescendantOfView:controller.viewIfLoaded]) return child.viewIfLoaded;
            if ([child isKindOfClass:UINavigationController.class]) {
                UIViewController *top = ((UINavigationController *)child).topViewController;
                if (top) [queue addObject:top];
            } else {
                [queue addObjectsFromArray:child.childViewControllers];
            }
        }
        // 等实际分享内容页就绪，避免把毛玻璃错误铺在全屏遮罩上。
        return nil;
    }
    Class shell = NSClassFromString(@"DUXVisualEffectView");
    for (UIView *view in controller.viewIfLoaded.subviews) {
        if (shell && [view isKindOfClass:shell])
            return [view isKindOfClass:UIVisualEffectView.class] ? ((UIVisualEffectView *)view).contentView : view;
    }
    // 外壳还未创建时不把玻璃铺到整个屏幕，等待下一次原生布局。
    return nil;
}

+ (void)synchronizeController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    controller = [self ownerForController:controller];
    if (!controller) return;
    if (![self enabledForController:controller]) {
        [self restoreController:controller];
        return;
    }
    [[self controllers] addObject:controller];
    UIView *host = [self hostForController:controller];
    if (!host || CGRectIsEmpty(host.bounds)) return;
    DYYYPanelBlurState *state = objc_getAssociatedObject(controller, &kDYYYPanelBlurStateKey);
    if (state && state.host != host) {
        [self restoreController:controller];
        state = nil;
    }
    if (!state) {
        state = [DYYYPanelBlurState new];
        state.controller = controller;
        state.host = host;
        state.objects = [NSHashTable weakObjectsHashTable];
        state.blur = [[DYYYPanelBlurEffectView alloc] initWithEffect:nil];
        state.blur.userInteractionEnabled = NO;
        state.blur.isAccessibilityElement = NO;
        state.blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        state.tint = [UIView new];
        state.tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [state.blur.contentView addSubview:state.tint];
        objc_setAssociatedObject(controller, &kDYYYPanelBlurStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self controllers] addObject:controller];
    }
    if (state.busy) return;
    state.busy = YES;
    @try {
        // DUX 的原生 contentColor 会在布局/主题刷新时重新铺底；直接保存并清除其源值。
        if ([controller respondsToSelector:@selector(contentColor)] &&
            [controller respondsToSelector:@selector(setContentColor:)])
            [self write:UIColor.clearColor key:@"contentColor" object:controller state:state];
        BOOL dark = [DYYYUtils isDarkMode];
        if (state.dark != dark && ![self isComment:controller])
            [DYYYCommentMenuPalette restoreController:controller];
        if (!state.blur.effect || state.dark != dark) {
            state.blur.effect = [UIBlurEffect effectWithStyle:dark ? UIBlurEffectStyleDark : UIBlurEffectStyleLight];
        }
        state.dark = dark;
        if (!CGRectEqualToRect(state.blur.frame, host.bounds)) state.blur.frame = host.bounds;
        if (!CGRectEqualToRect(state.tint.frame, state.blur.bounds)) state.tint.frame = state.blur.bounds;
        state.tint.backgroundColor = [UIColor colorWithWhite:dark ? 0 : 1 alpha:dark ? 0.2 : 0.1];
        // 透明度只作用于背景，文字和图标始终保留原来的 alpha。
        state.transparency = [DYYYUtils sharedBlurTransparency];
        state.blur.alpha = state.transparency;
        if (host.subviews.firstObject != state.blur) [host insertSubview:state.blur atIndex:0];
    } @finally {
        state.busy = NO;
    }
    [self clearView:controller.viewIfLoaded state:state];
}

+ (void)synchronizeView:(UIView *)view {
    if (!NSThread.isMainThread) return;
    if (!view.window) { [self restoreView:view]; return; }
    for (UIResponder *responder = view.nextResponder; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class]) continue;
        UIViewController *owner = [self ownerForController:(UIViewController *)responder];
        if (!owner) continue;
        DYYYPanelBlurState *state = objc_getAssociatedObject(owner, &kDYYYPanelBlurStateKey);
        if (![self enabledForController:owner] || !state) [self synchronizeController:owner];
        else [self clearView:view state:state];
        return;
    }
    [self restoreView:view];
}

+ (void)restoreObject:(id)object {
    NSDictionary *changes = objc_getAssociatedObject(object, &kDYYYPanelBlurChangesKey);
    objc_setAssociatedObject(object, &kDYYYPanelBlurChangesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(object, &kDYYYPanelBlurOwnerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSString *key in changes) {
        @try {
            NSDictionary *change = changes[key];
            id current = [object valueForKey:key] ?: NSNull.null;
            if ([self equal:current other:change[@"applied"]])
                [object setValue:change[@"original"] == NSNull.null ? nil : change[@"original"] forKey:key];
        } @catch (__unused NSException *exception) {}
    }
}

+ (void)restoreView:(UIView *)root {
    if (!NSThread.isMainThread || !root) return;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger index = 0; index < queue.count && index < 100; index++) {
        UIView *view = queue[index];
        [self restoreObject:view];
        [self restoreObject:[DYYYCommentMenuPalette cardLayerInCell:view]];
        [queue addObjectsFromArray:view.subviews];
    }
    [DYYYCommentMenuPalette restoreView:root];
}

+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYPanelBlurState *state = objc_getAssociatedObject(controller, &kDYYYPanelBlurStateKey);
    if (!state) { [[self controllers] removeObject:controller]; return; }
    if (state.busy) return;
    state.busy = YES;
    [state.blur removeFromSuperview];
    for (id object in state.objects.allObjects) [self restoreObject:object];
    if (![self isComment:controller]) [DYYYCommentMenuPalette restoreController:controller];
    objc_setAssociatedObject(controller, &kDYYYPanelBlurStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self controllers] removeObject:controller];
}

+ (void)refreshVisiblePanels {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisiblePanels]; });
        return;
    }
    for (UIViewController *controller in [self controllers].allObjects) {
        [self synchronizeController:controller];
        [controller.viewIfLoaded setNeedsLayout];
    }
}

+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{ @"mainThread": @NO };
    NSMutableArray *panels = [NSMutableArray array];
    for (UIViewController *controller in [self controllers].allObjects) {
        DYYYPanelBlurState *state = objc_getAssociatedObject(controller, &kDYYYPanelBlurStateKey);
        [panels addObject:@{
            @"controller": NSStringFromClass(controller.class),
            @"host": state.host ? NSStringFromClass(state.host.class) : @"not_found",
            @"hostBounds": state.host ? NSStringFromCGRect(state.host.bounds) : @"",
            @"attached": @(state.blur && state.blur.superview == state.host),
            @"backgroundAlpha": @(state.transparency),
            @"managedObjects": @(state.objects.count)
        }];
    }
    return @{ @"panels": panels,
        @"legacyShareClassAvailable": @(NSClassFromString(@"AWESharePanelController") != Nil),
        @"shareContainerClassAvailable": @(NSClassFromString(@"AWESharePanelContainerViewController") != Nil),
        @"shareContentClassAvailable": @(NSClassFromString(@"AWESharePanelViewController") != Nil) };
}
@end
