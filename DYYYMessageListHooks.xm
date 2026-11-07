#import "AwemeHeaders.h"
#import "DYYYMessageListStyle.h"
#import "DYYYInteractionNoticeStyle.h"
#import "DYYYMessageListViewport.h"
#import "DYYYRefreshIndicatorStyle.h"
#import "DYYYChatEnhancementPolicy.h"

%group DYYYMessageListControllerHooks
%hook AWEIMChatListViewController
- (void)viewDidLayoutSubviews { %orig; [DYYYMessageListStyle synchronizeController:self]; }
- (void)viewWillAppear:(BOOL)animated { %orig(animated); [DYYYMessageListStyle synchronizeController:self]; }
- (void)viewDidAppear:(BOOL)animated { %orig(animated); [DYYYMessageListStyle synchronizeController:self]; }
- (void)tableView:(UITableView *)table willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {
    %orig(table,cell,path); [DYYYMessageListStyle synchronizeCell:cell];
}
- (void)tableView:(UITableView *)table didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {
    [DYYYMessageListStyle resetCell:cell]; %orig(table,cell,path);
}
%end
%end
%group DYYYMessageViewportTableHooks
%hook AWEIMChatTabTableView
- (void)setFrame:(CGRect)frame { %orig([DYYYMessageListViewport nativeFrame:frame table:(UITableView *)self]); }
- (void)setContentInsetAdjustmentBehavior:(UIScrollViewContentInsetAdjustmentBehavior)behavior { %orig([DYYYMessageListViewport nativeAdjustment:behavior table:(UITableView *)self]); }
- (void)setContentInset:(UIEdgeInsets)inset { %orig([DYYYMessageListViewport nativeInset:inset table:(UITableView *)self indicator:NO]); }
- (void)setVerticalScrollIndicatorInsets:(UIEdgeInsets)inset { %orig([DYYYMessageListViewport nativeInset:inset table:(UITableView *)self indicator:YES]); }
- (void)didMoveToWindow { %orig;if(!((UIView *)self).window)[DYYYMessageListViewport detachTable:(UITableView *)self]; }
%end
%end
%group DYYYMessageViewportScrollHooks
%hook AWEIMChatListViewController
- (void)scrollViewDidEndDragging:(UIScrollView *)scroll willDecelerate:(BOOL)decelerate { %orig(scroll,decelerate);if(!decelerate)[DYYYMessageListViewport synchronizeController:(UIViewController *)self]; }
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scroll { %orig(scroll);[DYYYMessageListViewport synchronizeController:(UIViewController *)self]; }
%end
%end
%group DYYYMessageListDataHooks
%hook AWEIMChatListViewController
- (void)setChatList:(NSArray *)chats { %orig(chats); [DYYYMessageListStyle synchronizeController:self]; }
%end
%end
%group DYYYMessageListRowHeightHooks
%hook AWEIMChatListViewController
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    CGFloat native=%orig(table,path);
    return [DYYYMessageListStyle rowHeight:native controller:self table:table indexPath:path];
}
%end
%end
%group DYYYMessageLightInteractionHooks
%hook AWEIMChatCellRecommendChatLIView
- (void)layoutSubviews { %orig; [DYYYMessageListStyle synchronizeLightInteraction:self]; }
- (void)didMoveToWindow { %orig; if(self.window)[DYYYMessageListStyle synchronizeLightInteraction:self];else [DYYYMessageListStyle resetLightInteraction:self]; }
%end
%end
%group DYYYMessageListCellHooks
%hook AWEIMChatListCommonCell
- (void)layoutSubviews { %orig; [DYYYMessageListStyle synchronizeCell:self]; }
- (void)didMoveToWindow { %orig; if(self.window)[DYYYMessageListStyle synchronizeCell:self];else [DYYYMessageListStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYMessageListStyle resetCell:self]; %orig; }
- (void)renderWithHolder:(id)holder { %orig(holder); [DYYYMessageListStyle synchronizeCell:self]; }
%end
%end
%group DYYYMessageContentGeometryHooks
// 仅接管已关联消息列表状态的 contentView；其他 Cell 原样透传。
%hook UITableViewCellContentView
- (void)setFrame:(CGRect)frame {
    CGRect native=[DYYYMessageListStyle nativeContentFrame:frame forView:self];
    id token=[DYYYMessageListStyle beginContentGeometry:self];
    @try { %orig(native); } @finally { [DYYYMessageListStyle endContentGeometry:token]; }
}
- (void)setBounds:(CGRect)bounds {
    id token=[DYYYMessageListStyle beginContentGeometry:self];
    @try { %orig(bounds); } @finally { [DYYYMessageListStyle endContentGeometry:token]; }
}
- (void)setCenter:(CGPoint)center {
    id token=[DYYYMessageListStyle beginContentGeometry:self];
    @try { %orig(center); } @finally { [DYYYMessageListStyle endContentGeometry:token]; }
}
- (void)setTransform:(CGAffineTransform)transform {
    %orig([DYYYMessageListStyle nativeContentTransform:transform forView:self]);
    [DYYYMessageListStyle didSetContentTransform:self];
}
%end
%end
%group DYYYMessageListBarHooks
%hook AWENavigationBar
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {if([DYYYMessageListStyle passThroughNoticeActions:point bar:(UIView *)self])return nil;return %orig(point,event);}
- (void)setBackgroundColor:(UIColor *)color { %orig([DYYYMessageListStyle nativeBackgroundColor:color forBar:self]); }
- (void)setOpaque:(BOOL)opaque { %orig([DYYYMessageListStyle nativeOpaque:opaque forBar:self]); }
- (void)layoutSubviews { %orig; [DYYYInteractionNoticeStyle installHooks]; [DYYYRefreshIndicatorStyle installHooks]; [DYYYMessageListStyle synchronizeBar:self]; [DYYYMessageListStyle scheduleBarSynchronization:self]; }
- (void)didMoveToWindow { %orig; [DYYYMessageListStyle synchronizeBar:self]; [DYYYMessageListStyle scheduleBarSynchronization:self]; }
%end
%end
%group DYYYMessageListBarConfigurationHooks
%hook AWENavigationBar
- (void)addRightNaviBarBtnView:(UIView *)view { %orig(view); [DYYYMessageListStyle synchronizeBar:self]; [DYYYMessageListStyle scheduleBarSynchronization:self]; }
- (void)setRightBtnsContainerView:(UIView *)view { %orig(view); [DYYYMessageListStyle synchronizeBar:self]; [DYYYMessageListStyle scheduleBarSynchronization:self]; }
%end
%end
%group DYYYMessageListCellThemeHooks
%hook AWEIMChatListCommonCell
- (void)onThemeDidChanged { %orig; [DYYYMessageListStyle synchronizeCell:self]; }
%end
%end
%group DYYYNoticeTabSelectionHooks
%hook AWEIMFansAndInteractMergeViewControllerNaviBar
- (void)setFrame:(CGRect)frame {id token=[DYYYMessageListStyle beginNoticePlateFrame:(UIView *)self];@try {%orig(frame);}@finally {[DYYYMessageListStyle endNoticePlateFrame:token];}}
- (void)setSelectedIndex:(long long)index { %orig(index); [DYYYMessageListStyle synchronizeHeaderForView:(UIView *)self]; }
%end
%end
%ctor {
    [DYYYMessageListStyle preparePreferences];
    if([DYYYMessageListStyle contentAdapterReady]) { %init(DYYYMessageContentGeometryHooks); }
    if([DYYYMessageListViewport adapterReady]){%init(DYYYMessageViewportTableHooks);}
    Class list=NSClassFromString(@"AWEIMChatListViewController"),cell=NSClassFromString(@"AWEIMChatListCommonCell");
    if([list isSubclassOfClass:UIViewController.class] &&
        [DYYYChatEnhancementPolicy class:list selector:@selector(tableView) result:'@' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:list selector:@selector(chatList) result:'@' arguments:@""]) {
        %init(DYYYMessageListControllerHooks);
        if([DYYYChatEnhancementPolicy class:list selector:@selector(scrollViewDidEndDragging:willDecelerate:) result:'v' arguments:[@"@" stringByAppendingString:[NSString stringWithUTF8String:@encode(BOOL)]]] && [DYYYChatEnhancementPolicy class:list selector:@selector(scrollViewDidEndDecelerating:) result:'v' arguments:@"@"]) {%init(DYYYMessageViewportScrollHooks);}
        if([DYYYChatEnhancementPolicy class:list selector:@selector(tableView:heightForRowAtIndexPath:) result:@encode(CGFloat)[0] arguments:@"@@"]) { %init(DYYYMessageListRowHeightHooks); }
        if([DYYYChatEnhancementPolicy class:list selector:@selector(setChatList:) result:'v' arguments:@"@"]) { %init(DYYYMessageListDataHooks); }
    }
    Class light=NSClassFromString(@"AWEIMChatCellRecommendChatLIView");
    if([light isSubclassOfClass:UIView.class] && [DYYYChatEnhancementPolicy class:light selector:@selector(lightInteractionBtn) result:'@' arguments:@""]) { %init(DYYYMessageLightInteractionHooks); }
    Class tabs=NSClassFromString(@"AWEIMFansAndInteractMergeViewControllerNaviBar");
    if([tabs isSubclassOfClass:UIView.class] && [DYYYChatEnhancementPolicy class:tabs selector:@selector(setSelectedIndex:) result:'v' arguments:@"q"]) { %init(DYYYNoticeTabSelectionHooks); }
    if([cell isSubclassOfClass:UITableViewCell.class] && [DYYYChatEnhancementPolicy class:cell selector:@selector(renderWithHolder:) result:'v' arguments:@"@"]) {
        %init(DYYYMessageListCellHooks);
        if([DYYYChatEnhancementPolicy class:cell selector:@selector(onThemeDidChanged) result:'v' arguments:@""]) { %init(DYYYMessageListCellThemeHooks); }
    }
    Class bar=NSClassFromString(@"AWENavigationBar");
    if([bar isSubclassOfClass:UIView.class] && [DYYYChatEnhancementPolicy class:bar selector:@selector(rightBtnsContainerView) result:'@' arguments:@""]) {
        %init(DYYYMessageListBarHooks);
        if([DYYYChatEnhancementPolicy class:bar selector:@selector(addRightNaviBarBtnView:) result:'v' arguments:@"@"] &&
           [DYYYChatEnhancementPolicy class:bar selector:@selector(setRightBtnsContainerView:) result:'v' arguments:@"@"]) { %init(DYYYMessageListBarConfigurationHooks); }
    }
}
