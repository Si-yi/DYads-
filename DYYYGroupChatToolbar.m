/*
群聊功能栏原生组件入口参考 HierarchThurs/DYKiller DKChatTopClean.xm。
按用户要求增加可恢复隐藏，由原生组件管理器提供聊天详情入口。
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
#import "DYYYGroupChatComponents.h"
#import <objc/runtime.h>

static char kDYYYGroupToolbarKey, kDYYYGroupToggleKey, kDYYYGroupComponentStateKey;
@interface DYYYGroupToolbarState : NSObject
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, weak) id zone;
@property (nonatomic, weak) UIView *toggle;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *bars;
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
        state.bars = [NSMapTable weakToStrongObjectsMapTable];
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
            state.toggle = mounted;
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
            for (UIView *bar in state.bars.keyEnumerator.allObjects) if (bar.hidden) bar.hidden = [[state.bars objectForKey:bar] boolValue];
            [state.bars removeAllObjects]; return;
        }
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
// 普通私聊/原生电话+更多布局不包含群下拉组件，数组原样保留。
+ (id)nativeNavigationComponents:(id)components host:(UIViewController *)host {
    BOOL ready = [self enabled] && [self host:host] == host &&
        [NSClassFromString(@"AWEIMMessageListNaviBarChatDetailComponent") instancesRespondToSelector:@selector(naviBarView)];
    return [DYYYGroupChatComponents navigationComponents:components enabled:ready];
}
+ (NSDictionary *)diagnostics {
    NSMutableArray *rows = [NSMutableArray array];
    for (DYYYGroupToolbarState *state in [self states].allObjects) {
        BOOL nativeMore = NO; NSUInteger nativeTargets = 0;
        for (UIView *view in state.host.viewIfLoaded.subviews) if ([view isKindOfClass:NSClassFromString(@"AWENavigationBar")])
            for (UIView *action in ((AWENavigationBar *)view).rightBtnsContainerView.subviews)
                if ([action isKindOfClass:NSClassFromString(@"AWEIMMessageBaseVCMoreButton")]) { nativeMore = YES; nativeTargets += ((UIControl *)action).allTargets.count; }
        [rows addObject:@{ @"boundZone": @(state.zone != nil), @"hiddenBars": @(state.bars.count), @"nativeMoreMounted": @(nativeMore), @"nativeMoreTargets": @(nativeTargets) }];
    }
    return @{ @"hidden": @([self enabled]), @"observedGroups": @(rows.count), @"states": rows,
        @"configuration": [DYYYGroupChatComponents diagnostics], @"settingsRoute": @"native_chat_detail_component" };
}
@end
