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

// 历史插入/批量更新期间保留原生锚点。只处理聊天专用表格，不挂全局 UITableView。
%group DYYYChatListUpdateHooks
%hook AWEIMMessageTableView
- (void)reloadData {
    id token = [DYYYChatInputList beginTableUpdates:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatInputList endTableUpdates:token];
    }
}
- (void)beginUpdates {
    [DYYYChatInputList beginTableUpdates:self];
    %orig;
}
- (void)endUpdates {
    @try {
        %orig;
    } @finally {
        [DYYYChatInputList endTableUpdates:[DYYYChatInputList tokenForTable:self]];
    }
}
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL))completion {
    id token = [DYYYChatInputList beginTableUpdates:self];
    __weak UITableView *weakTable = self;
    void (^wrappedCompletion)(BOOL) = ^(BOOL finished) {
        if (completion) completion(finished);
        [DYYYChatInputList synchronizeTable:weakTable];
    };
    @try {
        %orig(updates, wrappedCompletion);
    } @finally {
        [DYYYChatInputList endTableUpdates:token];
    }
}
- (void)layoutSubviews {
    %orig;
    [DYYYChatInputList synchronizeTable:self];
}
%end
%end
%group DYYYChatListScrollEndHooks
%hook AWEIMMessageListViewController
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig(scrollView, decelerate);
    if (!decelerate && [scrollView isKindOfClass:UITableView.class]) [DYYYChatInputList synchronizeTable:(id)scrollView];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig(scrollView);
    if ([scrollView isKindOfClass:UITableView.class]) [DYYYChatInputList synchronizeTable:(id)scrollView];
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
    static BOOL snapshotInstalled, pageInstalled, tipsInstalled, updatesInstalled, scrollInstalled;
    if (!updatesInstalled && NSClassFromString(@"AWEIMMessageTableView")) {
        %init(DYYYChatListUpdateHooks);
        updatesInstalled = YES;
    }
    Class listClass = NSClassFromString(@"AWEIMMessageListViewController");
    if (!scrollInstalled && [listClass instancesRespondToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)] &&
        [listClass instancesRespondToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        %init(DYYYChatListScrollEndHooks);
        scrollInstalled = YES;
    }
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
