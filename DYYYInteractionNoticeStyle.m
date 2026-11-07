#import "DYYYInteractionNoticeStyle.h"
#import "DYYYMessageListStyle.h"
#import "DYYYMessageListCardView.h"
#import "DYYYMessageListMetrics.h"
#import "DYYYMessageListUpdateState.h"
#import "DYYYUtils.h"
#import "DYYYChatEnhancementPolicy.h"
#import "AwemeHeaders.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char kDYYYFansCellBindingKey;
static NSUInteger DYYYFansBindingEvents;
static NSUInteger DYYYFansBeforeWindowApplications;
@interface DYYYFansCellBinding : NSObject
@property (nonatomic, weak) UITableView *table;
@property (nonatomic, weak) AWEIMFansNewViewController *controller;
@property (nonatomic, copy) NSIndexPath *path;
@end
@implementation DYYYFansCellBinding @end

@interface DYYYNoticeCardState : NSObject
@property (nonatomic, weak) UIView *cell;
@property (nonatomic, strong) DYYYMessageListCardView *background;
@property (nonatomic, strong) DYYYMessageListCardView *panel;
@property (nonatomic, strong) UIView *nativeBackground;
@property (nonatomic, strong) CALayer *divider;
@property (nonatomic) BOOL first;
@property (nonatomic) BOOL last;
@property (nonatomic, strong) CAShapeLayer *mask;
@property (nonatomic, strong) CALayer *nativeMask;
@property (nonatomic, strong) DYYYMessageListUpdateState *updates;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *lines;
@property (nonatomic, strong) NSMapTable<UIView *, id> *fills;
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
+ (DYYYNoticeCardState *)state:(UIView *)cell { return objc_getAssociatedObject(cell,@selector(synchronizeCell:)); }
+ (UIView *)contentForCell:(UIView *)cell {
    if([cell isKindOfClass:UITableViewCell.class])return ((UITableViewCell *)cell).contentView;
    if([cell isKindOfClass:UICollectionViewCell.class])return ((UICollectionViewCell *)cell).contentView;
    return nil;
}
+ (UIView *)backgroundForCell:(UIView *)cell {
    if([cell isKindOfClass:UITableViewCell.class])return ((UITableViewCell *)cell).backgroundView;
    if([cell isKindOfClass:UICollectionViewCell.class])return ((UICollectionViewCell *)cell).backgroundView;
    return nil;
}
+ (void)setBackground:(UIView *)background cell:(UIView *)cell {
    if([cell isKindOfClass:UITableViewCell.class])((UITableViewCell *)cell).backgroundView=background;
    else if([cell isKindOfClass:UICollectionViewCell.class])((UICollectionViewCell *)cell).backgroundView=background;
}
+ (UIView *)listForCell:(UIView *)cell {
    for(UIView *view=cell.superview;view;view=view.superview)if([view isKindOfClass:UITableView.class] || [view isKindOfClass:UICollectionView.class])return view;
    return nil;
}
+ (NSHashTable *)fansControllers {static NSHashTable *t;static dispatch_once_t once;dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];});return t;}
+ (DYYYFansCellBinding *)fansBinding:(UIView *)cell {
    DYYYFansCellBinding *binding=objc_getAssociatedObject(cell,&kDYYYFansCellBindingKey);
    if(![binding isKindOfClass:DYYYFansCellBinding.class] || !binding.controller.isViewLoaded || !binding.table || binding.controller.tableView!=binding.table)return nil;
    return binding;
}
+ (BOOL)isFansCell:(UIView *)cell {
    if(![cell isKindOfClass:NSClassFromString(@"AWEIMNewFansTableViewCell")])return NO;
    if([self fansBinding:cell])return YES;
    UIViewController *owner=[DYYYUtils firstAvailableViewControllerFromView:cell];
    return [owner isKindOfClass:NSClassFromString(@"AWEIMFansNewViewController")] && ((AWEIMFansNewViewController *)owner).tableView==[self listForCell:cell];
}
+ (void)clearFansBinding:(UIView *)cell {if(cell)objc_setAssociatedObject(cell,&kDYYYFansCellBindingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
+ (void)prepareFansCell:(UIView *)cell table:(UITableView *)table indexPath:(NSIndexPath *)path controller:(UIViewController *)controller {
    if(!NSThread.isMainThread || ![controller isKindOfClass:NSClassFromString(@"AWEIMFansNewViewController")] || ((AWEIMFansNewViewController *)controller).tableView!=table || ![cell isKindOfClass:NSClassFromString(@"AWEIMNewFansTableViewCell")] || ![path isKindOfClass:NSIndexPath.class])return;
    DYYYFansBindingEvents++;
    DYYYFansCellBinding *binding=[DYYYFansCellBinding new];binding.table=table;binding.controller=(id)controller;binding.path=path;
    objc_setAssociatedObject(cell,&kDYYYFansCellBindingKey,binding,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self installFansCellHooksForCell:cell];[self synchronizeCell:cell];
}
+ (void)synchronizeMergedController:(UIViewController *)controller {
    if(!NSThread.isMainThread || ![controller isKindOfClass:NSClassFromString(@"AWEIMFansAndInteractMergeViewController")] || !controller.isViewLoaded)return;
    if([DYYYChatEnhancementPolicy class:controller.class selector:@selector(fansViewController) result:'@' arguments:@""]){
        UIViewController *fans=((AWEIMFansAndInteractMergeViewController *)controller).fansViewController;
        if(fans.isViewLoaded)[self synchronizeFansController:fans];
    }
    for(UIView *view in controller.viewIfLoaded.subviews)if([view isKindOfClass:NSClassFromString(@"AWENavigationBar")]){[DYYYMessageListStyle synchronizeBar:view];[DYYYMessageListStyle scheduleBarSynchronization:view];}
}
+ (BOOL)inScope:(UIView *)cell {
    if([self isFansCell:cell])return YES;
    if(![cell isKindOfClass:NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCell")])return NO;
    UIViewController *controller=[DYYYUtils firstAvailableViewControllerFromView:cell];
    return [controller isKindOfClass:NSClassFromString(@"AWENoticeSwiftImpl.InteractionNoticeListContainerViewController")];
}
+ (void)synchronizeFansController:(UIViewController *)controller {
    if(!NSThread.isMainThread || (! [controller isKindOfClass:NSClassFromString(@"AWEIMFansContainerViewController")] && ![controller isKindOfClass:NSClassFromString(@"AWEIMFansNewViewController")]) || !controller.isViewLoaded || !controller.viewIfLoaded.window)return;
    [[self fansControllers] addObject:controller];
    if([controller isKindOfClass:NSClassFromString(@"AWEIMFansNewViewController")]){
        UITableView *table=((AWEIMFansNewViewController *)controller).tableView;
        for(UITableViewCell *cell in table.visibleCells){NSIndexPath *path=[table indexPathForCell:cell];if(path)[self prepareFansCell:cell table:table indexPath:path controller:controller];}
        return;
    }
    NSMutableArray *pending=[NSMutableArray arrayWithObject:controller.viewIfLoaded];NSUInteger visited=0;
    while(pending.count && visited++<128){
        UIView *view=pending.lastObject;[pending removeLastObject];
        if([view isKindOfClass:UITableView.class] || [view isKindOfClass:UICollectionView.class]){
            NSHashTable *root=[NSHashTable weakObjectsHashTable];[root addObject:controller];objc_setAssociatedObject(view,@selector(synchronizeFansController:),root,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSArray *visible=[view isKindOfClass:UITableView.class]?((UITableView *)view).visibleCells:((UICollectionView *)view).visibleCells;
            // 只从这个原生宿主实际显示的业务行绑定具体类，拒绝 UIKit 通用 Cell。
            NSCountedSet *classes=[NSCountedSet new];
            for(UIView *cell in visible)if(cell.bounds.size.height>=56 && cell.bounds.size.width>=160)[classes addObject:NSStringFromClass(cell.class)];
            NSString *chosen=nil;NSUInteger count=0;
            for(NSString *name in classes)if([classes countForObject:name]>count){chosen=name;count=[classes countForObject:name];}
            for(UIView *cell in visible)if([NSStringFromClass(cell.class) isEqual:chosen] && [self installFansCellHooksForCell:cell])[self synchronizeCell:cell];
            continue;
        }
        if(pending.count+view.subviews.count<=128)[pending addObjectsFromArray:view.subviews];
    }
}
+ (void)resetCell:(UIView *)cell {
    if(!NSThread.isMainThread)return;
    DYYYNoticeCardState *s=[self state:cell];if(!s || s.busy)return;s.busy=YES;[s.updates invalidate];
    UIView *content=[self contentForCell:cell];
    if(s.applied && CGAffineTransformEqualToTransform(content.transform,s.appliedTransform))[UIView performWithoutAnimation:^{content.transform=s.nativeTransform;}];
    if(content.layer.mask==s.mask)content.layer.mask=s.nativeMask;
    for(UIView *line in s.lines.keyEnumerator.allObjects)if(line.hidden)line.hidden=[[s.lines objectForKey:line] boolValue];
    if([self backgroundForCell:cell]==s.panel)[self setBackground:s.nativeBackground cell:cell];
    for(UIView *view in s.fills.keyEnumerator.allObjects)if(!view.backgroundColor || CGColorGetAlpha(view.backgroundColor.CGColor)==0){id saved=[s.fills objectForKey:view];view.backgroundColor=saved==NSNull.null?nil:saved;}
    [s.background removeFromSuperview];objc_setAssociatedObject(cell,@selector(synchronizeCell:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self cells] removeObject:cell];
}
+ (id)beginUpdate:(UIView *)cell {
    if(!NSThread.isMainThread)return nil;
    DYYYNoticeCardState *s=[self state:cell];if(!s || s.busy)return nil;
    BOOL outer=s.updates.depth==0;NSUInteger generation=[s.updates beginUpdate];
    if(outer && s.applied){
        s.busy=YES;
        if(CGAffineTransformEqualToTransform([self contentForCell:cell].transform,s.appliedTransform))[UIView performWithoutAnimation:^{[self contentForCell:cell].transform=s.nativeTransform;}];
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
+ (void)synchronizeCell:(UIView *)cell {
    if(!NSThread.isMainThread)return;
    DYYYNoticeCardState *s=[self state:cell];if(s.busy || s.updates.depth)return;
    if(![DYYYMessageListStyle cardsEnabled] || (!cell.window && ![self fansBinding:cell].table.window) || ![self inScope:cell]){[self resetCell:cell];return;}
    UIView *content=[self contentForCell:cell];
    if(content.bounds.size.width<160 || content.bounds.size.height<40)return;
    for(UIView *view in content.subviews)if([view isKindOfClass:NSClassFromString(@"AWENoticeSwiftBizUI.InteractionNoticeContainerCellEditContainerView")] && view.bounds.size.width>1 && view.frame.origin.x<content.bounds.size.width){[self resetCell:cell];return;}
    if(!s){
        if(content.layer.mask)return;
        s=[DYYYNoticeCardState new];s.cell=cell;s.nativeMask=content.layer.mask;s.mask=[CAShapeLayer layer];s.mask.fillColor=UIColor.blackColor.CGColor;s.updates=[DYYYMessageListUpdateState new];s.lines=[NSMapTable weakToStrongObjectsMapTable];s.fills=[NSMapTable weakToStrongObjectsMapTable];
        s.background=[[DYYYMessageListCardView alloc] initWithFrame:content.bounds];s.background.accessibilityIdentifier=@"DYads.InteractionNoticeSurface";
        s.panel=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];s.panel.accessibilityIdentifier=@"DYads.InteractionNoticeGroup";s.nativeBackground=[self backgroundForCell:cell];
        s.divider=[CALayer layer];[s.panel.layer addSublayer:s.divider];s.first=YES;s.last=YES;
        objc_setAssociatedObject(cell,@selector(synchronizeCell:),s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self cells] addObject:cell];
    }
    s.busy=YES;
    @try {
    DYYYFansCellBinding *binding=[self fansBinding:cell];UIView *list=[self listForCell:cell]?:binding.table;NSIndexPath *path=nil;NSInteger count=0;
    if([list isKindOfClass:UICollectionView.class]){
        UICollectionView *collection=(id)list;path=[collection indexPathForCell:(id)cell];
        if(path && path.section<collection.numberOfSections)count=[collection numberOfItemsInSection:path.section];
    }else if([list isKindOfClass:UITableView.class]){
        UITableView *table=(id)list;path=[table indexPathForCell:(id)cell]?:binding.path;
        if(path && path.section<table.numberOfSections)count=[table numberOfRowsInSection:path.section];
    }
    if(path && path.item<count){s.first=path.item==0;s.last=path.item+1==count;}
        if(!s.applied || !CGAffineTransformEqualToTransform(content.transform,s.appliedTransform))s.nativeTransform=content.transform;
        s.appliedTransform=CGAffineTransformScale(s.nativeTransform,0.92,0.92);
        [UIView performWithoutAnimation:^{if(!CGAffineTransformEqualToTransform(content.transform,s.appliedTransform))content.transform=s.appliedTransform;}];s.applied=YES;
        CGRect bounds=content.bounds;
        BOOL dark=[DYYYUtils isDarkMode] || cell.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark;
        UIColor *fill=dark?[UIColor colorWithWhite:0.125 alpha:1]:UIColor.secondarySystemGroupedBackgroundColor;
        s.background.fillColor=fill;s.panel.fillColor=fill;
        if([self isFansCell:cell]){
            NSMutableArray *surfaces=[NSMutableArray arrayWithObjects:cell,content,nil];
            for(UIView *view in content.subviews)if(view.class==UIView.class && CGRectContainsRect(CGRectInset(view.frame,1,1),CGRectInset(content.bounds,2,2)))[surfaces addObject:view];
            for(UIView *view in surfaces){
                UIColor *color=view.backgroundColor;CGFloat r=0,g=0,b=0,a=0;
                if([color getRed:&r green:&g blue:&b alpha:&a] && a>0 && fabs(r-g)<0.02 && fabs(g-b)<0.02){if(![s.fills objectForKey:view])[s.fills setObject:color forKey:view];view.backgroundColor=UIColor.clearColor;}
            }
        }
        NSMutableDictionary *segment=[[DYYYMessageListMetrics segmentForKind:@"regular" previous:s.first?nil:@"regular" next:s.last?nil:@"regular" width:cell.bounds.size.width height:cell.bounds.size.height] mutableCopy];
        if(!s.last)segment[@"height"]=@([segment[@"height"] doubleValue]+0.5);
        s.panel.segment=segment;
        if(!CGRectEqualToRect(s.panel.frame,cell.bounds))s.panel.frame=cell.bounds;
        if([self backgroundForCell:cell]!=s.panel){s.nativeBackground=[self backgroundForCell:cell];[self setBackground:s.panel cell:cell];}
        s.background.segment=@{@"x":@0,@"y":@0,@"width":@(bounds.size.width),@"height":@(bounds.size.height),@"radius":@0,@"first":@NO,@"last":@NO};
        if(!CGRectEqualToRect(s.background.frame,bounds))s.background.frame=bounds;
        if(s.background.superview!=content)[content insertSubview:s.background atIndex:0];
        // 关注行的原生细线直接挂在 contentView，不在内部 body 下；两层都要检查。
        NSMutableArray *lineCandidates=[NSMutableArray arrayWithArray:content.subviews.count<=64?content.subviews:@[]];
        for(UIView *body in content.subviews)if(body.class==UIView.class && body.subviews.count<=32 && lineCandidates.count+body.subviews.count<=128)[lineCandidates addObjectsFromArray:body.subviews];
        for(UIView *line in lineCandidates)if(line.class==UIView.class && !line.subviews.count && !line.layer.contents && line.bounds.size.height>=0.1 && line.bounds.size.height<=1 && line.bounds.size.width>bounds.size.width/2){
            CGRect frame=[line convertRect:line.bounds toView:content];
            if(CGRectGetMaxY(frame)<bounds.size.height-1)continue;
            if(![s.lines objectForKey:line])[s.lines setObject:@(line.hidden) forKey:line];
            if(!line.hidden)line.hidden=YES;
        }
        CGRect panelRect=CGRectMake([segment[@"x"] doubleValue],[segment[@"y"] doubleValue],[segment[@"width"] doubleValue],[segment[@"height"] doubleValue]);
        CGRect maskRect=[cell convertRect:panelRect toView:content];
        UIRectCorner corners=0;if(s.first)corners|=UIRectCornerTopLeft|UIRectCornerTopRight;if(s.last)corners|=UIRectCornerBottomLeft|UIRectCornerBottomRight;
        CGPathRef maskPath=[UIBezierPath bezierPathWithRoundedRect:maskRect byRoundingCorners:corners cornerRadii:CGSizeMake(14/0.92,14/0.92)].CGPath;
        [CATransaction begin];[CATransaction setDisableActions:YES];
        if(!CGRectEqualToRect(s.mask.frame,bounds))s.mask.frame=bounds;
        if(!s.mask.path || !CGPathEqualToPath(s.mask.path,maskPath))s.mask.path=maskPath;
        CGRect lineRect=CGRectMake(96,cell.bounds.size.height-0.5,MAX(0,cell.bounds.size.width-120),0.333);
        if(!CGRectEqualToRect(s.divider.frame,lineRect))s.divider.frame=lineRect;
        s.divider.backgroundColor=(dark?[UIColor colorWithWhite:1 alpha:0.045]:[UIColor colorWithWhite:0 alpha:0.045]).CGColor;s.divider.hidden=s.last;
        if(content.layer.mask!=s.mask)content.layer.mask=s.mask;[CATransaction commit];
        if(!cell.window && binding)DYYYFansBeforeWindowApplications++;
    } @finally {s.busy=NO;}
}
+ (void)refresh { if(!NSThread.isMainThread)return;for(UIViewController *controller in [self fansControllers].allObjects)[self synchronizeFansController:controller];for(UIView *cell in [self cells].allObjects)[self synchronizeCell:cell]; }
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};
    NSUInteger active=0,fans=0,nativeLines=0;
    for(UIView *cell in [self cells].allObjects)if(cell.window){DYYYNoticeCardState *s=[self state:cell];for(UIView *line in s.lines.keyEnumerator.allObjects)if(line.hidden)nativeLines++;if(s.applied && [self contentForCell:cell].layer.mask==s.mask && s.background.superview==[self contentForCell:cell] && [self backgroundForCell:cell]==s.panel && CGAffineTransformEqualToTransform([self contentForCell:cell].transform,s.appliedTransform)){active++;if([self isFansCell:cell])fans++;}}
    return @{@"enabled":@([DYYYMessageListStyle cardsEnabled]),@"roundedVisibleCells":@(active),@"followersVisibleCells":@(fans),@"hiddenNativeDividers":@(nativeLines),@"bindingEvents":@(DYYYFansBindingEvents),@"beforeWindowApplications":@(DYYYFansBeforeWindowApplications),@"hooks":[self hookDiagnostics],@"layout":@"section_groups"};
}
@end
