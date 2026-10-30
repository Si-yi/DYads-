#import "DYYYChatChrome.h"
#import "AwemeHeaders.h"

%group DYYYChatChromeNavigationHooks
%hook AWENavigationBar
- (void)layoutSubviews {
    id token = [DYYYChatChrome beginTopUpdate:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatChrome endTopUpdate:token];
    }
    if (!token) [DYYYChatChrome synchronizeBar:self];
    [DYYYChatChrome scheduleTopSynchronization:self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYChatChrome synchronizeBar:self];
    [DYYYChatChrome scheduleTopSynchronization:self];
}
%end
%end
%group DYYYChatChromeConfigurationHooks
%hook AWENavigationBar
- (void)addRightNaviBarBtnView:(UIView *)view {
    %orig(view);
    [DYYYChatChrome scheduleTopSynchronization:self];
}
- (void)setRightBtnsContainerView:(UIView *)view {
    %orig(view);
    [DYYYChatChrome scheduleTopSynchronization:self];
}
- (void)setContentView:(UIView *)view {
    %orig(view);
    [DYYYChatChrome scheduleTopSynchronization:self];
}
%end
%end
%group DYYYChatChromeUnreadHooks
%hook AWEIMNavigationUnreadView
- (void)layoutSubviews {
    id token = [DYYYChatChrome beginTopUpdate:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatChrome endTopUpdate:token];
    }
}
- (void)updateWithCount:(long long)count {
    id token = [DYYYChatChrome beginTopUpdate:self];
    @try {
        %orig(count);
    } @finally {
        [DYYYChatChrome endTopUpdate:token];
    }
}
- (void)p_updateUI {
    id token = [DYYYChatChrome beginTopUpdate:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatChrome endTopUpdate:token];
    }
}
%end
%end
%group DYYYChatChromeUnreadSubclassHooks
%hook AWEIMMessageVCNavigationUnreadView
- (void)updateWithCount:(long long)count {
    id token = [DYYYChatChrome beginTopUpdate:self];
    @try {
        %orig(count);
    } @finally {
        [DYYYChatChrome endTopUpdate:token];
    }
}
%end
%end
%group DYYYChatChromeTitleHooks
%hook AWEIMMessageListNaviBarTitleView
- (void)layoutSubviews {
    id token = [DYYYChatChrome beginTopUpdate:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatChrome endTopUpdate:token];
    }
    if (!token) [DYYYChatChrome synchronizeTopForView:self];
}
%end
%end
%group DYYYChatChromePanelHooks
%hook AWEIMEmoticonPanelContainerView
- (void)layoutSubviews {
    %orig;
    [DYYYChatChrome synchronizePanel:self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYChatChrome synchronizePanel:self];
}
%end
%end
%group DYYYChatChromePanelThemeHooks
%hook AWEIMEmoticonPanelContainerView
- (void)refreshBackgroundColorWhileHasBackground:(BOOL)hasBackground {
    %orig(hasBackground);
    [DYYYChatChrome synchronizePanel:self];
}
%end
%end
%group DYYYChatChromeHostHooks
%hook AWEIMMessageBaseViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYChatChrome synchronizeHost:self];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [DYYYChatChrome synchronizeHost:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [DYYYChatChrome restoreHost:self];
}
%end
%end

@implementation DYYYChatChrome (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    [self preparePreferences];
    static BOOL nav, configuration, unread, unreadSubclass, title, panel, theme, host;
    if (!nav && NSClassFromString(@"AWENavigationBar")) { %init(DYYYChatChromeNavigationHooks); nav = YES; }
    Class navClass = NSClassFromString(@"AWENavigationBar");
    if (!configuration && [navClass instancesRespondToSelector:@selector(addRightNaviBarBtnView:)] &&
        [navClass instancesRespondToSelector:@selector(setRightBtnsContainerView:)] && [navClass instancesRespondToSelector:@selector(setContentView:)]) {
        %init(DYYYChatChromeConfigurationHooks);
        configuration = YES;
    }
    Class unreadClass = NSClassFromString(@"AWEIMNavigationUnreadView");
    if (!unread && [unreadClass instancesRespondToSelector:@selector(p_updateUI)]) { %init(DYYYChatChromeUnreadHooks); unread = YES; }
    Class unreadSubclassClass = NSClassFromString(@"AWEIMMessageVCNavigationUnreadView");
    if (!unreadSubclass && [unreadSubclassClass instancesRespondToSelector:@selector(updateWithCount:)]) { %init(DYYYChatChromeUnreadSubclassHooks); unreadSubclass = YES; }
    if (!title && NSClassFromString(@"AWEIMMessageListNaviBarTitleView")) { %init(DYYYChatChromeTitleHooks); title = YES; }
    Class panelClass = NSClassFromString(@"AWEIMEmoticonPanelContainerView");
    if (!panel && panelClass) { %init(DYYYChatChromePanelHooks); panel = YES; }
    if (!theme && [panelClass instancesRespondToSelector:@selector(refreshBackgroundColorWhileHasBackground:)]) { %init(DYYYChatChromePanelThemeHooks); theme = YES; }
    if (!host && NSClassFromString(@"AWEIMMessageBaseViewController")) { %init(DYYYChatChromeHostHooks); host = YES; }
}
@end

%ctor {
    [DYYYChatChrome installHooks];
}
