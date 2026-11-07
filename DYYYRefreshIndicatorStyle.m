#import "DYYYRefreshIndicatorStyle.h"
#import "DYYYMessageListStyle.h"
#import "DYYYMessageListMetrics.h"
#import "DYYYChatEnhancementPolicy.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>

static char kDYYYRefreshIndicatorStateKey;
@interface DYYYRefreshIndicatorState : NSObject
@property (nonatomic, weak) UIView *loading;
@property (nonatomic, strong) CALayer *mask;
@property (nonatomic) BOOL suppressed;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYRefreshIndicatorState @end

@implementation DYYYRefreshIndicatorStyle
+ (NSHashTable *)headers {static NSHashTable *headers;static dispatch_once_t once;dispatch_once(&once,^{headers=[NSHashTable weakObjectsHashTable];});return headers;}
+ (DYYYRefreshIndicatorState *)state:(UIView *)header {id state=objc_getAssociatedObject(header,&kDYYYRefreshIndicatorStateKey);return [state isKindOfClass:DYYYRefreshIndicatorState.class]?state:nil;}
+ (UIScrollView *)scrollViewForHeader:(UIView *)header {
    if(![header isKindOfClass:NSClassFromString(@"AWERefreshHeader")])return nil;
    UIView *view=header.superview;
    if(![view isKindOfClass:UIScrollView.class] || ((AWERefreshHeader *)header).scrollView!=view)return nil;
    UIViewController *owner=[DYYYUtils firstAvailableViewControllerFromView:header];
    BOOL fans=[owner isKindOfClass:NSClassFromString(@"AWEIMFansNewViewController")] && ((AWEIMFansNewViewController *)owner).tableView==view;
    BOOL notices=[owner isKindOfClass:NSClassFromString(@"AWENoticeSwiftImpl.InteractionNoticeListContainerViewController")];
    if(!fans && !notices)return nil;
    for(NSUInteger i=0;owner && i<12;i++,owner=owner.parentViewController)if([owner isKindOfClass:NSClassFromString(@"AWEIMFansAndInteractMergeViewController")])return (id)view;
    return nil;
}
+ (void)restore:(UIView *)header {
    DYYYRefreshIndicatorState *state=[self state:header];if(!state || state.busy)return;state.busy=YES;
    if(state.loading.layer.mask==state.mask)state.loading.layer.mask=nil;
    state.suppressed=NO;state.busy=NO;objc_setAssociatedObject(header,&kDYYYRefreshIndicatorStateKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (void)synchronizeHeader:(UIView *)candidate {
    if(!NSThread.isMainThread)return;DYYYRefreshIndicatorState *state=[self state:candidate];if(state.busy)return;
    UIScrollView *scroll=[self scrollViewForHeader:candidate];
    if(scroll && candidate.window)[[self headers] addObject:candidate];
    if(!scroll || ![DYYYMessageListStyle topEnabled] || !candidate.window){[self restore:candidate];return;}
    AWERefreshHeader *header=(id)candidate;UIView *loading=header.loading;
    if(![loading isKindOfClass:NSClassFromString(@"AWEUILoadingView")] || ![loading isDescendantOfView:header] || !isfinite(scroll.contentOffset.y) || !isfinite(scroll.adjustedContentInset.top) || scroll.adjustedContentInset.top<0){[self restore:header];return;}
    BOOL show=[DYYYMessageListMetrics showRefreshIndicator:header.isRefreshing dragging:(scroll.dragging || scroll.tracking) offsetY:scroll.contentOffset.y insetTop:scroll.adjustedContentInset.top];
    if(state.loading!=loading){[self restore:header];state=nil;}
    if(show){[self restore:header];return;}
    CGRect bounds=loading.bounds;
    if(!isfinite(bounds.size.width) || !isfinite(bounds.size.height) || bounds.size.width<=0 || bounds.size.height<=0 || bounds.size.width>64 || bounds.size.height>64){[self restore:header];return;}
    if(!state){
        if(loading.layer.mask)return;
        state=[DYYYRefreshIndicatorState new];state.loading=loading;state.mask=[CALayer layer];state.mask.backgroundColor=UIColor.clearColor.CGColor;
        // 只遮住这一个32pt加载图，不改 refreshHeader.hidden/状态/回调，不能影响下拉触发。
        state.mask.frame=bounds;objc_setAssociatedObject(header,&kDYYYRefreshIndicatorStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    state.busy=YES;
    @try {
        if(loading.layer.mask && loading.layer.mask!=state.mask)return;
        [CATransaction begin];[CATransaction setDisableActions:YES];
        if(!CGRectEqualToRect(state.mask.frame,bounds))state.mask.frame=bounds;
        if(loading.layer.mask!=state.mask)loading.layer.mask=state.mask;
        [CATransaction commit];state.suppressed=loading.layer.mask==state.mask;
    } @finally {state.busy=NO;}
}
+ (void)refresh {if(NSThread.isMainThread)for(UIView *header in [self headers].allObjects)[self synchronizeHeader:header];}
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};NSMutableArray *rows=[NSMutableArray array];
    for(UIView *view in [self headers].allObjects)if(view.window){
        AWERefreshHeader *header=(id)view;UIScrollView *scroll=[self scrollViewForHeader:header];DYYYRefreshIndicatorState *state=[self state:header];if(!scroll)continue;
        [rows addObject:@{@"refreshing":@(header.isRefreshing),@"dragging":@(scroll.dragging || scroll.tracking),@"idleSuppressed":@(state.suppressed && state.loading.layer.mask==state.mask),@"offsetY":@(scroll.contentOffset.y),@"insetTop":@(scroll.adjustedContentInset.top)}];
        if(rows.count>=4)break;
    }return @{@"headers":rows};
}
@end
