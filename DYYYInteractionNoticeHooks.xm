#import "AwemeHeaders.h"
#import "DYYYInteractionNoticeStyle.h"
#import "DYYYChatEnhancementPolicy.h"
%group DYYYInteractionNoticeCellHooks
%hook DYYYNativeInteractionNoticeCell
- (void)layoutSubviews { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig; } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} [DYYYInteractionNoticeStyle synchronizeCell:self]; }
- (void)setFrame:(CGRect)frame { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(frame); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)setBounds:(CGRect)bounds { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(bounds); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)didMoveToWindow { %orig;if(((UIView *)self).window)[DYYYInteractionNoticeStyle synchronizeCell:self];else [DYYYInteractionNoticeStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];%orig; }
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
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];%orig; }
%end
%end
%group DYYYFansCollectionCellHooks
%hook DYYYNativeFansCollectionCell
- (void)layoutSubviews { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig; } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} [DYYYInteractionNoticeStyle synchronizeCell:self]; }
- (void)setFrame:(CGRect)frame { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(frame); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)setBounds:(CGRect)bounds { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(bounds); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)didMoveToWindow { %orig;if(((UIView *)self).window)[DYYYInteractionNoticeStyle synchronizeCell:self];else [DYYYInteractionNoticeStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];%orig; }
%end
%end
@implementation DYYYInteractionNoticeStyle (RuntimeHooks)
+ (void)installHooks {
    static BOOL installed,fansInstalled;if(installed && fansInstalled)return;
    @synchronized(self){
        if(installed && fansInstalled)return;
        Class cell=NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCell");
        if(!installed && [cell isSubclassOfClass:UICollectionViewCell.class]){ %init(DYYYInteractionNoticeCellHooks,DYYYNativeInteractionNoticeCell=cell);installed=YES; }
        Class fans=NSClassFromString(@"AWEIMFansContainerViewController");
        if(!fansInstalled && [fans isSubclassOfClass:UIViewController.class] && [DYYYChatEnhancementPolicy class:fans selector:@selector(viewDidLayoutSubviews) result:'v' arguments:@""] && [DYYYChatEnhancementPolicy class:fans selector:@selector(viewDidAppear:) result:'v' arguments:[NSString stringWithUTF8String:@encode(BOOL)]]){
            %init(DYYYFansControllerHooks);fansInstalled=YES;
        }
    }
}
+ (BOOL)installFansCellHooksForCell:(UIView *)cell {
    if(!NSThread.isMainThread)return NO;
    static Class tableClass,collectionClass;Class cls=cell.class;
    NSString *bundle=[NSBundle bundleForClass:cls].bundleIdentifier;
    NSString *name=NSStringFromClass(cls);
    if(!bundle || [bundle hasPrefix:@"com.apple."] || [name hasPrefix:@"DYYY"] || cls==UITableViewCell.class || cls==UICollectionViewCell.class)return NO;
    if([cell isKindOfClass:UITableViewCell.class]){
        if(!tableClass){%init(DYYYFansTableCellHooks,DYYYNativeFansTableCell=cls);tableClass=cls;}
        return cls==tableClass;
    }
    if([cell isKindOfClass:UICollectionViewCell.class]){
        if(!collectionClass){%init(DYYYFansCollectionCellHooks,DYYYNativeFansCollectionCell=cls);collectionClass=cls;}
        return cls==collectionClass;
    }
    return NO;
}
@end
%ctor { [DYYYInteractionNoticeStyle installHooks]; }
