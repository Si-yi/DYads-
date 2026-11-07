#import "AwemeHeaders.h"
#import "DYYYInteractionNoticeStyle.h"
#import "DYYYChatEnhancementPolicy.h"
static Class DYYYFansTableHookClass;
static Class DYYYFansCollectionHookClass;
static BOOL DYYYNoticeHooksInstalled,DYYYFansContainerHooksInstalled,DYYYFansListHooksInstalled,DYYYFansDisplayHooksInstalled,DYYYFansMergeHooksInstalled,DYYYFansSelectionHooksInstalled;
%group DYYYInteractionNoticeCellHooks
%hook DYYYNativeInteractionNoticeCell
- (void)layoutSubviews { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig; } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} [DYYYInteractionNoticeStyle synchronizeCell:self]; }
- (void)setFrame:(CGRect)frame { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(frame); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)setBounds:(CGRect)bounds { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(bounds); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)didMoveToWindow { %orig;if(((UIView *)self).window)[DYYYInteractionNoticeStyle synchronizeCell:self];else [DYYYInteractionNoticeStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];[DYYYInteractionNoticeStyle clearFansBinding:(UIView *)self];%orig; }
%end
%end
%group DYYYFansControllerHooks
%hook AWEIMFansContainerViewController
- (void)viewDidLayoutSubviews { %orig;[DYYYInteractionNoticeStyle synchronizeFansController:(UIViewController *)self]; }
- (void)viewDidAppear:(BOOL)animated { %orig(animated);[DYYYInteractionNoticeStyle synchronizeFansController:(UIViewController *)self]; }
%end
%end
%group DYYYFansTableCellHooks
%hook DYYYNativeFansTableCell
- (void)layoutSubviews { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig; } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} [DYYYInteractionNoticeStyle synchronizeCell:self]; }
- (void)setFrame:(CGRect)frame { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(frame); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)setBounds:(CGRect)bounds { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(bounds); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)didMoveToWindow { %orig;if(((UIView *)self).window)[DYYYInteractionNoticeStyle synchronizeCell:self];else [DYYYInteractionNoticeStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];[DYYYInteractionNoticeStyle clearFansBinding:(UIView *)self];%orig; }
%end
%end
%group DYYYFansCollectionCellHooks
%hook DYYYNativeFansCollectionCell
- (void)layoutSubviews { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig; } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} [DYYYInteractionNoticeStyle synchronizeCell:self]; }
- (void)setFrame:(CGRect)frame { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(frame); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)setBounds:(CGRect)bounds { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(bounds); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)didMoveToWindow { %orig;if(((UIView *)self).window)[DYYYInteractionNoticeStyle synchronizeCell:self];else [DYYYInteractionNoticeStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];[DYYYInteractionNoticeStyle clearFansBinding:(UIView *)self];%orig; }
%end
%end
%group DYYYFansListLifecycleHooks
%hook AWEIMFansNewViewController
- (void)viewDidLoad { %orig;[DYYYInteractionNoticeStyle installHooks];[DYYYInteractionNoticeStyle synchronizeFansController:(UIViewController *)self]; }
- (void)viewWillAppear:(BOOL)animated { %orig(animated);[DYYYInteractionNoticeStyle synchronizeFansController:(UIViewController *)self]; }
- (void)viewDidAppear:(BOOL)animated { %orig(animated);[DYYYInteractionNoticeStyle synchronizeFansController:(UIViewController *)self]; }
- (void)viewDidLayoutSubviews { %orig;[DYYYInteractionNoticeStyle synchronizeFansController:(UIViewController *)self]; }
%end
%end
%group DYYYFansWillDisplayHooks
%hook AWEIMFansNewViewController
- (void)tableView:(UITableView *)table willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {
    %orig(table,cell,path);[DYYYInteractionNoticeStyle prepareFansCell:cell table:table indexPath:path controller:(UIViewController *)self];
}
%end
%end
%group DYYYFansMergedLifecycleHooks
%hook AWEIMFansAndInteractMergeViewController
- (void)viewDidAppear:(BOOL)animated { %orig(animated);[DYYYInteractionNoticeStyle synchronizeMergedController:(UIViewController *)self]; }
%end
%end
%group DYYYFansMergedSelectionHooks
%hook AWEIMFansAndInteractMergeViewController
- (void)setCurrentSelectedIndex:(long long)index { %orig(index);[DYYYInteractionNoticeStyle synchronizeMergedController:(UIViewController *)self]; }
- (void)slidingViewController:(id)controller didSelectIndex:(long long)index transitionType:(long long)type { %orig(controller,index,type);[DYYYInteractionNoticeStyle synchronizeMergedController:(UIViewController *)self]; }
%end
%end
@implementation DYYYInteractionNoticeStyle (RuntimeHooks)
+ (void)installHooks {
    @synchronized(self){
        if(DYYYNoticeHooksInstalled && DYYYFansContainerHooksInstalled && DYYYFansListHooksInstalled && DYYYFansDisplayHooksInstalled && DYYYFansMergeHooksInstalled && DYYYFansSelectionHooksInstalled && DYYYFansTableHookClass)return;
        Class notice=NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCell");
        if(!DYYYNoticeHooksInstalled && [notice isSubclassOfClass:UICollectionViewCell.class]){ %init(DYYYInteractionNoticeCellHooks,DYYYNativeInteractionNoticeCell=notice);DYYYNoticeHooksInstalled=YES; }
        // 已由两份调试包确认具体关注行，不再等容器先扫描出可见 Cell 才安装。
        [self installFansCellHooksForClass:NSClassFromString(@"AWEIMNewFansTableViewCell")];
        Class fans=NSClassFromString(@"AWEIMFansContainerViewController");
        if(!DYYYFansContainerHooksInstalled && [fans isSubclassOfClass:UIViewController.class] && [DYYYChatEnhancementPolicy class:fans selector:@selector(viewDidLayoutSubviews) result:'v' arguments:@""] && [DYYYChatEnhancementPolicy class:fans selector:@selector(viewDidAppear:) result:'v' arguments:@"B"]){
            %init(DYYYFansControllerHooks);DYYYFansContainerHooksInstalled=YES;
        }
        Class list=NSClassFromString(@"AWEIMFansNewViewController");
        if([list isSubclassOfClass:UIViewController.class] && [DYYYChatEnhancementPolicy class:list selector:@selector(tableView) result:'@' arguments:@""]){
            if(!DYYYFansListHooksInstalled && [DYYYChatEnhancementPolicy class:list selector:@selector(viewWillAppear:) result:'v' arguments:@"B"] && [DYYYChatEnhancementPolicy class:list selector:@selector(viewDidAppear:) result:'v' arguments:@"B"]){%init(DYYYFansListLifecycleHooks);DYYYFansListHooksInstalled=YES;}
            if(!DYYYFansDisplayHooksInstalled && [DYYYChatEnhancementPolicy class:list selector:@selector(tableView:willDisplayCell:forRowAtIndexPath:) result:'v' arguments:@"@@@"]){%init(DYYYFansWillDisplayHooks);DYYYFansDisplayHooksInstalled=YES;}
        }
        Class merge=NSClassFromString(@"AWEIMFansAndInteractMergeViewController");
        if([merge isSubclassOfClass:UIViewController.class] && [DYYYChatEnhancementPolicy class:merge selector:@selector(fansViewController) result:'@' arguments:@""]){
            if(!DYYYFansMergeHooksInstalled && [DYYYChatEnhancementPolicy class:merge selector:@selector(viewDidAppear:) result:'v' arguments:@"B"]){%init(DYYYFansMergedLifecycleHooks);DYYYFansMergeHooksInstalled=YES;}
            if(!DYYYFansSelectionHooksInstalled && [DYYYChatEnhancementPolicy class:merge selector:@selector(setCurrentSelectedIndex:) result:'v' arguments:@"q"] && [DYYYChatEnhancementPolicy class:merge selector:@selector(slidingViewController:didSelectIndex:transitionType:) result:'v' arguments:@"@qq"]){%init(DYYYFansMergedSelectionHooks);DYYYFansSelectionHooksInstalled=YES;}
        }
    }
}
+ (BOOL)installFansCellHooksForClass:(Class)cls {
    if(!cls)return NO;
    NSString *bundle=[NSBundle bundleForClass:cls].bundleIdentifier,*name=NSStringFromClass(cls);
    BOOL known=cls==NSClassFromString(@"AWEIMNewFansTableViewCell");
    if((!known && (!bundle || [bundle hasPrefix:@"com.apple."])) || [name hasPrefix:@"DYYY"] || cls==UITableViewCell.class || cls==UICollectionViewCell.class)return NO;
    if([cls isSubclassOfClass:UITableViewCell.class]){
        if(!DYYYFansTableHookClass){%init(DYYYFansTableCellHooks,DYYYNativeFansTableCell=cls);DYYYFansTableHookClass=cls;}
        return cls==DYYYFansTableHookClass;
    }
    if([cls isSubclassOfClass:UICollectionViewCell.class]){
        if(!DYYYFansCollectionHookClass){%init(DYYYFansCollectionCellHooks,DYYYNativeFansCollectionCell=cls);DYYYFansCollectionHookClass=cls;}
        return cls==DYYYFansCollectionHookClass;
    }return NO;
}
+ (BOOL)installFansCellHooksForCell:(UIView *)cell {return NSThread.isMainThread && [self installFansCellHooksForClass:cell.class];}
+ (NSDictionary *)hookDiagnostics {
    return @{@"noticeCell":@(DYYYNoticeHooksInstalled),@"fansContainer":@(DYYYFansContainerHooksInstalled),@"fansList":@(DYYYFansListHooksInstalled),@"fansWillDisplay":@(DYYYFansDisplayHooksInstalled),@"fansCell":@(DYYYFansTableHookClass!=Nil),@"mergedAppearance":@(DYYYFansMergeHooksInstalled),@"mergedSelection":@(DYYYFansSelectionHooksInstalled)};
}
@end
%ctor { [DYYYInteractionNoticeStyle installHooks]; }
