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
#import <objc/runtime.h>

static char kDYYYGroupToolbarKey, kDYYYGroupToggleKey, kDYYYGroupComponentStateKey, kDYYYNativeDetailKey, kDYYYObservedDetailClassKey, kDYYYToggleSourceKey, kDYYYObserveDetailBusyKey;
// 原 provider 由抖音管理；额外详情组件与它同寿命，只复用当前群 context/manager，不跨群复制 target。
@interface DYYYNativeGroupDetail : NSObject
@property (nonatomic, strong) AWEIMMessageListNaviBarChatDetailComponent *component;
@property (nonatomic, weak) id context;
@property (nonatomic, weak) id manager;
@property (nonatomic, weak) UIView *view;
@property (nonatomic) BOOL busy;
@property (nonatomic) BOOL attempted;
@property (nonatomic) Class componentClass;
@property (nonatomic, copy) NSString *decision;
@end
@implementation DYYYNativeGroupDetail
@end
@interface DYYYGroupToggleSource : NSObject
@property (nonatomic, weak) id component;
@end
@implementation DYYYGroupToggleSource
@end
@interface DYYYGroupToolbarState : NSObject
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, weak) id zone;
@property (nonatomic, weak) UIView *toggle;
@property (nonatomic, weak) id source;
@property (nonatomic) BOOL refreshAttempted;
@property (nonatomic) BOOL refreshPending;
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
    DYYYGroupToggleSource *source = objc_getAssociatedObject(view, &kDYYYToggleSourceKey);
    if (!source) { source = [DYYYGroupToggleSource new]; objc_setAssociatedObject(view, &kDYYYToggleSourceKey, source, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    source.component = component;
    // getter 可能先于 context 绑定，挂载后 synchronizeHost 会从真实群栏补绑定。
    UIViewController *host = [self hostForComponent:component] ?: [self host:[DYYYUtils firstAvailableViewControllerFromView:view]];
    DYYYGroupToolbarState *state = [self state:host create:YES];
    if (!state) return;
    state.toggle = view; state.source = component;
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
    [self observeNativeDetailForHost:host];
    DYYYGroupToolbarState *state = [self state:host create:entry != nil];
    if (!state || state.busy) return;
    state.busy = YES;
    @try {
        [self bindMountedComponents:state];
        UIView *mounted = [self mountedToggleForHost:host];
        if (mounted && mounted != state.toggle) {
            state.toggle = mounted;
            DYYYGroupToggleSource *source = objc_getAssociatedObject(mounted, &kDYYYToggleSourceKey);
            if (source.component) state.source = source.component;
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
        if (!state.refreshAttempted && state.source) [self scheduleNativeRefresh:state];
    } @finally { state.busy = NO; }
}
+ (void)synchronizeEntry:(UIView *)view {
    [self synchronizeHost:[self host:[DYYYUtils firstAvailableViewControllerFromView:view]]];
}
+ (BOOL)blocksEntry:(UIView *)view { return [self enabled] && [self host:[DYYYUtils firstAvailableViewControllerFromView:view]] != nil; }
+ (void)refreshVisible {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisible]; }); return; }
    for (DYYYGroupToolbarState *state in [self states].allObjects) {
        state.refreshAttempted = NO;
        DYYYNativeGroupDetail *detail = objc_getAssociatedObject(state.source, &kDYYYNativeDetailKey);
        if (!detail.component) detail.attempted = NO;
        [self synchronizeHost:state.host];
        [self scheduleNativeRefresh:state];
        for (UIView *view in state.host.viewIfLoaded.subviews)
            if ([view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) [DYYYChatChrome synchronizeTopForView:view];
    }
}
// 识别已有原生更多按钮的真实 provider 类型，只记 Class，不持有别的群的 target/上下文。
+ (void)observeNativeDetailForHost:(UIViewController *)host {
    Class base = NSClassFromString(@"AWEIMComponentBase");
    if (!base || [objc_getAssociatedObject(host, &kDYYYObserveDetailBusyKey) boolValue]) return;
    objc_setAssociatedObject(host, &kDYYYObserveDetailBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        for (UIView *view in host.viewIfLoaded.subviews) if ([view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) {
            for (UIView *action in ((AWENavigationBar *)view).rightBtnsContainerView.subviews) {
                if (![action isKindOfClass:NSClassFromString(@"AWEIMMessageBaseVCMoreButton")]) continue;
                for (id target in ((UIControl *)action).allTargets) {
                    if (![target isKindOfClass:base] || ![target respondsToSelector:@selector(naviBarView)] ||
                        ![target respondsToSelector:@selector(setContext:)] || ![target respondsToSelector:@selector(setBelongingManager:)]) continue;
                    Class previous = objc_getAssociatedObject(self, &kDYYYObservedDetailClassKey);
                    if (previous == [target class]) continue;
                    @try { if (((AWEIMMessageListNaviBarChatDetailComponent *)target).naviBarView != action) continue; }
                    @catch (__unused NSException *exception) { continue; }
                    objc_setAssociatedObject(self, &kDYYYObservedDetailClassKey, [target class], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    for (DYYYGroupToolbarState *state in [self states].allObjects) {
                        if (![self enabled]) continue;
                        state.refreshAttempted = NO; [self scheduleNativeRefresh:state];
                    }
                }
            }
        }
    } @finally { objc_setAssociatedObject(host, &kDYYYObserveDetailBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
+ (void)scheduleNativeRefresh:(DYYYGroupToolbarState *)state {
    if (state.refreshPending || !state.host.viewIfLoaded.window || !state.source) return;
    if (![state.source respondsToSelector:@selector(context)] || ![state.source respondsToSelector:@selector(belongingManager)] ||
        !((AWEIMComponentBase *)state.source).context || !((AWEIMComponentBase *)state.source).belongingManager) return;
    state.refreshPending = YES; state.refreshAttempted = YES;
    __weak DYYYGroupToolbarState *weakState = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYGroupToolbarState *current = weakState;
        if (!current) return;
        current.refreshPending = NO;
        UIViewController *host = current.host;
        if (!host.viewIfLoaded.window || (host.navigationController.visibleViewController && host.navigationController.visibleViewController != host)) return;
        AWEIMComponentManager *manager = ((AWEIMComponentBase *)current.source).belongingManager;
        if (![manager respondsToSelector:@selector(components)]) return;
        NSArray *components = manager.components;
        if (![components isKindOfClass:NSArray.class]) return;
        Class navClass = NSClassFromString(@"AWEIMMessageListNaviBarComponent");
        for (NSUInteger i = 0; i < MIN(components.count, 128); i++) {
            id component = components[i];
            if (navClass && [component isKindOfClass:navClass] && [component respondsToSelector:@selector(setNeedsUpdateNaviBar)]) {
                [component setNeedsUpdateNaviBar]; break;
            }
        }
    });
}
+ (UIView *)nativeDetailViewForComponent:(id)source original:(UIView *)original {
    if (!NSThread.isMainThread || ![self enabled]) return original;
    DYYYNativeGroupDetail *native = objc_getAssociatedObject(source, &kDYYYNativeDetailKey);
    if (!native) {
        native = [DYYYNativeGroupDetail new];
        objc_setAssociatedObject(source, &kDYYYNativeDetailKey, native, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (native.busy) return original;
    native.busy = YES;
    @try {
        if (![source respondsToSelector:@selector(context)] || ![source respondsToSelector:@selector(belongingManager)]) {
            native.decision = @"source_binding_unavailable"; return original;
        }
        id context = ((AWEIMComponentBase *)source).context;
        id manager = ((AWEIMComponentBase *)source).belongingManager;
        UIViewController *host = [self hostForComponent:source];
        if (!context || !manager || !host) { native.decision = @"waiting_native_context"; return original; }
        Class cls = objc_getAssociatedObject(self, &kDYYYObservedDetailClassKey) ?: NSClassFromString(@"AWEIMMessageListNaviBarChatDetailComponent");
        if (!cls || ![cls instancesRespondToSelector:@selector(naviBarView)] || ![cls instancesRespondToSelector:@selector(setContext:)] ||
            ![cls instancesRespondToSelector:@selector(setBelongingManager:)]) {
            native.decision = @"native_detail_provider_unavailable"; return original;
        }
        if (native.context != context || native.manager != manager || native.componentClass != cls) {
            native.component = nil; native.attempted = NO;
            native.context = context; native.manager = manager; native.componentClass = cls;
        }
        if (!native.component) {
            // 同一绑定只初始化一次；失败不在布局中持续分配/重试。换上下文或手动切换才允许重试。
            if (native.attempted) return original;
            native.attempted = YES;
            AWEIMMessageListNaviBarChatDetailComponent *detail = [[cls alloc] init];
            if (!detail) { native.decision = @"native_detail_init_failed"; return original; }
            detail.context = context; detail.belongingManager = manager;
            native.component = detail;
            if (host.isViewLoaded && [detail respondsToSelector:@selector(hostVC_viewDidLoad)]) [detail hostVC_viewDidLoad];
        }
        UIView *view = native.component.naviBarView;
        if (![view isKindOfClass:NSClassFromString(@"AWEIMMessageBaseVCMoreButton")]) {
            native.decision = @"native_detail_did_not_return_more"; return original;
        }
        UIControl *button = (id)view;
        if (!button.allTargets.count || !button.enabled || !button.userInteractionEnabled) {
            native.decision = @"native_more_action_not_ready"; return original;
        }
        native.view = view; native.decision = @"returned_native_more_with_action";
        return view;
    } @catch (__unused NSException *exception) {
        native.decision = @"native_detail_setup_exception"; return original;
    } @finally { native.busy = NO; }
}
+ (NSDictionary *)diagnostics {
    NSMutableArray *rows = [NSMutableArray array];
    for (DYYYGroupToolbarState *state in [self states].allObjects) {
        BOOL nativeMore = NO; NSUInteger nativeTargets = 0;
        for (UIView *view in state.host.viewIfLoaded.subviews) if ([view isKindOfClass:NSClassFromString(@"AWENavigationBar")])
            for (UIView *action in ((AWENavigationBar *)view).rightBtnsContainerView.subviews)
                if ([action isKindOfClass:NSClassFromString(@"AWEIMMessageBaseVCMoreButton")]) { nativeMore = YES; nativeTargets += ((UIControl *)action).allTargets.count; }
        DYYYNativeGroupDetail *detail = objc_getAssociatedObject(state.source, &kDYYYNativeDetailKey);
        [rows addObject:@{ @"boundZone": @(state.zone != nil), @"hiddenBars": @(state.bars.count), @"nativeMoreMounted": @(nativeMore), @"nativeMoreTargets": @(nativeTargets), @"providerDecision": detail.decision ?: @"provider_not_called",
            @"replacementClass": detail.component ? NSStringFromClass(detail.component.class) : @"", @"refreshAttempted": @(state.refreshAttempted) }];
    }
    return @{ @"hidden": @([self enabled]), @"observedGroups": @(rows.count), @"states": rows,
        @"nativeDetailClassAvailable": @(NSClassFromString(@"AWEIMMessageListNaviBarChatDetailComponent") != nil),
        @"observedDetailClass": NSStringFromClass(objc_getAssociatedObject(self, &kDYYYObservedDetailClassKey)) ?: @"",
        @"settingsRoute": @"native_group_toggle_provider_replacement" };
}
@end
