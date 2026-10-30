#import "DYYYGroupChatToolbar.h"
#import "AwemeHeaders.h"
%group DYYYGroupToggleHooks
%hook AWEIMMessageListNaviBarGroupZoneToggleComponent
- (UIView *)naviBarView {
    UIView *view = %orig;
    [DYYYGroupChatToolbar captureToggle:view component:self];
    return [DYYYGroupChatToolbar nativeDetailViewForComponent:self original:view];
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
    static BOOL toggle, zone, entry;
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
