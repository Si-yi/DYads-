#import "DYYYFeedTagGlass.h"
#import "DYYYUtils.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char kDYYYFeedTagGlassKey;

@interface DYYYFeedTagGlassState : NSObject
@property (nonatomic, weak) UIView *host;
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) NSMapTable<UIView *, NSMutableDictionary *> *changes;
@property (nonatomic, assign) BOOL busy;
@end
@implementation DYYYFeedTagGlassState
@end

@implementation DYYYFeedTagGlass

+ (BOOL)isFeedTag:(UIView *)tag {
    if (!tag.window) return NO;
    for (UIView *parent = tag; parent; parent = parent.superview)
        if (parent.hidden || parent.alpha <= 0.01) return NO;
    Class interaction = NSClassFromString(@"AWEPlayInteractionViewController");
    UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:tag];
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController)
        if (interaction && [controller isKindOfClass:interaction]) return YES;
    return NO;
}

+ (UIView *)existingView:(NSString *)name inTag:(UIView *)tag {
    if (![tag respondsToSelector:NSSelectorFromString(name)]) return nil;
    @try {
        id view = [tag valueForKey:name];
        return [view isKindOfClass:UIView.class] && [view isDescendantOfView:tag] ? view : nil;
    } @catch (__unused NSException *exception) { return nil; }
}

+ (void)write:(id)value key:(NSString *)key view:(UIView *)view state:(DYYYFeedTagGlassState *)state {
    if (!view || !value) return;
    @try {
        id current = [view valueForKey:key] ?: NSNull.null;
        if (current == value || [current isEqual:value]) return;
        NSMutableDictionary *changes = [state.changes objectForKey:view];
        if (!changes) {
            changes = [NSMutableDictionary dictionary];
            [state.changes setObject:changes forKey:view];
        }
        NSDictionary *previous = changes[key];
        id original = previous && [current isEqual:previous[@"applied"]] ? previous[@"original"] : current;
        changes[key] = @{ @"original": original, @"applied": value };
        [view setValue:value forKey:key];
    } @catch (__unused NSException *exception) {}
}

+ (BOOL)needsLightText:(UIColor *)color {
    CGFloat r, g, b, a;
    return color && [color getRed:&r green:&g blue:&b alpha:&a] && a > 0.01 &&
        MAX(r, MAX(g, b)) < 0.8 && MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) < 0.12;
}

+ (void)prepareLabels:(UIView *)host state:(DYYYFeedTagGlassState *)state {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:host];
    Class yyLabel = NSClassFromString(@"YYLabel");
    for (NSUInteger index = 0; index < queue.count && index < 48; index++) {
        UIView *view = queue[index];
        if (view == state.glass || [view isKindOfClass:UIImageView.class]) continue;
        if ([view isKindOfClass:UILabel.class] || (yyLabel && [view isKindOfClass:yyLabel])) {
            @try {
                UIColor *color = [view valueForKey:@"textColor"];
                NSAttributedString *original = [view valueForKey:@"attributedText"];
                if (original.length) {
                    NSMutableAttributedString *text = [original mutableCopy];
                    __block BOOL changed = NO;
                    [original enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, original.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                        UIColor *source = [value isKindOfClass:UIColor.class] ? value : color;
                        if ([self needsLightText:source]) {
                            [text addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:range];
                            changed = YES;
                        }
                    }];
                    if (changed) [self write:text key:@"attributedText" view:view state:state];
                } else if ([self needsLightText:color]) [self write:UIColor.whiteColor key:@"textColor" view:view state:state];
            } @catch (__unused NSException *exception) {}
            continue;
        }
        [queue addObjectsFromArray:view.subviews];
    }
}

