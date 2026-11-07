#import "DYYYMessageListViewport.h"
#import "DYYYMessageListStyle.h"
#import "DYYYMessageListMetrics.h"
#import "AwemeHeaders.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface DYYYMessageViewportState : NSObject
@property (nonatomic, weak) UITableView *table;
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, strong) NSMapTable<UIView *, CAShapeLayer *> *clips;
@property (nonatomic) CGRect nativeFrame;
@property (nonatomic) CGRect appliedFrame;
@property (nonatomic) CGRect rootBounds;
@property (nonatomic) UIEdgeInsets nativeInset;
@property (nonatomic) UIEdgeInsets nativeIndicator;
@property (nonatomic) CGFloat top;
@property (nonatomic) UIScrollViewContentInsetAdjustmentBehavior nativeAdjustment;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYMessageViewportState @end

@implementation DYYYMessageListViewport
+ (BOOL)adapterReady {
    Class cls=NSClassFromString(@"AWEIMChatTabTableView");if(![cls isSubclassOfClass:UITableView.class])return NO;
    NSArray *names=@[@"setFrame:",@"setContentInset:",@"setVerticalScrollIndicatorInsets:",@"setContentInsetAdjustmentBehavior:"];
    const char *types[]={@encode(CGRect),@encode(UIEdgeInsets),@encode(UIEdgeInsets),@encode(UIScrollViewContentInsetAdjustmentBehavior)};
    for(NSUInteger i=0;i<names.count;i++){
        Method method=class_getInstanceMethod(cls,NSSelectorFromString(names[i]));if(!method)return NO;
        NSMethodSignature *signature=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        if(signature.numberOfArguments!=3 || strcmp(signature.methodReturnType,@encode(void)) || strcmp([signature getArgumentTypeAtIndex:2],types[i]))return NO;
    }return YES;
}
+ (NSHashTable *)states {static NSHashTable *t;static dispatch_once_t once;dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];});return t;}
+ (DYYYMessageViewportState *)state:(UITableView *)table {return objc_getAssociatedObject(table,@selector(synchronizeController:));}
+ (void)restore:(DYYYMessageViewportState *)s {
    if(!s || s.busy || s.top<=0)return;s.busy=YES;
    UITableView *table=s.table;CGFloat top=s.top;s.top=0;CGPoint offset=table.contentOffset;
    BOOL ownFrame=CGRectEqualToRect(table.frame,s.appliedFrame);
    if(ownFrame){table.frame=s.nativeFrame;offset.y+=top;}
    UIEdgeInsets inset=table.contentInset;
    if(fabs(inset.top-(s.nativeInset.top+top))<0.5){inset.top=s.nativeInset.top;table.contentInset=inset;}
    UIEdgeInsets indicator=table.verticalScrollIndicatorInsets;
    if(fabs(indicator.top-(s.nativeIndicator.top+top))<0.5){indicator.top=s.nativeIndicator.top;table.verticalScrollIndicatorInsets=indicator;}
    for(UIView *view in s.clips.keyEnumerator.allObjects)if(view.layer.mask==[s.clips objectForKey:view]){view.layer.mask=nil;if(!view.clipsToBounds)view.clipsToBounds=YES;}
    if(table.contentInsetAdjustmentBehavior==UIScrollViewContentInsetAdjustmentNever)table.contentInsetAdjustmentBehavior=s.nativeAdjustment;
    [s.clips removeAllObjects];if(ownFrame && !CGPointEqualToPoint(table.contentOffset,offset))table.contentOffset=offset;
    s.busy=NO;
}
+ (UIViewController *)host:(UIViewController *)controller {
    for(NSUInteger i=0;controller && i<12;i++,controller=controller.parentViewController)if([controller isKindOfClass:NSClassFromString(@"AWEIMMessageTabViewController")])return controller;
    return nil;
}
+ (UIView *)bar:(UIView *)root {
    NSMutableArray *pending=[NSMutableArray arrayWithObject:root];NSUInteger visited=0;
    while(pending.count && visited++<64){UIView *view=pending.lastObject;[pending removeLastObject];
        if([view isKindOfClass:NSClassFromString(@"AWENavigationBar")])return view;
        if([view isKindOfClass:UIScrollView.class])continue;
        if(pending.count+view.subviews.count<=64)[pending addObjectsFromArray:view.subviews];
    }return nil;
}
+ (void)updateClips:(DYYYMessageViewportState *)s {
    for(UIView *view in s.clips.keyEnumerator.allObjects){
        CAShapeLayer *mask=[s.clips objectForKey:view];if(view.layer.mask!=mask)continue;
        CGRect rect=CGRectMake(view.bounds.origin.x,view.bounds.origin.y-s.top,view.bounds.size.width,view.bounds.size.height+s.top);
        CGPathRef path=[UIBezierPath bezierPathWithRect:rect].CGPath;
        [CATransaction begin];[CATransaction setDisableActions:YES];
        if(!CGRectEqualToRect(mask.frame,view.bounds))mask.frame=view.bounds;
        if(!mask.path || !CGPathEqualToPath(mask.path,path))mask.path=path;
        if(view.clipsToBounds)view.clipsToBounds=NO;[CATransaction commit];
    }
}
+ (void)synchronizeController:(UIViewController *)controller {
    if(!NSThread.isMainThread || ![controller isKindOfClass:NSClassFromString(@"AWEIMChatListViewController")] || !controller.isViewLoaded)return;
    UITableView *table=((AWEIMChatListViewController *)controller).tableView;
    if(![table isKindOfClass:NSClassFromString(@"AWEIMChatTabTableView")] || ![self adapterReady])return;
    DYYYMessageViewportState *s=[self state:table];if(s.busy)return;
    UIViewController *host=[self host:controller];UIView *root=host.viewIfLoaded;
    if(![DYYYMessageListStyle topEnabled] || !table.window || !root.window){[self restore:s];return;}
    if(table.dragging || table.decelerating || table.hasUncommittedUpdates)return;
    UIView *bar=[self bar:root];if(!bar || bar.hidden || ![table isDescendantOfView:root]){[self restore:s];return;}
    CGFloat headerBottom=CGRectGetMaxY([bar convertRect:bar.bounds toView:root]);
    if(s.top>0 && CGRectEqualToRect(table.frame,s.appliedFrame) && CGRectEqualToRect(root.bounds,s.rootBounds) && fabs(headerBottom-s.top)<0.5){[self updateClips:s];return;}
    [self restore:s];
    CGRect native=table.frame,global=[table convertRect:table.bounds toView:root];
    // scrollView.bounds.origin 是滚动偏移；用 frame 原点避免把阅读位置误当列表起点。
    CGPoint origin=[table.superview convertPoint:native.origin toView:root];
    NSDictionary *plan=[DYYYMessageListMetrics viewportForListTop:origin.y headerBottom:headerBottom tableY:native.origin.y width:native.size.width height:native.size.height rootHeight:root.bounds.size.height];
    if(!plan.count || fabs(global.size.width-root.bounds.size.width)>1 || !CGAffineTransformIsIdentity(table.transform))return;
    // 原始导出 adjusted/contentInset 相同。未知安全区补偿不接管，避免顶部被系统再加一遍。
    if(!UIEdgeInsetsEqualToEdgeInsets(table.adjustedContentInset,table.contentInset))return;
    NSMutableArray *ancestors=[NSMutableArray array];UIView *view=table.superview;NSUInteger depth=0;
    for(;view && view!=root && depth++<10;view=view.superview){
        if(view.layer.mask || !CGAffineTransformIsIdentity(view.transform) || fabs(view.bounds.size.width-root.bounds.size.width)>1)return;
        if(view.clipsToBounds)[ancestors addObject:view];
    }
    if(view!=root)return;
    if(!s){s=[DYYYMessageViewportState new];s.table=table;s.controller=controller;s.clips=[NSMapTable weakToStrongObjectsMapTable];objc_setAssociatedObject(table,@selector(synchronizeController:),s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self states] addObject:s];}
    s.busy=YES;
    @try {
        CGFloat top=[plan[@"extension"] doubleValue];CGPoint offset=table.contentOffset;
        s.nativeFrame=native;s.appliedFrame=CGRectMake(native.origin.x,native.origin.y-top,native.size.width,native.size.height+top);s.nativeInset=table.contentInset;s.nativeIndicator=table.verticalScrollIndicatorInsets;s.nativeAdjustment=table.contentInsetAdjustmentBehavior;s.rootBounds=root.bounds;s.top=top;
        for(UIView *ancestor in ancestors){CAShapeLayer *mask=[CAShapeLayer layer];mask.fillColor=UIColor.blackColor.CGColor;[s.clips setObject:mask forKey:ancestor];ancestor.layer.mask=mask;}
        [self updateClips:s];
        UIEdgeInsets inset=s.nativeInset;inset.top+=top;UIEdgeInsets indicator=s.nativeIndicator;indicator.top+=top;offset.y-=top;
        [UIView performWithoutAnimation:^{table.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;table.frame=s.appliedFrame;table.contentInset=inset;table.verticalScrollIndicatorInsets=indicator;if(!CGPointEqualToPoint(table.contentOffset,offset))table.contentOffset=offset;}];
    } @finally {s.busy=NO;}
}
+ (CGRect)nativeFrame:(CGRect)frame table:(UITableView *)table {
    if(!NSThread.isMainThread)return frame;DYYYMessageViewportState *s=[self state:table];if(!s || s.busy || s.top<=0)return frame;
    NSDictionary *request=@{@"x":@(frame.origin.x),@"y":@(frame.origin.y),@"width":@(frame.size.width),@"height":@(frame.size.height)};
    NSDictionary *native=@{@"x":@(s.nativeFrame.origin.x),@"y":@(s.nativeFrame.origin.y),@"width":@(s.nativeFrame.size.width),@"height":@(s.nativeFrame.size.height)};
    NSDictionary *displayed=@{@"x":@(s.appliedFrame.origin.x),@"y":@(s.appliedFrame.origin.y),@"width":@(s.appliedFrame.size.width),@"height":@(s.appliedFrame.size.height)};
    NSDictionary *base=[DYYYMessageListMetrics nativeFrameForRequest:request previousNative:native previousDisplayed:displayed];
    s.nativeFrame=CGRectMake([base[@"x"] doubleValue],[base[@"y"] doubleValue],[base[@"width"] doubleValue],[base[@"height"] doubleValue]);
    s.appliedFrame=CGRectMake(s.nativeFrame.origin.x,s.nativeFrame.origin.y-s.top,s.nativeFrame.size.width,s.nativeFrame.size.height+s.top);return s.appliedFrame;
}
+ (UIEdgeInsets)nativeInset:(UIEdgeInsets)inset table:(UITableView *)table indicator:(BOOL)indicator {
    if(!NSThread.isMainThread)return inset;DYYYMessageViewportState *s=[self state:table];if(!s || s.busy || s.top<=0)return inset;
    UIEdgeInsets native=indicator?s.nativeIndicator:s.nativeInset;
    if(fabs(inset.top-(native.top+s.top))<0.5)inset.top=native.top;
    if(indicator)s.nativeIndicator=inset;else s.nativeInset=inset;inset.top+=s.top;return inset;
}
+ (UIScrollViewContentInsetAdjustmentBehavior)nativeAdjustment:(UIScrollViewContentInsetAdjustmentBehavior)behavior table:(UITableView *)table {
    if(!NSThread.isMainThread)return behavior;DYYYMessageViewportState *s=[self state:table];if(!s || s.busy || s.top<=0)return behavior;
    s.nativeAdjustment=behavior;return UIScrollViewContentInsetAdjustmentNever;
}
+ (void)detachTable:(UITableView *)table {if(NSThread.isMainThread)[self restore:[self state:table]];}
+ (void)refresh {if(NSThread.isMainThread)for(DYYYMessageViewportState *s in [self states].allObjects)[self synchronizeController:s.controller];}
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};NSMutableArray *result=[NSMutableArray array];
    for(DYYYMessageViewportState *s in [self states].allObjects)if(s.table.window){
        NSUInteger activeClips=0;for(UIView *view in s.clips.keyEnumerator.allObjects)if(view.layer.mask==[s.clips objectForKey:view] && !view.clipsToBounds)activeClips++;
        [result addObject:@{@"topExtension":@(s.top),@"frame":NSStringFromCGRect(s.table.frame),@"nativeFrame":NSStringFromCGRect(s.nativeFrame),@"frameMatches":@(CGRectEqualToRect(s.table.frame,s.appliedFrame)),@"clipCount":@(activeClips)}];
    }
    return @{@"visible":result};
}
@end
