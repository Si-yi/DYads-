#import "DYYYGroupChatToolbar.h"
#import "AwemeHeaders.h"
%group DYYYGroupNativeNavigationHooks
%hook AWEIMConversationViewController
- (id)componentsNameArrayWithContext:(id)context {
    id components = %orig(context);
    return [DYYYGroupChatToolbar nativeNavigationComponents:components host:self];
}
- (id)p_componentsNameArrayWithContext:(id)context {
    id components = %orig(context);
    return [DYYYGroupChatToolbar nativeNavigationComponents:components host:self];
}
- (id)lazyComponentsNameWithContext:(id)context {
    id components = %orig(context);
    return [DYYYGroupChatToolbar nativeNavigationComponents:components host:self];
}
- (id)p_lazyComponentsNameWithContext:(id)context {
    id components = %orig(context);
    return [DYYYGroupChatToolbar nativeNavigationComponents:components host:self];
}
%end
%end
%group DYYYGroupToggleHooks
%hook AWEIMMessageListNaviBarGroupZoneToggleComponent
- (UIView *)naviBarView {
    UIView *view = %orig;
    [DYYYGroupChatToolbar captureToggle:view component:self];
    return view;
}
%end
%end
%group DYYYGroupZoneHooks
%hook AWEIMGroupZoneConversationComponent
- (double)desiredGroupZoneHeight {
    if ([DYYYGroupChatToolbar hiddenForComponent:self]) return 0;
    return %orig;
}
- (void)hostVC_viewDidLoad {
    %orig;
    [DYYYGroupChatToolbar captureZone:self];
}
%end
%end
%group DYYYGroupEntryHooks
%hook DYYYNativeGroupEntryBar
- (void)layoutSubviews {
    %orig;
    [DYYYGroupChatToolbar synchronizeEntry:self];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if ([DYYYGroupChatToolbar blocksEntry:self]) return nil;
    return %orig;
}
%end
%end
@implementation DYYYGroupChatToolbar (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; }); return; }
    static BOOL toggle, zone, entry, navigation;
    Class conversation = NSClassFromString(@"AWEIMConversationViewController");
    if (!navigation && [conversation instancesRespondToSelector:@selector(componentsNameArrayWithContext:)] &&
        [conversation instancesRespondToSelector:@selector(p_componentsNameArrayWithContext:)] &&
        [conversation instancesRespondToSelector:@selector(lazyComponentsNameWithContext:)] &&
        [conversation instancesRespondToSelector:@selector(p_lazyComponentsNameWithContext:)]) {
        %init(DYYYGroupNativeNavigationHooks);
        navigation = YES;
    }
    Class toggleClass = NSClassFromString(@"AWEIMMessageListNaviBarGroupZoneToggleComponent");
    if (!toggle && [toggleClass instancesRespondToSelector:@selector(naviBarView)]) {
        %init(DYYYGroupToggleHooks);
        toggle = YES;
    }
    Class zoneClass = NSClassFromString(@"AWEIMGroupZoneConversationComponent");
    if (!zone && [zoneClass instancesRespondToSelector:@selector(desiredGroupZoneHeight)] &&
        [zoneClass instancesRespondToSelector:@selector(hostVC_viewDidLoad)]) {
        %init(DYYYGroupZoneHooks);
        zone = YES;
    }
    Class entryClass = NSClassFromString(@"AWEIMGroupImpl.GroupZoneEntryBarView");
    if (!entry && entryClass) {
        %init(DYYYGroupEntryHooks, DYYYNativeGroupEntryBar = entryClass);
        entry = YES;
    }
}
@end
%ctor { [DYYYGroupChatToolbar installHooks]; }
