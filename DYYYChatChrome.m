/*
聊天顶栏语义控件与表情面板入口参考 HierarchThurs/DYKiller ChatInput。
样式按用户 Codex 截图定制：返回圆钮、右侧共用胶囊，头像与名称不铺玻璃；表情面板仅圆角顶部。
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
#import "DYYYChatChrome.h"
#import "DYYYUtils.h"
#import "DYYYChatInputList.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static char kDYYYChatTopKey, kDYYYChatPanelKey;

@interface DYYYChatTopState : NSObject
@property (nonatomic, weak) AWENavigationBar *bar;
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, strong) UIVisualEffectView *backGlass;
@property (nonatomic, strong) UIVisualEffectView *rightGlass;
@property (nonatomic, strong) CAShapeLayer *backGlyph;
@property (nonatomic, strong) NSMapTable<UIImageView *, NSDictionary *> *iconMasks;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *fills;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *moves;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *clips;
@property (nonatomic) BOOL pending;
@property (nonatomic) BOOL suspended;
@property (nonatomic, copy) NSString *lastDecision;
@property (nonatomic) CGRect backFrame;
@property (nonatomic) CGRect rightFrame;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) BOOL busy;
@property (nonatomic) BOOL active;
@end
@implementation DYYYChatTopState
@end

@interface DYYYChatPanelState : NSObject
@property (nonatomic, weak) UIView *panel;
@property (nonatomic, weak) UIView *carrier;
@property (nonatomic, weak) UIViewController *input;
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, strong) NSDictionary *native;
@property (nonatomic, strong) UIColor *border;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *backdrops;
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL busy;
@property (nonatomic) BOOL active;
@end
@implementation DYYYChatPanelState
@end

@implementation DYYYChatChrome
+ (BOOL)enabled { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"]; }
+ (void)preparePreferences { (void)[self topEnabled]; }
+ (BOOL)topEnabled {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    // 拆分旧联动开关时只迁移一次，之后输入框和顶栏互不控制。
    if (![defaults objectForKey:@"DYYYEnableChatTopGlass"])
        [defaults setBool:[self enabled] forKey:@"DYYYEnableChatTopGlass"];
    return [defaults boolForKey:@"DYYYEnableChatTopGlass"];
}
+ (NSHashTable *)topStates {
    static NSHashTable *states; static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}
+ (NSHashTable *)panelStates {
    static NSHashTable *states; static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}
+ (UIViewController *)chatForController:(UIViewController *)controller {
    Class chat = NSClassFromString(@"AWEIMMessageBaseViewController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController)
        if (chat && [controller isKindOfClass:chat]) return controller;
    return nil;
}
+ (UIViewController *)controllerForView:(UIView *)view { return [DYYYUtils firstAvailableViewControllerFromView:view]; }
+ (AWENavigationBar *)barForView:(UIView *)view {
    Class cls = NSClassFromString(@"AWENavigationBar");
    for (NSUInteger depth = 0; view && depth < 12; depth++, view = view.superview)
        if (cls && [view isKindOfClass:cls]) return (id)view;
    return nil;
}
+ (BOOL)visible:(UIView *)view inRoot:(UIView *)root {
    for (NSUInteger depth = 0; view && depth < 20; depth++, view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
        if (view == root) return YES;
    }
    return NO;
}
+ (BOOL)validRect:(CGRect)rect {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) && isfinite(rect.size.width) && isfinite(rect.size.height)
        && rect.size.width > 0 && rect.size.height > 0;
}
+ (DYYYChatTopState *)topState:(AWENavigationBar *)bar create:(BOOL)create {
    DYYYChatTopState *state = objc_getAssociatedObject(bar, &kDYYYChatTopKey);
    if (!state && create && bar) {
        state = [DYYYChatTopState new]; state.bar = bar;
        state.fills = [NSMapTable weakToStrongObjectsMapTable];
        state.moves = [NSMapTable weakToStrongObjectsMapTable];
        state.iconMasks = [NSMapTable weakToStrongObjectsMapTable];
        state.clips = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(bar, &kDYYYChatTopKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self topStates] addObject:state];
    }
    return state;
}
+ (void)restoreMoves:(DYYYChatTopState *)state {
    for (UIView *view in state.moves.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.moves objectForKey:view];
        if (CGAffineTransformEqualToTransform(view.transform, [saved[@"applied"] CGAffineTransformValue]))
            view.transform = [saved[@"base"] CGAffineTransformValue];
    }
    [state.moves removeAllObjects];
    for (UIImageView *icon in state.iconMasks.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.iconMasks objectForKey:icon];
        if (icon.layer.mask == saved[@"applied"])
            icon.layer.mask = saved[@"native"] == NSNull.null ? nil : saved[@"native"];
    }
    [state.iconMasks removeAllObjects];
}
+ (void)restoreTop:(DYYYChatTopState *)state {
    [DYYYChatInputList synchronizeHost:(id)state.host topActive:NO];
    [self restoreMoves:state];
    [state.backGlass removeFromSuperview]; [state.rightGlass removeFromSuperview];
    for (UIView *view in state.fills.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.fills objectForKey:view];
        if (!view.backgroundColor || CGColorGetAlpha(view.backgroundColor.CGColor) == 0)
            view.backgroundColor = saved[@"color"] == NSNull.null ? nil : saved[@"color"];
        if (!view.opaque) view.opaque = [saved[@"opaque"] boolValue];
    }
    for (UIView *view in state.clips.keyEnumerator.allObjects)
        if (!view.clipsToBounds) view.clipsToBounds = [[state.clips objectForKey:view] boolValue];
    [state.fills removeAllObjects]; [state.clips removeAllObjects]; state.active = NO;
}
+ (void)clearFill:(UIView *)view state:(DYYYChatTopState *)state {
    if (!view) return;
    NSDictionary *saved = [state.fills objectForKey:view];
    BOOL filled = view.backgroundColor && CGColorGetAlpha(view.backgroundColor.CGColor) > 0;
    if (!saved || filled || view.opaque)
        [state.fills setObject:@{ @"color": (!saved || filled) ? (view.backgroundColor ?: NSNull.null) : saved[@"color"],
            @"opaque": @(!saved ? view.opaque : ([saved[@"opaque"] boolValue] || view.opaque)) } forKey:view];
    if (filled) view.backgroundColor = UIColor.clearColor;
    if (view.opaque) view.opaque = NO;
}
+ (void)allowOverflow:(UIView *)view state:(DYYYChatTopState *)state {
    if (!view) return;
    if (![state.clips objectForKey:view]) [state.clips setObject:@(view.clipsToBounds) forKey:view];
    if (view.clipsToBounds) view.clipsToBounds = NO;
}
+ (void)move:(UIView *)view from:(CGPoint)source to:(CGPoint)target bar:(UIView *)bar state:(DYYYChatTopState *)state {
    if (!view.superview) return;
    CGPoint a = [view.superview convertPoint:source fromView:bar], b = [view.superview convertPoint:target fromView:bar];
    NSDictionary *saved = [state.moves objectForKey:view];
    CGAffineTransform current = view.transform, base = current, applied = current;
    if (saved && CGAffineTransformEqualToTransform(current, [saved[@"applied"] CGAffineTransformValue]))
        base = [saved[@"base"] CGAffineTransformValue];
    applied.tx += b.x - a.x; applied.ty += b.y - a.y;
    if (CGAffineTransformEqualToTransform(current, applied)) return;
    [state.moves setObject:@{ @"base": [NSValue valueWithCGAffineTransform:base], @"applied": [NSValue valueWithCGAffineTransform:applied] } forKey:view];
    view.transform = applied;
}
// 原生图片带透明留白，未读态还会重排 UIImageView。仅替换绘制，不替换原生返回动作。
+ (void)centerBackGlyph:(UIButton *)button state:(DYYYChatTopState *)state style:(UIUserInterfaceStyle)style {
    UIImageView *icon = button.imageView;
    if (!icon) return;
    NSDictionary *saved = [state.iconMasks objectForKey:icon];
    if (!saved || icon.layer.mask != saved[@"applied"]) {
        CALayer *mask = [CALayer layer];
        saved = @{ @"native": icon.layer.mask ?: NSNull.null, @"applied": mask };
        [state.iconMasks setObject:saved forKey:icon];
        icon.layer.mask = mask;
    }
    if (!state.backGlyph) {
        state.backGlyph = [CAShapeLayer layer];
        state.backGlyph.fillColor = UIColor.clearColor.CGColor;
        state.backGlyph.lineWidth = 2.25;
        state.backGlyph.lineCap = kCALineCapRound;
        state.backGlyph.lineJoin = kCALineJoinRound;
    }
    CGRect bounds = state.backGlass.bounds;
    if (!CGRectEqualToRect(state.backGlyph.frame, bounds) || !state.backGlyph.path) {
        state.backGlyph.frame = bounds;
        CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(center.x + 4.5, center.y - 8.5)];
        [path addLineToPoint:CGPointMake(center.x - 4.5, center.y)];
        [path addLineToPoint:CGPointMake(center.x + 4.5, center.y + 8.5)];
        state.backGlyph.path = path.CGPath;
    }
    UIColor *color = style == UIUserInterfaceStyleDark ? UIColor.whiteColor : UIColor.blackColor;
    if (!state.backGlyph.strokeColor || !CGColorEqualToColor(state.backGlyph.strokeColor, color.CGColor)) state.backGlyph.strokeColor = color.CGColor;
    if (state.backGlyph.superlayer != state.backGlass.contentView.layer) [state.backGlass.contentView.layer addSublayer:state.backGlyph];
}
+ (UIVisualEffectView *)glass:(NSString *)identifier {
    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *material = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular]; material.interactive = NO; effect = material;
    }
#endif
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
    glass.userInteractionEnabled = NO; glass.accessibilityElementsHidden = YES;
    glass.accessibilityIdentifier = identifier; glass.clipsToBounds = YES;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.layer.borderWidth = 0.5; glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
#endif
    return glass;
}
+ (void)placeGlass:(UIVisualEffectView *)glass frame:(CGRect)frame carrier:(UIView *)carrier style:(UIUserInterfaceStyle)style {
    if (!CGRectEqualToRect(glass.frame, frame)) glass.frame = frame;
    CGFloat radius = CGRectGetHeight(frame) / 2;
    if (glass.layer.cornerRadius != radius) glass.layer.cornerRadius = radius;
    if (glass.overrideUserInterfaceStyle != style) glass.overrideUserInterfaceStyle = style;
    if (glass.superview != carrier) [carrier insertSubview:glass atIndex:0];
}
+ (void)synchronizeTopForView:(UIView *)view {
    AWENavigationBar *bar = [self barForView:view];
    [self synchronizeBar:bar];
    [self scheduleTopSynchronization:bar];
}
// 子控件回调可能发生在父 StackView 尚未完成排版时。只合并一次当轮结束后的复核，不能轮询。
+ (void)scheduleTopSynchronization:(UIView *)view {
    if (!NSThread.isMainThread) return;
    AWENavigationBar *bar = [self barForView:view];
    DYYYChatTopState *state = [self topState:bar create:NO];
    if (!state || state.pending || state.suspended || !bar.window) return;
    state.pending = YES;
    __weak DYYYChatTopState *weakState = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYChatTopState *current = weakState;
        if (!current) return;
        current.pending = NO;
        if (!current.suspended) [self synchronizeBar:current.bar];
    });
}
+ (void)synchronizeBar:(UIView *)candidate {
    if (!NSThread.isMainThread) return;
    [UIView performWithoutAnimation:^{ [self applyBar:candidate]; }];
}
+ (void)applyBar:(UIView *)candidate {
    if (!NSThread.isMainThread || ![candidate isKindOfClass:NSClassFromString(@"AWENavigationBar")]) return;
    AWENavigationBar *bar = (id)candidate;
    DYYYChatTopState *state = [self topState:bar create:NO];
    if (state.busy || state.depth) return;
    UIViewController *host = [self chatForController:[self controllerForView:bar]];
    if (![self topEnabled] || state.suspended || !host || !bar.window || ![self visible:bar inRoot:host.viewIfLoaded]) {
        state.lastDecision = @"disabled_or_outside_visible_chat";
        [self restoreTop:state]; return;
    }
    if (![bar respondsToSelector:@selector(contentView)] || ![bar respondsToSelector:@selector(leftBtnsContainerView)] ||
        ![bar respondsToSelector:@selector(rightBtnsContainerView)]) return;
    UIView *carrier = bar.contentView, *left = bar.leftBtnsContainerView, *right = bar.rightBtnsContainerView;
    if (![self validRect:carrier.bounds] || CGRectGetHeight(carrier.bounds) < 28 || CGRectGetHeight(carrier.bounds) > 72) return;
    state = [self topState:bar create:YES]; state.host = host; state.busy = YES;
    @try {
        AWEIMNavigationUnreadView *unread = nil; UIView *title = nil;
        for (UIView *view in left.subviews) {
            if ([view isKindOfClass:NSClassFromString(@"AWEIMNavigationUnreadView")]) unread = (id)view;
            if ([view isKindOfClass:NSClassFromString(@"AWEIMMessageListNaviBarTitleView")]) title = view;
        }
        if (!title && [bar respondsToSelector:@selector(titleView)]) title = bar.titleView;
        UIButton *back = [unread respondsToSelector:@selector(backButton)] ? unread.backButton : nil;
        if (!back || !title || ![self visible:back inRoot:bar] || ![self visible:title inRoot:bar]) { state.lastDecision = @"native_controls_not_ready"; [self restoreTop:state]; return; }
        CGRect titleRect = [title convertRect:title.bounds toView:bar];
        NSDictionary *titleMove = [state.moves objectForKey:title];
        if (titleMove && CGAffineTransformEqualToTransform(title.transform, [titleMove[@"applied"] CGAffineTransformValue])) {
            CGAffineTransform applied = [titleMove[@"applied"] CGAffineTransformValue], base = [titleMove[@"base"] CGAffineTransformValue];
            titleRect.origin.x -= applied.tx - base.tx;
        }
        CGRect row = [carrier convertRect:carrier.bounds toView:bar];
        CGFloat diameter = 44;
        if (CGRectGetHeight(row) < 44) { state.lastDecision = @"title_geometry_not_ready"; [self restoreTop:state]; return; }
        CGFloat x = 16;
        CGRect backRect = CGRectMake(x, CGRectGetMidY(row) - diameter / 2, diameter, diameter);
        CGRect controls = CGRectNull;
        for (UIView *view in right.subviews) {
            if (![self visible:view inRoot:bar]) continue;
            if (![view isKindOfClass:UIControl.class] && ![view isKindOfClass:NSClassFromString(@"AWEIMMessageVoipEntranceView")]) continue;
            CGRect rect = [view convertRect:view.bounds toView:bar];
            if ([self validRect:rect]) controls = CGRectIsNull(controls) ? rect : CGRectUnion(controls, rect);
        }
        if (CGRectIsNull(controls)) { state.lastDecision = @"actions_not_ready"; [self restoreTop:state]; return; }
        CGFloat h = MIN(44, CGRectGetHeight(row));
        CGFloat wantedShift = MAX(10, CGRectGetMaxX(backRect) + 12 - CGRectGetMinX(titleRect));
        CGFloat titleShift = MIN(wantedShift, MAX(0, CGRectGetMinX(controls) - 24 - CGRectGetMaxX(titleRect)));
        CGRect shiftedTitle = CGRectOffset(titleRect, titleShift, 0);
        CGFloat start = MAX(CGRectGetMinX(controls) - 10, CGRectGetMaxX(shiftedTitle) + 4);
        CGFloat end = MIN(CGRectGetMaxX(controls) + 10, CGRectGetMaxX(bar.bounds) - 8);
        if (start > CGRectGetMinX(controls) + 0.5 || end + 0.5 < CGRectGetMaxX(controls) || end - start < h) { state.lastDecision = @"actions_geometry_not_ready"; [self restoreTop:state]; return; }
        CGRect rightRect = CGRectMake(start, CGRectGetMidY(row) - h / 2, end - start, h);
        [self allowOverflow:carrier state:state]; [self allowOverflow:left state:state]; [self allowOverflow:unread state:state];
        CGRect currentTitle = [title convertRect:title.bounds toView:bar];
        [self move:title from:CGPointMake(CGRectGetMidX(currentTitle), CGRectGetMidY(currentTitle))
            to:CGPointMake(CGRectGetMidX(shiftedTitle), CGRectGetMidY(shiftedTitle)) bar:bar state:state];
        UIView *badge = [unread respondsToSelector:@selector(unreadCountView)] ? unread.unreadCountView : nil;
        if (badge && [self visible:badge inRoot:bar]) {
            CGRect rect = [badge convertRect:badge.bounds toView:bar];
            CGPoint target = CGPointMake(MIN(CGRectGetMaxX(backRect) - 6, CGRectGetMinX(shiftedTitle) - 1 - CGRectGetWidth(rect) / 2), CGRectGetMinY(backRect) + 4);
            [self move:badge from:CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect)) to:target bar:bar state:state];
        }
        [self clearFill:bar state:state]; [self clearFill:carrier state:state];
        if ([bar respondsToSelector:@selector(bottomLineView)]) [self clearFill:bar.bottomLineView state:state];
        if (!state.backGlass) state.backGlass = [self glass:@"DYads.ChatBackGlass"];
        if (!state.rightGlass) state.rightGlass = [self glass:@"DYads.ChatActionsGlass"];
        UIUserInterfaceStyle style = [DYYYUtils isDarkMode] || bar.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        [self placeGlass:state.backGlass frame:[carrier convertRect:backRect fromView:bar] carrier:carrier style:style];
        [self placeGlass:state.rightGlass frame:[carrier convertRect:rightRect fromView:bar] carrier:carrier style:style];
        [self centerBackGlyph:back state:state style:style];
        state.lastDecision = @"applied";
        state.backFrame = backRect; state.rightFrame = rightRect; state.active = YES;
        [DYYYChatInputList synchronizeHost:(id)host topActive:YES];
    } @finally { state.busy = NO; }
}
+ (id)beginTopUpdate:(UIView *)view {
    if (!NSThread.isMainThread) return nil;
    AWENavigationBar *bar = [self barForView:view];
    if (!bar) return nil;
    DYYYChatTopState *state = [self topState:bar create:NO];
    if (!state && [self topEnabled] && [self chatForController:[self controllerForView:bar]]) state = [self topState:bar create:YES];
    if (!state || state.busy) return nil;
    if (state.depth++ == 0) {
        state.busy = YES;
        @try { [UIView performWithoutAnimation:^{ [self restoreMoves:state]; }]; } @finally { state.busy = NO; }
    }
    return state;
}
+ (void)endTopUpdate:(id)token {
    if (!NSThread.isMainThread || ![token isKindOfClass:DYYYChatTopState.class]) return;
    DYYYChatTopState *state = token;
    if (state.depth) state.depth--;
    if (!state.depth) {
        [self synchronizeBar:state.bar];
        [self scheduleTopSynchronization:state.bar];
    }
}
// 原生动态模糊底板与面板是兄弟，不能只圆角前景、在角外留下矩形底板。
+ (void)restoreBackdrop:(UIView *)view saved:(NSDictionary *)saved radius:(CGFloat)radius {
    if (view.layer.cornerRadius == radius) view.layer.cornerRadius = [saved[@"radius"] doubleValue];
    if (view.layer.maskedCorners == (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)) view.layer.maskedCorners = [saved[@"corners"] unsignedIntegerValue];
    if ([view.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) view.layer.cornerCurve = saved[@"curve"];
    if (view.clipsToBounds) view.clipsToBounds = [saved[@"clips"] boolValue];
}
+ (void)synchronizePanelBackdrops:(DYYYChatPanelState *)state {
    UIView *page = state.input.viewIfLoaded.superview;
    if (!page) return;
    CGRect reference = [state.carrier convertRect:state.carrier.bounds toView:page];
    NSMutableArray *wanted = [NSMutableArray array];
    for (UIView *view in page.subviews) {
        if (![view isKindOfClass:UIVisualEffectView.class]) continue;
        UIVisualEffect *effect = ((UIVisualEffectView *)view).effect;
        if (![NSStringFromClass(effect.class) isEqualToString:@"AWEUIDynamicBlurEffect"]) continue;
        CGRect rect = [view convertRect:view.bounds toView:page];
        if (fabs(rect.origin.x - reference.origin.x) > 1 || fabs(rect.origin.y - reference.origin.y) > 1 ||
            fabs(rect.size.width - reference.size.width) > 1 || rect.size.height < reference.size.height - 1 ||
            rect.size.height - reference.size.height > 80) continue;
        [wanted addObject:view];
    }
    for (UIView *view in state.backdrops.keyEnumerator.allObjects) if (![wanted containsObject:view]) {
        [self restoreBackdrop:view saved:[state.backdrops objectForKey:view] radius:state.radius];
        [state.backdrops removeObjectForKey:view];
    }
    for (UIView *view in wanted) {
        NSDictionary *original = [state.backdrops objectForKey:view];
        NSMutableDictionary *saved = original ? [original mutableCopy] : [NSMutableDictionary dictionary];
        if (!original || view.layer.cornerRadius != state.radius) saved[@"radius"] = @(view.layer.cornerRadius);
        if (!original || view.layer.maskedCorners != (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)) saved[@"corners"] = @(view.layer.maskedCorners);
        if (!original || ![view.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) saved[@"curve"] = view.layer.cornerCurve ?: kCACornerCurveCircular;
        if (!original || !view.clipsToBounds) saved[@"clips"] = @(view.clipsToBounds);
        [state.backdrops setObject:saved forKey:view];
        if (view.layer.cornerRadius != state.radius) view.layer.cornerRadius = state.radius;
        if (view.layer.maskedCorners != (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)) view.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        if (![view.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) view.layer.cornerCurve = kCACornerCurveContinuous;
        if (!view.clipsToBounds) view.clipsToBounds = YES;
    }
}
+ (void)restorePanel:(DYYYChatPanelState *)state {
    if (!state.active) return;
    UIView *view = state.carrier; NSDictionary *saved = state.native;
    if (view.layer.cornerRadius == state.radius) view.layer.cornerRadius = [saved[@"radius"] doubleValue];
    if (view.layer.maskedCorners == (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)) view.layer.maskedCorners = [saved[@"corners"] unsignedIntegerValue];
    if ([view.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) view.layer.cornerCurve = saved[@"curve"];
    if (view.layer.borderWidth == 0.5) view.layer.borderWidth = [saved[@"borderWidth"] doubleValue];
    if (view.layer.borderColor && CGColorEqualToColor(view.layer.borderColor, state.border.CGColor))
        view.layer.borderColor = saved[@"border"] == NSNull.null ? NULL : ((UIColor *)saved[@"border"]).CGColor;
    if (view.clipsToBounds) view.clipsToBounds = [saved[@"clips"] boolValue];
    for (UIView *backdrop in state.backdrops.keyEnumerator.allObjects)
        [self restoreBackdrop:backdrop saved:[state.backdrops objectForKey:backdrop] radius:state.radius];
    [state.backdrops removeAllObjects];
    state.active = NO; state.native = nil;
}
+ (void)synchronizePanel:(UIView *)panel {
    if (!NSThread.isMainThread || !panel) return;
    DYYYChatPanelState *state = objc_getAssociatedObject(panel, &kDYYYChatPanelKey);
    if (state.busy) return;
    UIViewController *input = nil, *owner = [self controllerForView:panel];
    Class inputClass = NSClassFromString(@"IESIMInputViewController");
    for (NSUInteger depth = 0; owner && depth < 10; depth++, owner = owner.parentViewController)
        if (inputClass && [owner isKindOfClass:inputClass]) { input = owner; break; }
    UIViewController *host = [self chatForController:input];
    BOOL shown = panel.window && [self visible:panel inRoot:input.viewIfLoaded] &&
        CGRectGetHeight(CGRectIntersection([panel convertRect:panel.bounds toView:panel.window], panel.window.bounds)) > 1;
    if (![self enabled] || !host || !shown || CGRectGetWidth(panel.bounds) < 200 || CGRectGetHeight(panel.bounds) < 120 ||
        ![(id)input respondsToSelector:@selector(currentInputType)] || ((IESIMInputViewController *)input).currentInputType != 2) {
        [self restorePanel:state]; return;
    }
    UIView *carrier = panel;
    for (NSUInteger depth = 0; depth < 4; depth++) {
        UIView *parent = carrier.superview;
        if (!parent || parent == input.viewIfLoaded || parent.class != UIView.class) break;
        CGRect rect = [carrier convertRect:carrier.bounds toView:parent];
        if (fabs(rect.origin.x - parent.bounds.origin.x) > 1 || fabs(rect.origin.y - parent.bounds.origin.y) > 1 ||
            fabs(rect.size.width - parent.bounds.size.width) > 1 || parent.bounds.size.height < rect.size.height - 1 ||
            parent.bounds.size.height - rect.size.height > 80) break;
        carrier = parent;
    }
    if (!state) {
        state = [DYYYChatPanelState new]; state.panel = panel;
        state.backdrops = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(panel, &kDYYYChatPanelKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self panelStates] addObject:state];
    }
    state.busy = YES;
    @try {
        if (state.carrier != carrier) { [self restorePanel:state]; state.carrier = carrier; }
        state.input = input; state.host = host;
        // 不替换原 mask、不动 frame、表情集合视图或键盘，仅裁出面板顶部两角。
        if (!state.active) state.native = @{ @"radius": @(carrier.layer.cornerRadius), @"corners": @(carrier.layer.maskedCorners),
            @"curve": carrier.layer.cornerCurve ?: kCACornerCurveCircular, @"borderWidth": @(carrier.layer.borderWidth),
            @"border": carrier.layer.borderColor ? [UIColor colorWithCGColor:carrier.layer.borderColor] : NSNull.null, @"clips": @(carrier.clipsToBounds) };
        if (state.active) {
            NSMutableDictionary *saved = [state.native mutableCopy];
            if (carrier.layer.cornerRadius != state.radius) saved[@"radius"] = @(carrier.layer.cornerRadius);
            if (carrier.layer.maskedCorners != (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)) saved[@"corners"] = @(carrier.layer.maskedCorners);
            if (![carrier.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) saved[@"curve"] = carrier.layer.cornerCurve ?: kCACornerCurveCircular;
            if (carrier.layer.borderWidth != 0.5) saved[@"borderWidth"] = @(carrier.layer.borderWidth);
            if (!carrier.layer.borderColor || !CGColorEqualToColor(carrier.layer.borderColor, state.border.CGColor))
                saved[@"border"] = carrier.layer.borderColor ? [UIColor colorWithCGColor:carrier.layer.borderColor] : NSNull.null;
            if (!carrier.clipsToBounds) saved[@"clips"] = @NO;
            state.native = saved;
        }
        state.radius = MIN(28, MIN(CGRectGetWidth(carrier.bounds), CGRectGetHeight(carrier.bounds)) / 2);
        state.border = [DYYYUtils isDarkMode] ? [UIColor colorWithWhite:1 alpha:0.14] : [UIColor colorWithWhite:0 alpha:0.12];
        if (carrier.layer.cornerRadius != state.radius) carrier.layer.cornerRadius = state.radius;
        if (carrier.layer.maskedCorners != (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)) carrier.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        if (![carrier.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) carrier.layer.cornerCurve = kCACornerCurveContinuous;
        if (carrier.layer.borderWidth != 0.5) carrier.layer.borderWidth = 0.5;
        if (!carrier.layer.borderColor || !CGColorEqualToColor(carrier.layer.borderColor, state.border.CGColor)) carrier.layer.borderColor = state.border.CGColor;
        if (!carrier.clipsToBounds) carrier.clipsToBounds = YES;
        [self synchronizePanelBackdrops:state];
        state.active = YES;
    } @finally { state.busy = NO; }
}
+ (void)synchronizeInput:(UIViewController *)input {
    if (!NSThread.isMainThread || !input) return;
    BOOL cached = NO;
    for (DYYYChatPanelState *state in [self panelStates].allObjects) if (state.input == input) {
        [self synchronizePanel:state.panel];
        if (state.active && state.panel.window && [state.panel isDescendantOfView:input.viewIfLoaded]) cached = YES;
    }
    if (cached || ![self enabled] || !input.viewIfLoaded.window || ![self chatForController:input] ||
        ![input respondsToSelector:@selector(currentInputType)] || ((IESIMInputViewController *)input).currentInputType != 2) return;
    NSMutableArray *queue = [NSMutableArray arrayWithArray:input.viewIfLoaded.subviews];
    Class panelClass = NSClassFromString(@"AWEIMEmoticonPanelContainerView");
    for (NSUInteger index = 0; index < queue.count && index < 128; index++) {
        UIView *view = queue[index];
        if (panelClass && [view isKindOfClass:panelClass] && [self visible:view inRoot:input.viewIfLoaded]) {
            [self synchronizePanel:view];
            DYYYChatPanelState *state = objc_getAssociatedObject(view, &kDYYYChatPanelKey);
            if (state.active) return;
            continue;
        }
        if ([view isKindOfClass:UIScrollView.class] || [view isKindOfClass:UIControl.class] || [view isKindOfClass:UIImageView.class]) continue;
        if (queue.count + view.subviews.count <= 128) [queue addObjectsFromArray:view.subviews];
    }
}
+ (void)synchronizeHost:(UIViewController *)host {
    if (!NSThread.isMainThread || [self chatForController:host] != host) return;
    for (UIView *view in host.viewIfLoaded.subviews)
        if ([view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) {
            DYYYChatTopState *state = [self topState:(id)view create:[self topEnabled]];
            state.suspended = NO;
            [self synchronizeBar:view];
            [self scheduleTopSynchronization:view];
        }
    for (UIViewController *child in host.childViewControllers)
        if ([child isKindOfClass:NSClassFromString(@"IESIMInputViewController")]) [self synchronizeInput:child];
}
+ (void)restoreHost:(UIViewController *)host {
    if (!NSThread.isMainThread) return;
    for (DYYYChatTopState *state in [self topStates].allObjects) if (state.host == host && !state.busy) { state.suspended = YES; state.lastDecision = @"host_disappeared"; [self restoreTop:state]; }
    for (DYYYChatPanelState *state in [self panelStates].allObjects) if (state.host == host && !state.busy) [self restorePanel:state];
}
+ (void)refreshVisibleViews {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisibleViews]; }); return; }
    for (DYYYChatTopState *state in [self topStates].allObjects) [self synchronizeBar:state.bar];
    for (DYYYChatPanelState *state in [self panelStates].allObjects) [self synchronizePanel:state.panel];
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSMutableArray *tops = [NSMutableArray array], *panels = [NSMutableArray array];
    for (DYYYChatTopState *state in [self topStates].allObjects) if (state.bar.window)
        [tops addObject:@{ @"active": @(state.active), @"lastDecision": state.lastDecision ?: @"", @"pending": @(state.pending), @"back": NSStringFromCGRect(state.backFrame), @"actions": NSStringFromCGRect(state.rightFrame) }];
    for (DYYYChatPanelState *state in [self panelStates].allObjects) if (state.panel.window)
        [panels addObject:@{ @"active": @(state.active), @"radius": @(state.radius), @"frame": NSStringFromCGRect(state.carrier.frame),
            @"inputType": @([state.input respondsToSelector:@selector(currentInputType)] ? ((IESIMInputViewController *)state.input).currentInputType : -1),
            @"roundedNativeBackdrops": @(state.backdrops.count) }];
    return @{ @"enabled": @([self enabled]), @"topEnabled": @([self topEnabled]), @"topBars": tops, @"emojiPanels": panels };
}
@end
