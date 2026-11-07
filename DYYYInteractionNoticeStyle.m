#import "DYYYInteractionNoticeStyle.h"
#import "DYYYMessageListStyle.h"
#import "DYYYMessageListCardView.h"
#import "DYYYMessageListUpdateState.h"
#import "DYYYUtils.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface DYYYNoticeCardState : NSObject
@property (nonatomic, weak) UICollectionViewCell *cell;
@property (nonatomic, strong) DYYYMessageListCardView *background;
@property (nonatomic, strong) CAShapeLayer *mask;
@property (nonatomic, strong) CALayer *nativeMask;
@property (nonatomic, strong) DYYYMessageListUpdateState *updates;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *lines;
@property (nonatomic) CGAffineTransform nativeTransform;
@property (nonatomic) CGAffineTransform appliedTransform;
@property (nonatomic) BOOL applied;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYNoticeCardState @end
@interface DYYYNoticeUpdateToken : NSObject
@property (nonatomic, strong) DYYYNoticeCardState *state;
@property (nonatomic) NSUInteger generation;
@end
@implementation DYYYNoticeUpdateToken @end

@implementation DYYYInteractionNoticeStyle
+ (NSHashTable *)cells { static NSHashTable *t;static dispatch_once_t once;dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];});return t; }
+ (DYYYNoticeCardState *)state:(UICollectionViewCell *)cell { return objc_getAssociatedObject(cell,@selector(synchronizeCell:)); }
+ (BOOL)inScope:(UICollectionViewCell *)cell {
    if(![cell isKindOfClass:NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCell")])return NO;
    UIViewController *controller=[DYYYUtils firstAvailableViewControllerFromView:cell];
    return [controller isKindOfClass:NSClassFromString(@"AWENoticeSwiftImpl.InteractionNoticeListContainerViewController")];
}
+ (void)resetCell:(UICollectionViewCell *)cell {
    if(!NSThread.isMainThread)return;
    DYYYNoticeCardState *s=[self state:cell];if(!s || s.busy)return;s.busy=YES;[s.updates invalidate];
    UIView *content=cell.contentView;
    if(s.applied && CGAffineTransformEqualToTransform(content.transform,s.appliedTransform))[UIView performWithoutAnimation:^{content.transform=s.nativeTransform;}];
    if(content.layer.mask==s.mask)content.layer.mask=s.nativeMask;
    for(UIView *line in s.lines.keyEnumerator.allObjects)if(line.hidden)line.hidden=[[s.lines objectForKey:line] boolValue];
    [s.background removeFromSuperview];objc_setAssociatedObject(cell,@selector(synchronizeCell:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self cells] removeObject:cell];
}
+ (id)beginUpdate:(UICollectionViewCell *)cell {
    if(!NSThread.isMainThread)return nil;
    DYYYNoticeCardState *s=[self state:cell];if(!s || s.busy)return nil;
    BOOL outer=s.updates.depth==0;NSUInteger generation=[s.updates beginUpdate];
    if(outer && s.applied){
        s.busy=YES;
        if(CGAffineTransformEqualToTransform(cell.contentView.transform,s.appliedTransform))[UIView performWithoutAnimation:^{cell.contentView.transform=s.nativeTransform;}];
        s.busy=NO;s.applied=NO;
    }
    DYYYNoticeUpdateToken *token=[DYYYNoticeUpdateToken new];token.state=s;token.generation=generation;return token;
}
+ (void)endUpdate:(id)candidate {
    if(!NSThread.isMainThread || ![candidate isKindOfClass:DYYYNoticeUpdateToken.class])return;
    DYYYNoticeUpdateToken *token=candidate;DYYYNoticeCardState *s=token.state;
    if([self state:s.cell]!=s)return;
    if([s.updates endUpdate:token.generation])[self synchronizeCell:s.cell];
}
+ (void)synchronizeCell:(UICollectionViewCell *)cell {
    if(!NSThread.isMainThread)return;
    DYYYNoticeCardState *s=[self state:cell];if(s.busy || s.updates.depth)return;
    if(![DYYYMessageListStyle cardsEnabled] || !cell.window || ![self inScope:cell]){[self resetCell:cell];return;}
    UIView *content=cell.contentView;
    if(content.bounds.size.width<160 || content.bounds.size.height<40)return;
    for(UIView *view in content.subviews)if([view isKindOfClass:NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCellEditContainerView")] && view.bounds.size.width>1 && view.frame.origin.x<content.bounds.size.width){[self resetCell:cell];return;}
    if(!s){
        if(content.layer.mask)return;
        s=[DYYYNoticeCardState new];s.cell=cell;s.nativeMask=content.layer.mask;s.mask=[CAShapeLayer layer];s.mask.fillColor=UIColor.blackColor.CGColor;s.updates=[DYYYMessageListUpdateState new];s.lines=[NSMapTable weakToStrongObjectsMapTable];
        s.background=[[DYYYMessageListCardView alloc] initWithFrame:content.bounds];s.background.accessibilityIdentifier=@"DYads.InteractionNoticeCard";
        objc_setAssociatedObject(cell,@selector(synchronizeCell:),s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self cells] addObject:cell];
    }
    s.busy=YES;
    @try {
        if(!s.applied || !CGAffineTransformEqualToTransform(content.transform,s.appliedTransform))s.nativeTransform=content.transform;
        s.appliedTransform=CGAffineTransformScale(s.nativeTransform,0.92,0.92);
        [UIView performWithoutAnimation:^{if(!CGAffineTransformEqualToTransform(content.transform,s.appliedTransform))content.transform=s.appliedTransform;}];s.applied=YES;
        CGRect bounds=content.bounds;
        s.background.fillColor=([DYYYUtils isDarkMode] || cell.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark)?[UIColor colorWithWhite:0.14 alpha:1]:UIColor.secondarySystemGroupedBackgroundColor;
        s.background.segment=@{@"x":@0,@"y":@0,@"width":@(bounds.size.width),@"height":@(bounds.size.height),@"radius":@20,@"first":@YES,@"last":@YES};
        if(!CGRectEqualToRect(s.background.frame,bounds))s.background.frame=bounds;
        if(s.background.superview!=content)[content insertSubview:s.background atIndex:0];
        for(UIView *body in content.subviews)if(body.class==UIView.class && body.subviews.count<=32){
            for(UIView *line in body.subviews)if(line.class==UIView.class && !line.subviews.count && !line.layer.contents && line.bounds.size.height>0 && line.bounds.size.height<=1 && line.bounds.size.width>bounds.size.width/2 && CGRectGetMaxY(line.frame)>=bounds.size.height-1){
                if(![s.lines objectForKey:line])[s.lines setObject:@(line.hidden) forKey:line];
                if(!line.hidden)line.hidden=YES;
            }
        }
        CGPathRef path=[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:20].CGPath;
        [CATransaction begin];[CATransaction setDisableActions:YES];
        if(!CGRectEqualToRect(s.mask.frame,bounds))s.mask.frame=bounds;
        if(!s.mask.path || !CGPathEqualToPath(s.mask.path,path))s.mask.path=path;
        if(content.layer.mask!=s.mask)content.layer.mask=s.mask;[CATransaction commit];
    } @finally {s.busy=NO;}
}
+ (void)refresh { if(NSThread.isMainThread)for(UICollectionViewCell *cell in [self cells].allObjects)[self synchronizeCell:cell]; }
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};
    NSUInteger active=0;
    for(UICollectionViewCell *cell in [self cells].allObjects)if(cell.window){DYYYNoticeCardState *s=[self state:cell];if(s.applied && CGAffineTransformEqualToTransform(cell.contentView.transform,s.appliedTransform))active++;}
    return @{@"enabled":@([DYYYMessageListStyle cardsEnabled]),@"roundedVisibleCells":@(active)};
}
@end
