/*
群聊功能栏原生组件入口参考 HierarchThurs/DYKiller DKChatTopClean.xm。
按用户要求增加可恢复隐藏与原生群头像命中代理。
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
#import "DYYYGroupChatToolbar.h"
#import "AwemeHeaders.h"
#import "DYYYUtils.h"
#import "DYYYChatChrome.h"
#import <objc/runtime.h>

static char kDYYYGroupToolbarKey, kDYYYGroupToggleKey, kDYYYGroupComponentStateKey;
// 原生标题 action 以点击位置区分头像等区域。三点真实手势映射到头像中心，保留原生路由与权限判断。
@interface DYYYGroupSettingsGesture : UITapGestureRecognizer
@property (nonatomic, weak) UIView *avatar;
@end
@implementation DYYYGroupSettingsGesture
- (CGPoint)locationInView:(UIView *)view {
    UIView *avatar = self.avatar;
    return avatar ? [avatar convertPoint:CGPointMake(CGRectGetMidX(avatar.bounds), CGRectGetMidY(avatar.bounds)) toView:view] : [super locationInView:view];
}
@end
@interface DYYYGroupSettingsButton : UIButton
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, strong) DYYYGroupSettingsGesture *routeGesture;
- (void)openSettings:(DYYYGroupSettingsGesture *)gesture;
@end
@interface DYYYGroupToolbarState : NSObject
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, weak) id zone;
@property (nonatomic, weak) UIView *toggle;
@property (nonatomic, strong) DYYYGroupSettingsButton *proxy;
@property (nonatomic, strong) NSMapTable<UIImageView *, NSDictionary *> *masks;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *bars;
@property (nonatomic, strong) NSMapTable<UIGestureRecognizer *, NSNumber *> *gestures;
@property (nonatomic) BOOL wanted;
@property (nonatomic) BOOL zoneSnapshotValid;
@property (nonatomic) BOOL restoreExpanded;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYGroupToolbarState
@end

@implementation DYYYGroupChatToolbar
+ (BOOL)enabled { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYHideGroupToolbar"]; }
+ (NSHashTable *)states {
    static NSHashTable *states; static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; }); return states;
}
+ (UIViewController *)host:(UIViewController *)controller {
    Class cls = NSClassFromString(@"AWEIMMessageBaseViewController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController)
        if (cls && [controller isKindOfClass:cls]) return controller;
    return nil;
}
+ (UIViewController *)hostForComponent:(id)component {
    DYYYGroupToolbarState *bound = objc_getAssociatedObject(component, &kDYYYGroupComponentStateKey);
    if (bound.host) return bound.host;
    if (![component respondsToSelector:@selector(context)]) return nil;
    id context = ((AWEIMComponentBase *)component).context;
    return [context respondsToSelector:@selector(hostViewController)] ? [self host:[context hostViewController]] : nil;
}
+ (DYYYGroupToolbarState *)state:(UIViewController *)host create:(BOOL)create {
    if (!host) return nil;
    DYYYGroupToolbarState *state = objc_getAssociatedObject(host, &kDYYYGroupToolbarKey);
    if (!state && create) {
        state = [DYYYGroupToolbarState new]; state.host = host;
        state.masks = [NSMapTable weakToStrongObjectsMapTable]; state.bars = [NSMapTable weakToStrongObjectsMapTable];
        state.gestures = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(host, &kDYYYGroupToolbarKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self states] addObject:state];
    }
    return state;
}
+ (BOOL)hiddenForComponent:(id)component { return [self enabled] && [self hostForComponent:component] != nil; }
+ (BOOL)isToggleView:(UIView *)view { return [objc_getAssociatedObject(view, &kDYYYGroupToggleKey) boolValue]; }
+ (void)captureToggle:(UIView *)view component:(id)component {
    if (!NSThread.isMainThread || !view) return;
    // getter 可能先于 context 绑定，挂载后 synchronizeHost 会从真实群栏补绑定。
    UIViewController *host = [self hostForComponent:component] ?: [self host:[DYYYUtils firstAvailableViewControllerFromView:view]];
    DYYYGroupToolbarState *state = [self state:host create:YES];
    if (!state) return;
    state.toggle = view;
    objc_setAssociatedObject(view, &kDYYYGroupToggleKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self synchronizeHost:host];
}
+ (void)captureZone:(id)component {
    if (!NSThread.isMainThread) return;
    DYYYGroupToolbarState *state = [self state:[self hostForComponent:component] create:YES];
    if (!state) return;
    if (state.zone != component) state.zoneSnapshotValid = NO;
    state.zone = component;
    [self synchronizeHost:state.host];
}
+ (AWEIMMessageListNaviBarTitleView *)titleForHost:(UIViewController *)host {
    for (UIView *view in host.viewIfLoaded.subviews) {
        if (![view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) continue;
        for (UIView *child in ((AWENavigationBar *)view).leftBtnsContainerView.subviews)
            if ([child isKindOfClass:NSClassFromString(@"AWEIMMessageListNaviBarTitleView")]) return (id)child;
    }
    return nil;
}
+ (UIView *)mountedToggleForHost:(UIViewController *)host {
    for (UIView *view in host.viewIfLoaded.subviews) {
        if (![view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) continue;
        NSArray<UIView *> *actions = ((AWENavigationBar *)view).rightBtnsContainerView.subviews;
        // 只认带原生群功能栏的单一下拉控件；电话+更多的原生布局不接管。
        if (actions.count != 1) return nil;
        UIView *toggle = actions.firstObject;
        if ([self isToggleView:toggle]) return toggle;
        if (toggle.class != UIView.class || !toggle.userInteractionEnabled || toggle.bounds.size.width > 48 || toggle.bounds.size.height > 48) return nil;
        if (toggle.subviews.count == 1 && [toggle.subviews.firstObject isKindOfClass:UIImageView.class]) return toggle;
    }
    return nil;
}
+ (void)bindMountedComponents:(DYYYGroupToolbarState *)state {
    if (state.zone) return;
    AWEIMComponentViewController *host = (id)state.host;
    if (![host respondsToSelector:@selector(componentManager)]) return;
    AWEIMComponentManager *manager = host.componentManager;
    if (![manager respondsToSelector:@selector(components)]) return;
    NSArray *components = manager.components;
    if (![components isKindOfClass:NSArray.class]) return;
    Class zoneClass = NSClassFromString(@"AWEIMGroupZoneConversationComponent");
    for (NSUInteger index = 0; index < MIN(components.count, 128); index++) {
        id component = components[index];
        if (!zoneClass || ![component isKindOfClass:zoneClass]) continue;
        if (state.zone != component) state.zoneSnapshotValid = NO;
        state.zone = component;
        objc_setAssociatedObject(component, &kDYYYGroupComponentStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        break;
    }
}
+ (void)restorePaint:(DYYYGroupToolbarState *)state {
    [state.proxy removeFromSuperview];
    for (UIImageView *icon in state.masks.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.masks objectForKey:icon];
        if (icon.layer.mask == saved[@"mask"]) icon.layer.mask = saved[@"native"] == NSNull.null ? nil : saved[@"native"];
    }
    [state.masks removeAllObjects];
    for (UIGestureRecognizer *gesture in state.gestures.keyEnumerator.allObjects)
        if (!gesture.enabled) gesture.enabled = [[state.gestures objectForKey:gesture] boolValue];
    [state.gestures removeAllObjects];
}
+ (void)synchronizeHost:(UIViewController *)host {
    if (!NSThread.isMainThread || !host || [self host:host] != host) return;
    UIView *entry = nil;
    for (UIView *child in host.viewIfLoaded.subviews)
        if ([NSStringFromClass(child.class) isEqual:@"AWEIMGroupImpl.GroupZoneEntryBarView"]) { entry = child; break; }
    DYYYGroupToolbarState *state = [self state:host create:entry != nil];
    if (!state || state.busy) return;
    state.busy = YES;
    @try {
        [self bindMountedComponents:state];
        UIView *mounted = [self mountedToggleForHost:host];
        if (mounted && mounted != state.toggle) {
            [self restorePaint:state]; state.toggle = mounted;
            objc_setAssociatedObject(mounted, &kDYYYGroupToggleKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        BOOL enabled = [self enabled];
        // 必须在原生收起前保存 hidden，否则关闭开关可能还原为收起后的状态。
        if (enabled && entry && ![state.bars objectForKey:entry]) [state.bars setObject:@(entry.hidden) forKey:entry];
        AWEIMGroupZoneConversationComponent *zone = state.zone;
        if (zone && [zone respondsToSelector:@selector(isGroupZoneExpanded)] && [zone respondsToSelector:@selector(toggleGroupZoneExpanded:)]) {
            BOOL expanded = zone.isGroupZoneExpanded;
            if (enabled) {
                if (!state.zoneSnapshotValid) {
                    state.restoreExpanded = expanded; state.zoneSnapshotValid = YES;
                    if (expanded) [zone toggleGroupZoneExpanded:NO];
                }
            } else if (state.zoneSnapshotValid) {
                state.zoneSnapshotValid = NO;
                if (state.restoreExpanded != expanded) [zone toggleGroupZoneExpanded:NO];
            }
        }
        if (state.wanted != enabled) { state.wanted = enabled; [host.viewIfLoaded setNeedsLayout]; }
        if (!enabled) {
            [self restorePaint:state];
            for (UIView *bar in state.bars.keyEnumerator.allObjects) if (bar.hidden) bar.hidden = [[state.bars objectForKey:bar] boolValue];
            [state.bars removeAllObjects]; return;
        }
        UIView *toggle = state.toggle;
        // 仅在原生标题入口可用时替换，避免展示没有可执行入口的按钮。
        AWEIMMessageListNaviBarTitleView *title = [self titleForHost:host];
        if (toggle && toggle.window && [toggle isDescendantOfView:host.viewIfLoaded] && [title respondsToSelector:@selector(p_didClickSelfWithGesture:)]) {
            if (!state.proxy) {
                state.proxy = [DYYYGroupSettingsButton buttonWithType:UIButtonTypeSystem];
                state.proxy.accessibilityLabel = @"群聊设置";
                state.proxy.accessibilityIdentifier = @"DYads.GroupSettings";
                [state.proxy setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
                state.proxy.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                state.proxy.routeGesture = [[DYYYGroupSettingsGesture alloc] initWithTarget:state.proxy action:@selector(openSettings:)];
                [state.proxy addGestureRecognizer:state.proxy.routeGesture];
            }
            state.proxy.host = host;
            UIColor *tint = [DYYYUtils isDarkMode] || host.viewIfLoaded.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIColor.whiteColor : UIColor.blackColor;
            if (![state.proxy.tintColor isEqual:tint]) state.proxy.tintColor = tint;
            if (!CGRectEqualToRect(state.proxy.frame, toggle.bounds)) state.proxy.frame = toggle.bounds;
            for (UIGestureRecognizer *gesture in toggle.gestureRecognizers) {
                if (![state.gestures objectForKey:gesture]) [state.gestures setObject:@(gesture.enabled) forKey:gesture];
                if (gesture.enabled) gesture.enabled = NO;
            }
            for (UIView *child in toggle.subviews) if ([child isKindOfClass:UIImageView.class]) {
                UIImageView *icon = (id)child;
                NSDictionary *saved = [state.masks objectForKey:icon];
                if (!saved || icon.layer.mask != saved[@"mask"]) {
                    CALayer *mask = [CALayer layer];
                    saved = @{ @"native": icon.layer.mask ?: NSNull.null, @"mask": mask };
                    [state.masks setObject:saved forKey:icon]; icon.layer.mask = mask;
                }
            }
            if (state.proxy.superview != toggle) [toggle addSubview:state.proxy];
            if (toggle.subviews.lastObject != state.proxy) [toggle bringSubviewToFront:state.proxy];
        } else [self restorePaint:state];
        if (entry && !entry.hidden) entry.hidden = YES;
    } @finally { state.busy = NO; }
}
+ (void)synchronizeEntry:(UIView *)view {
    [self synchronizeHost:[self host:[DYYYUtils firstAvailableViewControllerFromView:view]]];
}
+ (BOOL)blocksEntry:(UIView *)view { return [self enabled] && [self host:[DYYYUtils firstAvailableViewControllerFromView:view]] != nil; }
+ (void)refreshVisible {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisible]; }); return; }
    for (DYYYGroupToolbarState *state in [self states].allObjects) {
        [self synchronizeHost:state.host];
        for (UIView *view in state.host.viewIfLoaded.subviews)
            if ([view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) [DYYYChatChrome synchronizeTopForView:view];
    }
}
+ (NSDictionary *)diagnostics {
    NSMutableArray *rows = [NSMutableArray array];
    for (DYYYGroupToolbarState *state in [self states].allObjects) {
        [rows addObject:@{ @"boundZone": @(state.zone != nil), @"boundToggle": @(state.toggle != nil),
            @"replacementMounted": @(state.proxy.superview != nil), @"hiddenBars": @(state.bars.count),
            @"nativeSettingsAction": @([[self titleForHost:state.host] respondsToSelector:@selector(p_didClickSelfWithGesture:)]) }];
    }
    return @{ @"hidden": @([self enabled]), @"observedGroups": @(rows.count), @"states": rows,
        @"zoneHeightAvailable": @([NSClassFromString(@"AWEIMGroupZoneConversationComponent") instancesRespondToSelector:@selector(desiredGroupZoneHeight)]),
        @"toggleProviderAvailable": @([NSClassFromString(@"AWEIMMessageListNaviBarGroupZoneToggleComponent") instancesRespondToSelector:@selector(naviBarView)]) };
}
@end

@implementation DYYYGroupSettingsButton
- (void)openSettings:(DYYYGroupSettingsGesture *)gesture {
    UIViewController *host = self.host;
    if (!host.viewIfLoaded.window || (host.navigationController.visibleViewController && host.navigationController.visibleViewController != host)) return;
    AWEIMMessageListNaviBarTitleView *title = [DYYYGroupChatToolbar titleForHost:host];
    if (![title respondsToSelector:@selector(p_didClickSelfWithGesture:)]) return;
    UIView *avatar = title.avatarStackView;
    if (!avatar || avatar.hidden) return;
    gesture.avatar = avatar;
    [title p_didClickSelfWithGesture:gesture];
}
- (BOOL)accessibilityActivate {
    [self openSettings:self.routeGesture];
    return YES;
}
@end
