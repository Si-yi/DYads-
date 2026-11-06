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
- (void)renderWithHolder:(id)holder { [DYYYMessageListStyle resetCell:self]; %orig(holder); [DYYYMessageListStyle synchronizeCell:self]; }
%end
%end
%group DYYYMessageListCellPaintHooks
%hook AWEIMChatListCommonCell
- (UIColor *)chatBackgroundColor {
    UIColor *native=%orig;
    return [DYYYMessageListStyle usesCardsForCell:self] ? UIColor.clearColor : native;
}
%end
%end
%group DYYYMessageListBarHooks
%hook AWENavigationBar
- (void)layoutSubviews { %orig; [DYYYMessageListStyle synchronizeBar:self]; }
- (void)didMoveToWindow { %orig; [DYYYMessageListStyle synchronizeBar:self]; }
%end
%end
%ctor {
    [DYYYMessageListStyle preparePreferences];
    Class list=NSClassFromString(@"AWEIMChatListViewController"),cell=NSClassFromString(@"AWEIMChatListCommonCell");
    if([list isSubclassOfClass:UIViewController.class] &&
        [DYYYChatEnhancementPolicy class:list selector:@selector(tableView) result:'@' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:list selector:@selector(chatList) result:'@' arguments:@""]) {
        %init(DYYYMessageListControllerHooks);
        if([DYYYChatEnhancementPolicy class:list selector:@selector(setChatList:) result:'v' arguments:@"@"]) { %init(DYYYMessageListDataHooks); }
    }
    if([cell isSubclassOfClass:UITableViewCell.class] && [DYYYChatEnhancementPolicy class:cell selector:@selector(renderWithHolder:) result:'v' arguments:@"@"]) {
        %init(DYYYMessageListCellHooks);
        if([DYYYChatEnhancementPolicy class:cell selector:@selector(chatBackgroundColor) result:'@' arguments:@""]) { %init(DYYYMessageListCellPaintHooks); }
    }
    if([NSClassFromString(@"AWENavigationBar") isSubclassOfClass:UIView.class]) { %init(DYYYMessageListBarHooks); }
}
