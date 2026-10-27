#import "AwemeHeaders.h"
#import "DYYYChatInputGlass.h"
#import "DYYYChatInputList.h"

%group DYYYChatInputGlassHooks
%hook IESIMInputViewController
- (void)viewDidLayoutSubviews {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [DYYYChatInputGlass synchronizeController:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    [DYYYChatInputGlass restoreController:self];
    %orig(animated);
    [DYYYChatInputGlass restoreController:self];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig(previous);
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
- (void)refreshbackground:(BOOL)refresh {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig(refresh);
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
- (void)setHasBackgroundImage:(BOOL)hasImage {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig(hasImage);
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
%end
%end

// 只钩消息页自己的布局组件，不在全局 UIView/UITableView frame setter 中撑高。
%group DYYYChatListSnapshotHooks
%hook AWEIMMessageListLayoutComponent
- (void)p_layoutWithAnimation:(BOOL)animated coordinate:(id)coordinate {
    id token = [DYYYChatInputList beginNativeLayoutForComponent:self];
    @try {
        %orig(animated, coordinate);
    } @finally {
        [DYYYChatInputList endNativeLayout:token];
    }
}
%end
%end
%group DYYYChatListPageHooks
%hook AWEIMMessageListLayoutComponent
- (void)updatePageLayout:(id)layoutInfo {
    id token = [DYYYChatInputList beginNativeLayoutForComponent:self];
    @try {
        %orig(layoutInfo);
    } @finally {
        [DYYYChatInputList endNativeLayout:token];
    }
}
%end
%end
%group DYYYChatListTipsHooks
%hook AWEIMBottomNewMessageTipsImageView
- (void)setFrame:(CGRect)frame {
    %orig([DYYYChatInputList frameForBottomTips:self proposedFrame:frame]);
}
%end
%end

@implementation DYYYChatInputGlass (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL installed;
    if (!installed && NSClassFromString(@"IESIMInputViewController")) {
        %init(DYYYChatInputGlassHooks);
        installed = YES;
    }
    static BOOL snapshotInstalled, pageInstalled, tipsInstalled;
    Class layout = NSClassFromString(@"AWEIMMessageListLayoutComponent");
    if (!snapshotInstalled && [layout instancesRespondToSelector:@selector(p_layoutWithAnimation:coordinate:)]) {
        %init(DYYYChatListSnapshotHooks);
        snapshotInstalled = YES;
    }
    if (!pageInstalled && [layout instancesRespondToSelector:@selector(updatePageLayout:)]) {
        %init(DYYYChatListPageHooks);
        pageInstalled = YES;
    }
    if (!tipsInstalled && NSClassFromString(@"AWEIMBottomNewMessageTipsImageView")) {
        %init(DYYYChatListTipsHooks);
        tipsInstalled = YES;
    }
}
@end

%ctor {
    [DYYYChatInputGlass installHooks];
}
