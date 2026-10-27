#import "DYYYChatInputGlass.h"
#import "DYYYChatInputList.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static char kDYYYChatGlassStateKey;

@interface DYYYChatGlassState : NSObject
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UIView *slot;
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) BOOL opaque;
@property (nonatomic, assign) BOOL clips;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) CGFloat appliedRadius;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *paints;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *backgrounds;
@property (nonatomic, assign) NSUInteger depth;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) BOOL active;
@end
@implementation DYYYChatGlassState
@end

@implementation DYYYChatInputGlass
+ (NSHashTable *)states {
    static NSHashTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}
+ (DYYYChatGlassState *)state:(UIViewController *)controller create:(BOOL)create {
    DYYYChatGlassState *state = objc_getAssociatedObject(controller, &kDYYYChatGlassStateKey);
    if (!state && create && controller) {
        state = [DYYYChatGlassState new];
        state.controller = controller;
        state.paints = [NSMapTable weakToStrongObjectsMapTable];
        state.backgrounds = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(controller, &kDYYYChatGlassStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self states] addObject:state];
    }
    return state;
}
+ (void)restoreState:(DYYYChatGlassState *)state {
    if (!state) return;
    [state.glass removeFromSuperview];
    UIView *slot = state.slot;
    if (state.active && slot) {
        if (!slot.backgroundColor || CGColorGetAlpha(slot.backgroundColor.CGColor) == 0) slot.backgroundColor = state.color;
        if (!slot.opaque) slot.opaque = state.opaque;
        if (slot.layer.cornerRadius == state.appliedRadius) slot.layer.cornerRadius = state.radius;
        if (slot.clipsToBounds) slot.clipsToBounds = state.clips;
    }
    for (UIView *paint in state.paints.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.paints objectForKey:paint];
        if (paint.layer.mask == saved[@"applied"]) paint.layer.mask = saved[@"native"] == NSNull.null ? nil : saved[@"native"];
    }
    [state.paints removeAllObjects];
    for (UIView *view in state.backgrounds.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.backgrounds objectForKey:view];
        if (!view.backgroundColor || CGColorGetAlpha(view.backgroundColor.CGColor) == 0)
            view.backgroundColor = saved[@"color"] == NSNull.null ? nil : saved[@"color"];
        if (!view.opaque) view.opaque = [saved[@"opaque"] boolValue];
        if ([view isKindOfClass:UIVisualEffectView.class] && !((UIVisualEffectView *)view).effect && saved[@"effect"])
            ((UIVisualEffectView *)view).effect = saved[@"effect"];
    }
    [state.backgrounds removeAllObjects];
    state.active = NO;
}
// B8C5BB62：输入 VC 的 64pt 根视图仍是 #161616，不能只替换 44pt 槽内绘制。
+ (void)clearBackground:(UIView *)view state:(DYYYChatGlassState *)state {
    if (!view) return;
    NSDictionary *saved = [state.backgrounds objectForKey:view];
    UIColor *color = view.backgroundColor;
    BOOL filled = color && CGColorGetAlpha(color.CGColor) > 0;
    if (!saved || filled || view.opaque) {
        saved = @{ @"color": (!saved || filled) ? (color ?: NSNull.null) : saved[@"color"],
                   @"opaque": @(!saved ? view.opaque : ([saved[@"opaque"] boolValue] || view.opaque)) };
        [state.backgrounds setObject:saved forKey:view];
    }
    if (filled) view.backgroundColor = UIColor.clearColor;
    if (view.opaque) view.opaque = NO;
}
+ (void)clearInputSurroundings:(IESIMInputViewController *)controller state:(DYYYChatGlassState *)state {
    UIView *root = controller.viewIfLoaded;
    UIView *text = controller.textView;
    [self clearBackground:root state:state];
    // 仅清理已确认的输入前景路径，不递归到文字绘制、按钮、附件或表情面板。
    UIView *view = text;
    for (NSUInteger depth = 0; view && view != root && depth < 10; depth++, view = view.superview) {
        if (view != text && view.class != UIView.class) break;
        [self clearBackground:view state:state];
    }
    // 原生无交互安全区底板伸出 root；不能把同起点的 355pt panelsContainer 一起清掉。
    for (UIView *view in root.subviews) {
        if (view.class != UIView.class || view.userInteractionEnabled || view.subviews.count || view.layer.sublayers.count) continue;
        CGRect rect = view.frame;
        if (fabs(CGRectGetMinY(rect) - CGRectGetMaxY(root.bounds)) <= 1 &&
            fabs(CGRectGetWidth(rect) - CGRectGetWidth(root.bounds)) <= 1 &&
            CGRectGetHeight(rect) > 0 && CGRectGetHeight(rect) <= 64)
            [self clearBackground:view state:state];
    }
}
// 参考 DYKiller DKChatInputGlass.xm，许可同 DYYYChatInputList.m。
// 仅移除输入行以下已确认的原生动态模糊底板，不能把键盘/附件面板清成透明。
+ (void)clearNativeBottomBlur:(IESIMInputViewController *)controller state:(DYYYChatGlassState *)state {
    UIView *root = controller.viewIfLoaded;
    for (UIView *view in root.superview.subviews) {
        if (![view isKindOfClass:UIVisualEffectView.class] || CGRectGetMinY(view.frame) < CGRectGetMinY(root.frame) ||
            CGRectGetHeight(view.bounds) > 128 || fabs(CGRectGetWidth(view.bounds) - CGRectGetWidth(root.bounds)) > 1) continue;
        UIVisualEffectView *blur = (id)view;
        UIVisualEffect *effect = blur.effect;
        UIVisualEffect *native = effect ?: [state.backgrounds objectForKey:view][@"effect"];
        if (![NSStringFromClass(native.class) isEqualToString:@"AWEUIDynamicBlurEffect"]) continue;
        [self clearBackground:view state:state];
        NSMutableDictionary *saved = [[state.backgrounds objectForKey:view] mutableCopy];
        saved[@"effect"] = native;
        [state.backgrounds setObject:saved forKey:view];
        if (effect) blur.effect = nil;
    }
}
+ (BOOL)isChatController:(UIViewController *)controller {
    Class chat = NSClassFromString(@"AWEIMMessageBaseViewController");
    for (NSUInteger depth = 0; controller && depth < 10; depth++, controller = controller.parentViewController)
        if (chat && [controller isKindOfClass:chat]) return YES;
    return NO;
}
+ (BOOL)isPaintOnly:(UIView *)slot {
    NSMutableArray *queue = [NSMutableArray arrayWithArray:slot.subviews];
    for (NSUInteger index = 0; index < queue.count && index < 64; index++) {
        UIView *view = queue[index];
        if ([view isKindOfClass:UIVisualEffectView.class]) {
            [queue addObjectsFromArray:((UIVisualEffectView *)view).contentView.subviews];
        } else {
            if (view.class != UIView.class) return NO;
            [queue addObjectsFromArray:view.subviews];
        }
    }
    return queue.count < 64;
}
+ (UIView *)slotInController:(IESIMInputViewController *)controller {
    UIView *root = controller.viewIfLoaded;
    UIView *text = [controller respondsToSelector:@selector(textView)] ? controller.textView : nil;
    if (!root || !text.superview || ![text isDescendantOfView:root]) return nil;
    CGRect field = [text convertRect:text.bounds toView:root];
    if (!isfinite(field.origin.x) || !isfinite(field.origin.y) || !isfinite(field.size.width) || !isfinite(field.size.height) ||
        CGRectGetWidth(field) < 160 || CGRectGetHeight(field) < 32 || CGRectGetHeight(field) > 220 ||
        CGRectGetMinY(field) < CGRectGetMinY(root.bounds) - 1 || CGRectGetMaxY(field) > CGRectGetMaxY(root.bounds) + 1) return nil;
    // 2D69E19A：44pt 的原生背景槽与 GrowingTextView 同框，按钮位于独立前景容器。
    for (UIView *slot in root.subviews) {
        if (slot.class != UIView.class || slot == text || [text isDescendantOfView:slot]) continue;
        CGRect rect = [slot convertRect:slot.bounds toView:root];
        if (fabs(rect.origin.x - field.origin.x) > 1 || fabs(rect.origin.y - field.origin.y) > 1 ||
            fabs(rect.size.width - field.size.width) > 1 || fabs(rect.size.height - field.size.height) > 1) continue;
        if ([self isPaintOnly:slot]) return slot;
    }
    return nil;
}
+ (void)applyState:(DYYYChatGlassState *)state {
    if (!state || state.busy || state.depth) return;
    state.busy = YES;
    @try {
        IESIMInputViewController *controller = (id)state.controller;
        UIView *root = controller.viewIfLoaded;
        BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"];
        if (!enabled || !root.window || ![self isChatController:controller]) {
            [self restoreState:state];
            return;
        }
        UIView *slot = [self slotInController:controller];
        if (!slot || slot.hidden || slot.alpha <= 0.01) { [self restoreState:state]; return; }
        if (state.slot != slot) { [self restoreState:state]; state.slot = slot; }
        if (!state.active) {
            state.color = slot.backgroundColor;
            state.opaque = slot.opaque;
            state.clips = slot.clipsToBounds;
            state.radius = slot.layer.cornerRadius;
        } else {
            if (slot.backgroundColor && CGColorGetAlpha(slot.backgroundColor.CGColor) > 0) state.color = slot.backgroundColor;
            if (slot.layer.cornerRadius != state.appliedRadius) state.radius = slot.layer.cornerRadius;
        }
        if (!state.glass) {
            UIVisualEffect *material = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
            if (@available(iOS 26.0, *)) {
                UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
                glass.interactive = NO;
                material = glass;
            }
#endif
            state.glass = [[UIVisualEffectView alloc] initWithEffect:material];
            state.glass.userInteractionEnabled = NO;
            state.glass.accessibilityElementsHidden = YES;
            state.glass.accessibilityIdentifier = @"DYads.ChatInputGlass";
            state.glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            state.glass.clipsToBounds = YES;
            state.glass.layer.cornerCurve = kCACornerCurveContinuous;
            state.glass.layer.borderWidth = 0.5;
            state.glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
            if (@available(iOS 26.0, *)) state.glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
#endif
        }
        UIUserInterfaceStyle style = [DYYYUtils isDarkMode] || root.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        if (state.glass.overrideUserInterfaceStyle != style) state.glass.overrideUserInterfaceStyle = style;
        if (!CGRectEqualToRect(state.glass.frame, slot.bounds)) state.glass.frame = slot.bounds;
        CGFloat radius = MIN(28, CGRectGetHeight(slot.bounds) / 2);
        state.appliedRadius = radius;
        if (state.glass.layer.cornerRadius != radius) state.glass.layer.cornerRadius = radius;
        [self clearInputSurroundings:controller state:state];
        [self clearNativeBottomBlur:controller state:state];
        // 只屏蔽已确认背景槽内的绘制；不改 native hidden/alpha/命中或任何输入内容。
        for (UIView *paint in slot.subviews) {
            if (paint == state.glass) continue;
            NSDictionary *saved = [state.paints objectForKey:paint];
            CALayer *mask = saved[@"applied"];
            if (!saved || paint.layer.mask != mask) {
                mask = [CALayer layer]; // 空的透明 mask，保留原生控件交互。
                saved = @{ @"native": paint.layer.mask ?: NSNull.null, @"applied": mask };
                [state.paints setObject:saved forKey:paint];
            }
            if (!CGRectEqualToRect(mask.frame, paint.bounds)) mask.frame = paint.bounds;
            if (paint.layer.mask != mask) paint.layer.mask = mask;
        }
        if (slot.backgroundColor && CGColorGetAlpha(slot.backgroundColor.CGColor) > 0) slot.backgroundColor = UIColor.clearColor;
        if (slot.opaque) slot.opaque = NO;
        if (slot.layer.cornerRadius != radius) slot.layer.cornerRadius = radius;
        if (!slot.clipsToBounds) slot.clipsToBounds = YES;
        state.active = YES;
        if (state.glass.superview != slot) [slot addSubview:state.glass];
    } @finally { state.busy = NO; }
}
+ (void)synchronizeController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller) return;
    DYYYChatGlassState *state = [self state:controller create:[NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"]];
    [UIView performWithoutAnimation:^{ [self applyState:state]; }];
    if (!state.depth && !state.busy) [DYYYChatInputList synchronizeInputController:controller active:state.active];
}
+ (void)beginUpdate:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYChatGlassState *state = [self state:controller create:[NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"]];
    if (!state || state.busy) return;
    if (state.depth++ == 0) {
        state.busy = YES;
        @try { [self restoreState:state]; } @finally { state.busy = NO; }
    }
}
+ (void)endUpdate:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYChatGlassState *state = [self state:controller create:NO];
    if (state.depth) state.depth--;
    [self synchronizeController:controller];
}
+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYChatGlassState *state = [self state:controller create:NO];
    if (!state || state.busy) return;
    state.busy = YES;
    @try { [self restoreState:state]; } @finally { state.busy = NO; }
    [DYYYChatInputList synchronizeInputController:controller active:NO];
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSMutableArray *states = [NSMutableArray array];
    for (DYYYChatGlassState *state in [self states].allObjects) {
        if (!state.controller.viewIfLoaded.window) continue;
        [states addObject:@{ @"active": @(state.active), @"slotFrame": NSStringFromCGRect(state.slot.frame),
            @"glassFrame": NSStringFromCGRect(state.glass.frame), @"maskedBackgroundCount": @(state.paints.count), @"clearedBackgroundCount": @(state.backgrounds.count),
            @"inputRootBackground": state.controller.viewIfLoaded.backgroundColor.description ?: @"",
            @"inputRootOpaque": @(state.controller.viewIfLoaded.opaque) }];
    }
    return @{ @"enabled": @([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"]), @"states": states };
}
@end
