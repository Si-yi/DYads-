#import "AwemeHeaders.h"
#import "DYYYMessageListStyle.h"
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
%group DYYYMessageListDataHooks
%hook AWEIMChatListViewController
- (void)setChatList:(NSArray *)chats { %orig(chats); [DYYYMessageListStyle synchronizeController:self]; }
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
- (void)setBackgroundColor:(UIColor *)color { %orig([DYYYMessageListStyle nativeBackgroundColor:color forBar:self]); }
- (void)setOpaque:(BOOL)opaque { %orig([DYYYMessageListStyle nativeOpaque:opaque forBar:self]); }
- (void)layoutSubviews { %orig; [DYYYMessageListStyle synchronizeBar:self]; [DYYYMessageListStyle scheduleBarSynchronization:self]; }
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
%ctor {
    [DYYYMessageListStyle preparePreferences];
    if([DYYYMessageListStyle contentAdapterReady]) { %init(DYYYMessageContentGeometryHooks); }
    Class list=NSClassFromString(@"AWEIMChatListViewController"),cell=NSClassFromString(@"AWEIMChatListCommonCell");
    if([list isSubclassOfClass:UIViewController.class] &&
        [DYYYChatEnhancementPolicy class:list selector:@selector(tableView) result:'@' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:list selector:@selector(chatList) result:'@' arguments:@""]) {
        %init(DYYYMessageListControllerHooks);
        if([DYYYChatEnhancementPolicy class:list selector:@selector(setChatList:) result:'v' arguments:@"@"]) { %init(DYYYMessageListDataHooks); }
    }
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
