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

static char kDYYYGroupToolbarKey, kDYYYGroupToggleKey;
@interface DYYYGroupSettingsButton : UIButton
@property (nonatomic, weak) UIViewController *host;
@end
@interface DYYYGroupToolbarState : NSObject
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, weak) id zone;
@property (nonatomic, weak) UIView *toggle;
@property (nonatomic, strong) DYYYGroupSettingsButton *proxy;
@property (nonatomic, strong) NSMapTable<UIImageView *, NSDictionary *> *masks;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *bars;
@property (nonatomic) BOOL wanted;
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
    if (![component respondsToSelector:@selector(context)]) return nil;
    return [self host:((AWEIMComponentBase *)component).context.hostViewController];
}
+ (DYYYGroupToolbarState *)state:(UIViewController *)host create:(BOOL)create {
    if (!host) return nil;
    DYYYGroupToolbarState *state = objc_getAssociatedObject(host, &kDYYYGroupToolbarKey);
    if (!state && create) {
        state = [DYYYGroupToolbarState new]; state.host = host;
        state.masks = [NSMapTable weakToStrongObjectsMapTable]; state.bars = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(host, &kDYYYGroupToolbarKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self states] addObject:state];
    }
    return state;
}
+ (BOOL)hiddenForComponent:(id)component { return [self enabled] && [self hostForComponent:component] != nil; }
+ (BOOL)isToggleView:(UIView *)view { return [objc_getAssociatedObject(view, &kDYYYGroupToggleKey) boolValue]; }
+ (void)captureToggle:(UIView *)view component:(id)component {
    if (!NSThread.isMainThread || !view) return;
    DYYYGroupToolbarState *state = [self state:[self hostForComponent:component] create:YES];
    if (!state) return;
    state.toggle = view;
    objc_setAssociatedObject(view, &kDYYYGroupToggleKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self synchronizeHost:state.host];
}
+ (void)captureZone:(id)component {
    if (!NSThread.isMainThread) return;
    DYYYGroupToolbarState *state = [self state:[self hostForComponent:component] create:YES];
    if (state.zone != component && state.wanted) state.wanted = NO;
    state.zone = component;
    [self synchronizeHost:state.host];
}
+ (UIView *)avatarForHost:(UIViewController *)host event:(UIEvent *)event {
    for (UIView *view in host.viewIfLoaded.subviews) {
        if (![view isKindOfClass:NSClassFromString(@"AWENavigationBar")]) continue;
        UIView *title = nil;
        for (UIView *child in ((AWENavigationBar *)view).leftBtnsContainerView.subviews)
            if ([child isKindOfClass:NSClassFromString(@"AWEIMMessageListNaviBarTitleView")]) { title = child; break; }
        if (!title) title = ((AWENavigationBar *)view).titleView;
        UIView *avatar = title.subviews.firstObject;
        if (!avatar || avatar.hidden || avatar.alpha <= 0.01) return nil;
        return [avatar hitTest:CGPointMake(CGRectGetMidX(avatar.bounds), CGRectGetMidY(avatar.bounds)) withEvent:event] ?: avatar;
    }
    return nil;
}
+ (void)synchronizeHost:(UIViewController *)host {
    if (!NSThread.isMainThread || !host) return;
    DYYYGroupToolbarState *state = [self state:host create:NO];
    if (!state || state.busy) return;
    state.busy = YES;
    @try {
        BOOL enabled = [self enabled];
        if (state.wanted != enabled) {
            state.wanted = enabled;
            AWEIMGroupZoneConversationComponent *zone = state.zone;
            if (zone && [zone respondsToSelector:@selector(isGroupZoneExpanded)] && [zone respondsToSelector:@selector(toggleGroupZoneExpanded:)]) {
                BOOL expanded = zone.isGroupZoneExpanded;
                if (enabled) { state.restoreExpanded = expanded; if (expanded) [zone toggleGroupZoneExpanded:NO]; }
                else if (state.restoreExpanded && !expanded) [zone toggleGroupZoneExpanded:NO];
            }
            [host.viewIfLoaded setNeedsLayout];
        }
        if (!enabled) {
            [state.proxy removeFromSuperview];
            for (UIImageView *icon in state.masks.keyEnumerator.allObjects) {
                NSDictionary *saved = [state.masks objectForKey:icon];
                if (icon.layer.mask == saved[@"mask"]) icon.layer.mask = saved[@"native"] == NSNull.null ? nil : saved[@"native"];
            }
            [state.masks removeAllObjects];
            for (UIView *bar in state.bars.keyEnumerator.allObjects) if (bar.hidden) bar.hidden = [[state.bars objectForKey:bar] boolValue];
            [state.bars removeAllObjects]; return;
        }
        UIView *toggle = state.toggle;
        if (toggle) {
            if (!state.proxy) {
                state.proxy = [DYYYGroupSettingsButton buttonWithType:UIButtonTypeSystem];
                state.proxy.accessibilityLabel = @"群聊设置";
                state.proxy.accessibilityIdentifier = @"DYads.GroupSettings";
                [state.proxy setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
                state.proxy.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            }
            state.proxy.host = host;
            UIColor *tint = [DYYYUtils isDarkMode] || host.viewIfLoaded.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIColor.whiteColor : UIColor.blackColor;
            if (![state.proxy.tintColor isEqual:tint]) state.proxy.tintColor = tint;
            if (!CGRectEqualToRect(state.proxy.frame, toggle.bounds)) state.proxy.frame = toggle.bounds;
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
        }
        for (UIView *bar in host.viewIfLoaded.subviews) {
            if (![NSStringFromClass(bar.class) isEqual:@"AWEIMGroupImpl.GroupZoneEntryBarView"]) continue;
            if (![state.bars objectForKey:bar]) [state.bars setObject:@(bar.hidden) forKey:bar];
            if (!bar.hidden) bar.hidden = YES;
        }
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
+ (NSDictionary *)diagnostics { return @{ @"hidden": @([self enabled]), @"observedGroups": @([self states].allObjects.count) }; }
@end

@implementation DYYYGroupSettingsButton
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (!hit) return nil;
    // 将点击交给原生群头像及其原生手势，不猜群设置路由、不复制私聊信息页、不发送伪造私有 action。
    return [DYYYGroupChatToolbar avatarForHost:self.host event:event] ?: hit;
}
- (BOOL)accessibilityActivate {
    UIView *avatar = [DYYYGroupChatToolbar avatarForHost:self.host event:nil];
    return avatar ? [avatar accessibilityActivate] : NO;
}
@end