+ (void)restoreTag:(UIView *)tag {
    if (!NSThread.isMainThread || !tag) return;
    DYYYFeedTagGlassState *state = objc_getAssociatedObject(tag, &kDYYYFeedTagGlassKey);
    if (!state || state.busy) return;
    state.busy = YES;
    [state.glass removeFromSuperview];
    for (UIView *view in state.changes.keyEnumerator.allObjects) {
        NSDictionary *changes = [state.changes objectForKey:view];
        for (NSString *key in changes) {
            @try {
                NSDictionary *change = changes[key];
                id current = [view valueForKey:key] ?: NSNull.null;
                if ([current isEqual:change[@"applied"]])
                    [view setValue:change[@"original"] == NSNull.null ? nil : change[@"original"] forKey:key];
            } @catch (__unused NSException *exception) {}
        }
    }
    objc_setAssociatedObject(tag, &kDYYYFeedTagGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)decorateTag:(UIView *)tag {
    if (!NSThread.isMainThread || !tag) return;
    DYYYFeedTagGlassState *state = objc_getAssociatedObject(tag, &kDYYYFeedTagGlassKey);
    if (state.busy) return;
    if (![self isFeedTag:tag]) { [self restoreTag:tag]; return; }
    UIView *host = [self existingView:@"containerView" inTag:tag] ?: tag;
    if (CGRectIsEmpty(host.bounds)) { [self restoreTag:tag]; return; }
    if (state && state.host != host) { [self restoreTag:tag]; state = nil; }
    if (!state) {
        state = [DYYYFeedTagGlassState new];
        state.host = host;
        state.changes = [NSMapTable weakToStrongObjectsMapTable];
        state.glass = [[UIVisualEffectView alloc] initWithEffect:nil];
        state.glass.userInteractionEnabled = NO;
        state.glass.isAccessibilityElement = NO;
        state.glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(tag, &kDYYYFeedTagGlassKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (state.busy) return;
    state.busy = YES;
    @try {
        [self write:UIColor.clearColor key:@"backgroundColor" view:tag state:state];
        [self write:UIColor.clearColor key:@"backgroundColor" view:host state:state];
        [self write:@NO key:@"opaque" view:tag state:state];
        [self write:@NO key:@"opaque" view:host state:state];
        // 仅替换已确认的背景槽，图标、头像、文字、按钮及原生布局均保留。
        for (NSString *name in @[ @"backgroundView", @"backgroundImageView" ]) {
            UIView *background = [self existingView:name inTag:tag];
            if (background && background != host) [self write:@YES key:@"hidden" view:background state:state];
        }
        if (!CGRectEqualToRect(state.glass.frame, host.bounds)) state.glass.frame = host.bounds;
        state.glass.layer.cornerRadius = host.layer.cornerRadius > 0 ? host.layer.cornerRadius : MIN(6, CGRectGetHeight(host.bounds) * 0.5);
        state.glass.clipsToBounds = YES;
        state.glass.layer.borderWidth = 0.5;
        state.glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
        state.glass.contentView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.06];
        // 昵称上方标签固定为薄毛玻璃，不跟随面板的共享透明度设置。
        state.glass.alpha = 0.9;
        if (host.subviews.firstObject != state.glass) [host insertSubview:state.glass atIndex:0];
        if (!state.glass.effect) state.glass.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        [self prepareLabels:host state:state];
    } @finally { state.busy = NO; }
}

+ (BOOL)isLabelView:(UIView *)view {
    for (NSString *name in @[ @"AFDRecommendToFriendEntranceLabel", @"AFDFriendRecommendTagView", @"AWEPlayInteractionGeneralTagView",
                             @"AWEPlayInteractionTagsContainerLabelView", @"AWEPlayDislikeTagView", @"AWEPlayDislikeWithDrawTagView",
                             @"AWEPlayInteractionWatchVideoLaterTagView", @"AWEFeedTagsView", @"AWEFeedMultiTagView", @"AFDRecommendToFriendTagView" ]) {
        Class type = NSClassFromString(name);
        if (type && [view isKindOfClass:type]) return YES;
    }
    return NO;
}

+ (void)decorateStack:(UIView *)stack {
    if (!NSThread.isMainThread || !stack) return;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithArray:stack.subviews];
    for (NSUInteger index = 0; index < queue.count && index < 96; index++) {
        UIView *view = queue[index];
        if ([self isLabelView:view]) { [self decorateTag:view]; continue; }
        if (![view isKindOfClass:UIImageView.class] && ![view isKindOfClass:UILabel.class] && ![view isKindOfClass:UIVisualEffectView.class])
            [queue addObjectsFromArray:view.subviews];
    }
}

@end
