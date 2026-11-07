#import "AwemeHeaders.h"
#import "DYYYInteractionNoticeStyle.h"
%group DYYYInteractionNoticeCellHooks
%hook DYYYNativeInteractionNoticeCell
- (void)layoutSubviews { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig; } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} [DYYYInteractionNoticeStyle synchronizeCell:self]; }
- (void)setFrame:(CGRect)frame { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(frame); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)setBounds:(CGRect)bounds { id t=[DYYYInteractionNoticeStyle beginUpdate:self];@try { %orig(bounds); } @finally {[DYYYInteractionNoticeStyle endUpdate:t];} }
- (void)didMoveToWindow { %orig;if(self.window)[DYYYInteractionNoticeStyle synchronizeCell:self];else [DYYYInteractionNoticeStyle resetCell:self]; }
- (void)prepareForReuse { [DYYYInteractionNoticeStyle resetCell:self];%orig; }
%end
%end
@implementation DYYYInteractionNoticeStyle (RuntimeHooks)
+ (void)installHooks {
    static BOOL installed;if(installed)return;
    @synchronized(self){
        if(installed)return;
        Class cell=NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCell");
        if([cell isSubclassOfClass:UICollectionViewCell.class]){ %init(DYYYInteractionNoticeCellHooks,DYYYNativeInteractionNoticeCell=cell);installed=YES; }
    }
}
@end
%ctor { [DYYYInteractionNoticeStyle installHooks]; }
