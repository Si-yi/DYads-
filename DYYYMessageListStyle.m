#import "DYYYMessageListStyle.h"
#import "DYYYMessageListCardView.h"
#import "DYYYMessageListMetrics.h"
#import "DYYYMessageListUpdateState.h"
#import "DYYYInteractionNoticeStyle.h"
#include <string.h>
#include <math.h>
#import "DYYYChatChrome.h"
#import "DYYYChatEnhancementPolicy.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface DYYYMessageCardState : NSObject
@property (nonatomic, strong) UIView *nativeBackground;
@property (nonatomic, strong) UIView *nativeSelected;
@property (nonatomic, strong) DYYYMessageListCardView *background;
@property (nonatomic, strong) DYYYMessageListCardView *selected;
@property (nonatomic, strong) NSMapTable<UIView *, id> *fills;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *masks;
@property (nonatomic, weak) UIView *line;
@property (nonatomic) BOOL lineHidden;
@property (nonatomic) BOOL busy;
@property (nonatomic, copy) NSString *kind;
@end
@implementation DYYYMessageCardState @end

@interface DYYYMessageContentState : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) UITableViewCell *cell;
@property (nonatomic, strong) DYYYMessageListUpdateState *updates;
@property (nonatomic) CGAffineTransform nativeTransform;
@property (nonatomic) CGAffineTransform appliedTransform;
@property (nonatomic) CGRect nativeFrame;
@property (nonatomic) CGRect displayedFrame;
@property (nonatomic) CGFloat scale;
@property (nonatomic) CGFloat topPadding;
@property (nonatomic) CGFloat bottomPadding;
@property (nonatomic) CGFloat verticalShift;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL applied;
@property (nonatomic) BOOL busy;
@property (nonatomic, copy) NSString *decision;
@end
@implementation DYYYMessageContentState @end
@interface DYYYMessageContentToken : NSObject
@property (nonatomic, strong) DYYYMessageContentState *state;
@property (nonatomic, weak) UIView *view;
@property (nonatomic) NSUInteger generation;
@end
@implementation DYYYMessageContentToken @end


@interface DYYYMessageLightState : NSObject
@property (nonatomic, weak) UIButton *button;
@property (nonatomic, strong) CALayer *nativeMask;
@property (nonatomic, strong) CAShapeLayer *mask;
@property (nonatomic) UIEdgeInsets nativeInsets;
@property (nonatomic) UIEdgeInsets appliedInsets;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYMessageLightState @end

@interface DYYYMessageHeaderState : NSObject
@property (nonatomic, strong) UIVisualEffectView *left;
@property (nonatomic, strong) UIVisualEffectView *right;
@property (nonatomic, strong) NSMapTable<UIView *, id> *fills;
@property (nonatomic, weak) UIView *line;
@property (nonatomic) BOOL notice;
@property (nonatomic, weak) UIView *leftAnchor;
@property (nonatomic, weak) UIView *rightAnchor;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *constraints;
@property (nonatomic) BOOL lineHidden;
@property (nonatomic) BOOL nativeOpaque;
@property (nonatomic) BOOL pending;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYMessageHeaderState @end

@implementation DYYYMessageListStyle
+ (NSHashTable *)controllers { static NSHashTable *t; static dispatch_once_t once; dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];}); return t; }
+ (NSHashTable *)cells { static NSHashTable *t; static dispatch_once_t once; dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];}); return t; }
+ (NSHashTable *)bars { static NSHashTable *t; static dispatch_once_t once; dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];}); return t; }
+ (void)preparePreferences {
    [DYYYChatChrome preparePreferences];
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"DYYYEnableMessageListCards":@YES,@"DYYYEnableMessageListTopGlass":@([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableChatTopGlass"])}];
}
+ (BOOL)cardsEnabled { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableMessageListCards"]; }
+ (BOOL)topEnabled { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableMessageListTopGlass"]; }
+ (BOOL)adapterReady {
    static BOOL ready;
    if(ready)return YES;
    Class cell=NSClassFromString(@"AWEIMChatListCommonCell"),vm=NSClassFromString(@"AWEIMChatCellViewModel"),chat=NSClassFromString(@"AWEIMChatModel");
    ready = [DYYYChatEnhancementPolicy class:cell selector:@selector(cellViewModel) result:'@' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:vm selector:@selector(chat) result:'@' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:chat selector:@selector(stickOnTop) result:'B' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:chat selector:@selector(name) result:'@' arguments:@""] &&
        [DYYYChatEnhancementPolicy class:object_getClass(chat) selector:@selector(isNoticeChat:) result:'B' arguments:@"@"];
    return ready;
}
+ (UIViewController *)owner:(UIView *)view named:(NSString *)name {
    UIViewController *controller=[DYYYUtils firstAvailableViewControllerFromView:view];
    Class cls=NSClassFromString(name);
    for(NSUInteger i=0;controller && i<12;i++,controller=controller.parentViewController)
        if(cls && [controller isKindOfClass:cls])return controller;
    return nil;
}
+ (NSString *)kindForChat:(AWEIMChatModel *)chat {
    if(![chat isKindOfClass:NSClassFromString(@"AWEIMChatModel")])return nil;
    BOOL notice=[NSClassFromString(@"AWEIMChatModel") isNoticeChat:chat] && [chat.name isKindOfClass:NSString.class] &&
        [@[@"互动消息",@"互动通知"] containsObject:chat.name];
    return [DYYYMessageListMetrics kindForNotice:notice pinned:chat.stickOnTop];
}
+ (NSMapTable *)rowPlans:(UITableView *)table create:(BOOL)create {
    NSMapTable *plans=objc_getAssociatedObject(table,@selector(rowHeight:controller:table:indexPath:));
    if(!plans && create){plans=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];objc_setAssociatedObject(table,@selector(rowHeight:controller:table:indexPath:),plans,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    return plans;
}
+ (CGFloat)rowHeight:(CGFloat)native controller:(UIViewController *)candidate table:(UITableView *)table indexPath:(NSIndexPath *)path {
    if(!NSThread.isMainThread || ![self cardsEnabled] || ![self adapterReady] || ![self contentAdapterReady] || ![candidate isKindOfClass:NSClassFromString(@"AWEIMChatListViewController")] || path.section!=0)return native;
    AWEIMChatListViewController *owner=(id)candidate;NSArray *chats=owner.chatList;
    if(table!=owner.tableView || ![chats isKindOfClass:NSArray.class] || path.row>=chats.count)return native;
    NSString *kind=[self kindForChat:chats[path.row]],*previous=path.row?[self kindForChat:chats[path.row-1]]:nil,*next=path.row+1<chats.count?[self kindForChat:chats[path.row+1]]:nil;
    NSDictionary *plan=[DYYYMessageListMetrics paddingForKind:kind previous:previous next:next nativeHeight:native];
    if(!plan.count)return native;
    [[self rowPlans:table create:YES] setObject:plan forKey:chats[path.row]];
    return [plan[@"height"] doubleValue];
}
+ (NSDictionary *)paddingForCell:(UITableViewCell *)cell {
    AWEIMChatListViewController *owner=(id)[self owner:cell named:@"AWEIMChatListViewController"];
    if(!owner || ![cell isKindOfClass:NSClassFromString(@"AWEIMChatListCommonCell")])return nil;
    id chat=((AWEIMChatListCommonCell *)cell).cellViewModel.chat;
    NSDictionary *plan=chat?[[self rowPlans:owner.tableView create:NO] objectForKey:chat]:nil;
    return plan && fabs(cell.bounds.size.height-[plan[@"height"] doubleValue])<0.5?plan:nil;
}
+ (UIView *)avatarInContent:(UIView *)content {
    if(content.subviews.count>64)return nil;
    for(UIView *view in content.subviews){
        if(view.subviews.count>8)continue;
        for(UIView *leaf in view.subviews)if([leaf isKindOfClass:NSClassFromString(@"AWEIMChatCellAvatarView")])return leaf;
    }
    return nil;
}
+ (NSHashTable *)lightViews { static NSHashTable *t;static dispatch_once_t once;dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];});return t; }
+ (void)resetLightInteraction:(UIView *)view {
    if(!NSThread.isMainThread)return;
    DYYYMessageLightState *state=objc_getAssociatedObject(view,@selector(synchronizeLightInteraction:));
    if(!state || state.busy)return;state.busy=YES;
    UIButton *button=state.button;
    if(button.layer.mask==state.mask)button.layer.mask=state.nativeMask;
    if(UIEdgeInsetsEqualToEdgeInsets(button.imageEdgeInsets,state.appliedInsets))button.imageEdgeInsets=state.nativeInsets;
    objc_setAssociatedObject(view,@selector(synchronizeLightInteraction:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self lightViews] removeObject:view];
}
+ (void)synchronizeLightInteraction:(UIView *)candidate {
    if(!NSThread.isMainThread || ![candidate isKindOfClass:NSClassFromString(@"AWEIMChatCellRecommendChatLIView")])return;
    DYYYMessageLightState *state=objc_getAssociatedObject(candidate,@selector(synchronizeLightInteraction:));if(state.busy)return;
    if(![self cardsEnabled] || !candidate.window || ![self owner:candidate named:@"AWEIMChatListViewController"]){[self resetLightInteraction:candidate];return;}
    if(![candidate respondsToSelector:@selector(lightInteractionBtn)])return;
    UIButton *button=((AWEIMChatCellRecommendChatLIView *)candidate).lightInteractionBtn;
    if(![button isKindOfClass:UIButton.class] || button.bounds.size.width<30 || button.bounds.size.width>60 || button.bounds.size.height<30 || button.bounds.size.height>60)return;
    if(state && state.button!=button){[self resetLightInteraction:candidate];state=nil;}
    if(!state){
        if(button.layer.mask)return;
        state=[DYYYMessageLightState new];state.button=button;state.nativeMask=button.layer.mask;state.nativeInsets=button.imageEdgeInsets;state.mask=[CAShapeLayer layer];state.mask.fillColor=UIColor.blackColor.CGColor;
        state.appliedInsets=state.nativeInsets;
        objc_setAssociatedObject(candidate,@selector(synchronizeLightInteraction:),state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self lightViews] addObject:candidate];
    }
    state.busy=YES;
    @try {
        if(!UIEdgeInsetsEqualToEdgeInsets(button.imageEdgeInsets,state.appliedInsets))state.nativeInsets=button.imageEdgeInsets;
        state.appliedInsets=UIEdgeInsetsMake(state.nativeInsets.top+3,state.nativeInsets.left+3,state.nativeInsets.bottom+3,state.nativeInsets.right+3);
        CGFloat diameter=MIN(button.bounds.size.width,button.bounds.size.height)*0.75;
        CGRect circle=CGRectMake((button.bounds.size.width-diameter)/2,(button.bounds.size.height-diameter)/2,diameter,diameter);
        [CATransaction begin];[CATransaction setDisableActions:YES];if(!CGRectEqualToRect(state.mask.frame,button.bounds))state.mask.frame=button.bounds;
        CGPathRef path=[UIBezierPath bezierPathWithOvalInRect:circle].CGPath;
        if(!state.mask.path || !CGPathEqualToPath(state.mask.path,path))state.mask.path=path;
        if(button.layer.mask!=state.mask)button.layer.mask=state.mask;[CATransaction commit];
        if(!UIEdgeInsetsEqualToEdgeInsets(button.imageEdgeInsets,state.appliedInsets))button.imageEdgeInsets=state.appliedInsets;
    } @finally {state.busy=NO;}
}
+ (void)clearFill:(UIView *)view state:(DYYYMessageCardState *)state {
    if(!view)return;
    UIColor *color=view.backgroundColor;
    if(![state.fills objectForKey:view] || (color && CGColorGetAlpha(color.CGColor)>0)) [state.fills setObject:color ?: NSNull.null forKey:view];
    if(color && CGColorGetAlpha(color.CGColor)>0)view.backgroundColor=UIColor.clearColor;
}
+ (void)restoreMasks:(DYYYMessageCardState *)state {
    for(UIView *view in state.masks.keyEnumerator.allObjects){
        NSDictionary *saved=[state.masks objectForKey:view];
        if(view.layer.mask==saved[@"applied"])view.layer.mask=saved[@"native"]==NSNull.null?nil:saved[@"native"];
    }
    [state.masks removeAllObjects];
}
+ (NSHashTable *)contentViews { static NSHashTable *t;static dispatch_once_t once;dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];});return t; }
+ (BOOL)contentAdapterReady {
    static BOOL ready;if(ready)return YES;
    Class cls=NSClassFromString(@"UITableViewCellContentView");
    if(![cls isSubclassOfClass:UIView.class])return NO;
    NSDictionary *types=@{NSStringFromSelector(@selector(setFrame:)):[NSString stringWithUTF8String:@encode(CGRect)],NSStringFromSelector(@selector(setBounds:)):[NSString stringWithUTF8String:@encode(CGRect)],NSStringFromSelector(@selector(setCenter:)):[NSString stringWithUTF8String:@encode(CGPoint)],NSStringFromSelector(@selector(setTransform:)):[NSString stringWithUTF8String:@encode(CGAffineTransform)]};
    for(NSString *name in types){
        NSMethodSignature *signature=[cls instanceMethodSignatureForSelector:NSSelectorFromString(name)];
        if(!signature || signature.numberOfArguments!=3 || strcmp(signature.methodReturnType,@encode(void)) || strcmp([signature getArgumentTypeAtIndex:2],[types[name] UTF8String]))return NO;
    }
    ready=YES;return YES;
}
+ (DYYYMessageContentState *)contentState:(UIView *)view {
    if(!NSThread.isMainThread)return nil;
    DYYYMessageContentState *state=objc_getAssociatedObject(view,@selector(beginContentGeometry:));
    return state.active && state.cell.contentView==view?state:nil;
}
+ (NSDictionary *)valuesForFrame:(CGRect)frame {
    return @{@"x":@(frame.origin.x),@"y":@(frame.origin.y),@"width":@(frame.size.width),@"height":@(frame.size.height)};
}
+ (CGRect)nativeContentFrame:(CGRect)frame forView:(UIView *)view {
    DYYYMessageContentState *state=[self contentState:view];
    if(!state || state.busy || state.updates.depth || !state.applied)return frame;
    NSDictionary *native=[DYYYMessageListMetrics nativeFrameForRequest:[self valuesForFrame:frame] previousNative:[self valuesForFrame:state.nativeFrame] previousDisplayed:[self valuesForFrame:state.displayedFrame]];
    return CGRectMake([native[@"x"] doubleValue],[native[@"y"] doubleValue],[native[@"width"] doubleValue],[native[@"height"] doubleValue]);
}
+ (void)applyContent:(DYYYMessageContentState *)state {
    UIView *view=state.view;
    if(!view || !state.active || state.busy || state.updates.depth)return;
    NSDictionary *plan=[DYYYMessageListMetrics contentTransformForX:0 y:0 width:view.bounds.size.width height:view.bounds.size.height rowWidth:view.bounds.size.width rowHeight:view.bounds.size.height];
    if(!plan.count){state.decision=@"unready_bounds";return;}
    state.scale=[plan[@"scale"] doubleValue];
    state.nativeFrame=view.frame;
    state.nativeTransform=view.transform;
    state.appliedTransform=CGAffineTransformScale(state.nativeTransform,state.scale,state.scale);
    state.verticalShift=0;
    state.busy=YES;
    @try {[UIView performWithoutAnimation:^{
        view.transform=state.appliedTransform;
        if(state.topPadding || state.bottomPadding){
            UIView *avatar=[self avatarInContent:view];
            if(avatar){
                CGRect rect=[avatar convertRect:avatar.bounds toView:state.cell];
                CGFloat desired=(state.topPadding+state.cell.bounds.size.height-state.bottomPadding)/2;
                state.verticalShift=desired-CGRectGetMidY(rect);
                CGAffineTransform shifted=state.appliedTransform;shifted.ty+=state.verticalShift;
                state.appliedTransform=shifted;view.transform=shifted;
            }
        }
    }];}
    @finally {state.busy=NO;}
    state.displayedFrame=view.frame;state.applied=YES;state.decision=@"container_applied";
}
+ (id)beginContentGeometry:(UIView *)view {
    DYYYMessageContentState *state=[self contentState:view];
    if(!state || state.busy)return nil;
    BOOL outer=state.updates.depth==0;
    NSUInteger generation=[state.updates beginUpdate];
    if(outer && state.applied){
        state.busy=YES;
        @try {if(CGAffineTransformEqualToTransform(view.transform,state.appliedTransform))[UIView performWithoutAnimation:^{view.transform=state.nativeTransform;}];}
        @finally {state.busy=NO;}
        state.applied=NO;
    }
    DYYYMessageContentToken *token=[DYYYMessageContentToken new];token.state=state;token.view=view;token.generation=generation;
    return token;
}
+ (void)endContentGeometry:(id)candidate {
    if(!NSThread.isMainThread || ![candidate isKindOfClass:DYYYMessageContentToken.class])return;
    DYYYMessageContentToken *token=candidate;
    if([self contentState:token.view]!=token.state)return;
    if([token.state.updates endUpdate:token.generation])[self applyContent:token.state];
}
+ (CGAffineTransform)nativeContentTransform:(CGAffineTransform)transform forView:(UIView *)view {
    DYYYMessageContentState *state=[self contentState:view];
    if(!state || state.busy)return transform;
    if(state.applied && !state.updates.depth && CGAffineTransformEqualToTransform(transform,state.appliedTransform))return transform;
    state.nativeTransform=transform;
    if(state.updates.depth || !state.applied)return transform;
    CGAffineTransform applied=CGAffineTransformScale(transform,state.scale,state.scale);
    applied.ty+=state.verticalShift;state.appliedTransform=applied;
    return state.appliedTransform;
}
+ (void)didSetContentTransform:(UIView *)view {
    DYYYMessageContentState *state=[self contentState:view];
    if(!state || state.busy || state.updates.depth || !state.applied || state.scale<=0)return;
    state.displayedFrame=view.frame;
    // 原生变换与均匀缩放共用中心；反算只用于识别之后由显示 frame 派生的原生移动。
    CGRect rect=view.frame;rect.origin.y-=state.verticalShift;CGFloat xInset=rect.size.width*(1/state.scale-1)/2,yInset=rect.size.height*(1/state.scale-1)/2;
    state.nativeFrame=CGRectInset(rect,-xInset,-yInset);
}
+ (void)resetContentView:(UIView *)view {
    DYYYMessageContentState *state=objc_getAssociatedObject(view,@selector(beginContentGeometry:));
    if(!state || state.busy)return;
    [state.updates invalidate];state.active=NO;state.busy=YES;
    @try {if(state.applied && CGAffineTransformEqualToTransform(view.transform,state.appliedTransform))[UIView performWithoutAnimation:^{view.transform=state.nativeTransform;}];}
    @finally {state.busy=NO;}
    objc_setAssociatedObject(view,@selector(beginContentGeometry:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self contentViews] removeObject:view];
}
+ (void)synchronizeContent:(UITableViewCell *)cell {
    UIView *view=cell.contentView;
    if(![self contentAdapterReady] || ![view isKindOfClass:NSClassFromString(@"UITableViewCellContentView")])return;
    DYYYMessageContentState *state=[self contentState:view];
    NSDictionary *padding=[self paddingForCell:cell];
    CGFloat top=[padding[@"top"] doubleValue],bottom=[padding[@"bottom"] doubleValue];
    BOOL changed=state && (state.topPadding!=top || state.bottomPadding!=bottom);
    if(state && changed){
        id token=[self beginContentGeometry:view];state.topPadding=top;state.bottomPadding=bottom;[self endContentGeometry:token];
    }
    if(state){
        if(state.busy || state.updates.depth)return;
        if(state.applied && CGAffineTransformEqualToTransform(view.transform,state.appliedTransform)){[self didSetContentTransform:view];return;}
    } else {
        state=[DYYYMessageContentState new];state.view=view;state.cell=cell;state.active=YES;state.topPadding=top;state.bottomPadding=bottom;state.updates=[DYYYMessageListUpdateState new];
        objc_setAssociatedObject(view,@selector(beginContentGeometry:),state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self contentViews] addObject:view];
    }
    [self applyContent:state];
}
+ (void)maskBackground:(UIView *)view state:(DYYYMessageCardState *)state {
    NSDictionary *saved=[state.masks objectForKey:view];
    if(saved && view.layer.mask!=saved[@"applied"]){[state.masks removeObjectForKey:view];saved=nil;}
    CALayer *mask=saved[@"applied"];
    if(!mask){
        if(view.layer.mask)return;
        // 原生满行底板可能在异步渲染后重写颜色。仅遮住已核对的空背景视图，不钩全局 setter。
        mask=[CALayer layer];mask.backgroundColor=UIColor.clearColor.CGColor;
        [state.masks setObject:@{@"native":NSNull.null,@"applied":mask,@"background":@YES} forKey:view];
        [CATransaction begin];[CATransaction setDisableActions:YES];view.layer.mask=mask;[CATransaction commit];
    }
    CGRect rect=view.bounds;
    if(!CGRectEqualToRect(mask.frame,rect)){[CATransaction begin];[CATransaction setDisableActions:YES];mask.frame=rect;[CATransaction commit];}
}
+ (void)resetCard:(UITableViewCell *)cell {
    if(!NSThread.isMainThread)return;
    DYYYMessageCardState *state=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
    if(!state || state.busy)return;
    state.busy=YES;
    if(cell.backgroundView==state.background)cell.backgroundView=state.nativeBackground;
    if(cell.selectedBackgroundView==state.selected)cell.selectedBackgroundView=state.nativeSelected;
    for(UIView *view in state.fills.keyEnumerator.allObjects)if(!view.backgroundColor || CGColorGetAlpha(view.backgroundColor.CGColor)==0){
        id color=[state.fills objectForKey:view];view.backgroundColor=color==NSNull.null?nil:color;
    }
    if(state.line.hidden)state.line.hidden=state.lineHidden;
    objc_setAssociatedObject(cell,@selector(synchronizeCell:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self cells] removeObject:cell];
}
+ (void)resetCell:(UITableViewCell *)cell {
    if(!NSThread.isMainThread)return;
    [self resetContentView:cell.contentView];[self resetCard:cell];
}
+ (void)synchronizeCell:(UITableViewCell *)base {
    if(!NSThread.isMainThread || ![base isKindOfClass:NSClassFromString(@"AWEIMChatListCommonCell")])return;
    AWEIMChatListCommonCell *cell=(id)base;
    DYYYMessageCardState *state=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
    if(state.busy)return;
    AWEIMChatListViewController *owner=(id)[self owner:cell named:@"AWEIMChatListViewController"];
    if(![self cardsEnabled] || !owner || !cell.window || ![self adapterReady]){[self resetCell:cell];return;}
    [self synchronizeContent:cell];
    for(UIView *view in cell.contentView.subviews)if([view isKindOfClass:NSClassFromString(@"AWEIMChatCellRecommendChatLIView")])[self synchronizeLightInteraction:view];
    UITableView *table=owner.tableView;
    NSIndexPath *index=[table indexPathForCell:cell];
    NSArray *chats=owner.chatList;
    if(![table isKindOfClass:UITableView.class] || ![chats isKindOfClass:NSArray.class] || !index || index.row>=chats.count ||
        [table numberOfRowsInSection:index.section]!=chats.count || table.hasUncommittedUpdates)return;
    AWEIMChatModel *chat=cell.cellViewModel.chat;
    if(chats[index.row]!=chat){[self resetCard:cell];return;}
    NSString *kind=[self kindForChat:chat],*previous=index.row?[self kindForChat:chats[index.row-1]]:nil;
    NSString *next=index.row+1<chats.count?[self kindForChat:chats[index.row+1]]:nil;
    NSDictionary *segment=[DYYYMessageListMetrics segmentForKind:kind previous:previous next:next width:cell.bounds.size.width height:cell.bounds.size.height];
    if(!segment.count){[self resetCard:cell];return;}
    if(!state){
        state=[DYYYMessageCardState new];state.nativeBackground=cell.backgroundView;state.nativeSelected=cell.selectedBackgroundView;
        state.fills=[NSMapTable weakToStrongObjectsMapTable];state.masks=[NSMapTable weakToStrongObjectsMapTable];state.background=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];state.selected=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];
        state.background.accessibilityIdentifier=@"DYads.MessageGroupBackground";state.selected.accessibilityIdentifier=@"DYads.MessageGroupSelection";
        objc_setAssociatedObject(cell,@selector(synchronizeCell:),state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self cells] addObject:cell];
    }
    state.busy=YES;
    @try {
        state.kind=kind;
        BOOL dark=[DYYYUtils isDarkMode] || cell.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark;
        state.background.fillColor=dark?[UIColor colorWithWhite:0.14 alpha:1]:UIColor.secondarySystemGroupedBackgroundColor;
        state.selected.fillColor=dark?[UIColor colorWithWhite:0.21 alpha:1]:UIColor.tertiarySystemFillColor;
        state.background.segment=segment;state.selected.segment=segment;
        if(!CGRectEqualToRect(state.background.frame,cell.bounds))state.background.frame=cell.bounds;
        if(!CGRectEqualToRect(state.selected.frame,cell.bounds))state.selected.frame=cell.bounds;
        if(cell.backgroundView!=state.background)cell.backgroundView=state.background;
        if(cell.selectedBackgroundView!=state.selected)cell.selectedBackgroundView=state.selected;
        [self clearFill:cell state:state];[self clearFill:cell.contentView state:state];
        CGFloat nativeHeight=[[self paddingForCell:cell][@"nativeHeight"] doubleValue];
        for(UIView *view in cell.contentView.subviews)
            if(view.class==UIView.class && !view.subviews.count && !view.layer.contents && !view.layer.sublayers.count && (CGRectEqualToRect(view.frame,cell.contentView.bounds) || (nativeHeight>0 && view.frame.origin.x==0 && view.frame.origin.y==0 && view.frame.size.width==cell.contentView.bounds.size.width && fabs(view.frame.size.height-nativeHeight)<0.5)))
                [self maskBackground:view state:state];
        UIView *line=cell.horizontalLine;
        if(line!=state.line){state.line=line;state.lineHidden=line.hidden;}
        if(!line.hidden)line.hidden=YES;
    } @finally {state.busy=NO;}
}
+ (void)synchronizeController:(UIViewController *)controller {
    if(!NSThread.isMainThread || ![controller isKindOfClass:NSClassFromString(@"AWEIMChatListViewController")] || !controller.isViewLoaded)return;
    [[self controllers] addObject:controller];
    UITableView *table=((AWEIMChatListViewController *)controller).tableView;
    if(![table isKindOfClass:UITableView.class])return;
    NSNumber *separator=objc_getAssociatedObject(table,@selector(synchronizeController:));
    if([self cardsEnabled] && [self adapterReady]){
        if(!separator)objc_setAssociatedObject(table,@selector(synchronizeController:),@(table.separatorStyle),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(table.separatorStyle!=UITableViewCellSeparatorStyleNone)table.separatorStyle=UITableViewCellSeparatorStyleNone;
    } else if(separator){
        if(table.separatorStyle==UITableViewCellSeparatorStyleNone)table.separatorStyle=separator.integerValue;
        objc_setAssociatedObject(table,@selector(synchronizeController:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for(UITableViewCell *cell in table.visibleCells)[self synchronizeCell:cell];
}
// 顶栏颜色与玻璃分别保存；原生后续换肤仍通过专用导航栏 setter 记录原值。
+ (DYYYMessageHeaderState *)headerState:(UIView *)bar create:(BOOL)create {
    DYYYMessageHeaderState *state=objc_getAssociatedObject(bar,@selector(synchronizeBar:));
    if(!state && create){
        state=[DYYYMessageHeaderState new];state.fills=[NSMapTable weakToStrongObjectsMapTable];state.nativeOpaque=bar.opaque;
        state.left=[DYYYChatChrome glassBackgroundWithIdentifier:@"DYads.MessageListLeftGlass"];
        state.right=[DYYYChatChrome glassBackgroundWithIdentifier:@"DYads.MessageListRightGlass"];
        objc_setAssociatedObject(bar,@selector(synchronizeBar:),state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self bars] addObject:bar];
    }
    return state;
}
+ (void)restoreHeader:(UIView *)bar state:(DYYYMessageHeaderState *)state {
    if(!state || state.busy)return;
    state.busy=YES;
    [NSLayoutConstraint deactivateConstraints:state.constraints];
    [state.left removeFromSuperview];[state.right removeFromSuperview];
    for(UIView *view in state.fills.keyEnumerator.allObjects)if(!view.backgroundColor || CGColorGetAlpha(view.backgroundColor.CGColor)==0){
        id saved=[state.fills objectForKey:view];view.backgroundColor=saved==NSNull.null?nil:saved;
    }
    if(!bar.opaque)bar.opaque=state.nativeOpaque;
    if(state.line.hidden)state.line.hidden=state.lineHidden;
    objc_setAssociatedObject(bar,@selector(synchronizeBar:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self bars] removeObject:bar];
    state.busy=NO;
}
+ (BOOL)hasTopOwner:(UIView *)bar {
    return [self owner:bar named:@"AWEIMMessageTabViewController"] || [self owner:bar named:@"AWEIMFansAndInteractMergeViewController"];
}
+ (UIColor *)nativeBackgroundColor:(UIColor *)color forBar:(UIView *)bar {
    if(!NSThread.isMainThread || ![self topEnabled] || ![self hasTopOwner:bar])return color;
    DYYYMessageHeaderState *state=[self headerState:bar create:YES];
    if(state.busy)return color;
    [state.fills setObject:color?:NSNull.null forKey:bar];
    return UIColor.clearColor;
}
+ (BOOL)nativeOpaque:(BOOL)opaque forBar:(UIView *)bar {
    if(!NSThread.isMainThread || ![self topEnabled] || ![self hasTopOwner:bar])return opaque;
    DYYYMessageHeaderState *state=[self headerState:bar create:YES];
    if(state.busy)return opaque;
    state.nativeOpaque=opaque;
    return NO;
}
+ (void)clearHeaderFill:(UIView *)view state:(DYYYMessageHeaderState *)state {
    if(!view)return;
    UIColor *color=view.backgroundColor;
    if(![state.fills objectForKey:view] || (color && CGColorGetAlpha(color.CGColor)>0))[state.fills setObject:color?:NSNull.null forKey:view];
    if(color && CGColorGetAlpha(color.CGColor)>0)view.backgroundColor=UIColor.clearColor;
}
+ (void)synchronizeBar:(UIView *)candidate {
    if(!NSThread.isMainThread || ![candidate isKindOfClass:NSClassFromString(@"AWENavigationBar")])return;
    AWENavigationBar *bar=(id)candidate;
    DYYYMessageHeaderState *state=[self headerState:bar create:NO];
    if(state.busy)return;
    if(![self topEnabled] || ![self hasTopOwner:bar] || !bar.window){[self restoreHeader:bar state:state];return;}
    BOOL notice=[self owner:bar named:@"AWEIMFansAndInteractMergeViewController"]!=nil;
    UIView *carrier=bar.contentView,*left=nil,*right=notice?nil:bar.rightBtnsContainerView;
    if(!carrier || carrier.bounds.size.height<32 || carrier.bounds.size.height>64){[self restoreHeader:bar state:state];return;}
    for(UIView *view in carrier.subviews){
        if([view isKindOfClass:NSClassFromString(notice?@"AWEIMNavigationUnreadView":@"AWEIMMessageTabExpandedHitContainerView")])left=view;
        if(notice && [view isKindOfClass:NSClassFromString(@"AWEIMFansAndInteractMergeViewControllerNaviBar")])right=view;
    }
    NSUInteger buttons=0;
    for(UIView *child in right.subviews)if([child isKindOfClass:UIControl.class]&&!child.hidden)buttons++;
    if(!left || right.superview!=carrier || (!notice && buttons<2) || left.hidden || right.hidden || left.alpha<=0.01 || right.alpha<=0.01){[self restoreHeader:bar state:state];return;}
    state=[self headerState:bar create:YES];state.busy=YES;
    @try {
        [self clearHeaderFill:bar state:state];[self clearHeaderFill:carrier state:state];
        [self clearHeaderFill:left state:state];[self clearHeaderFill:right state:state];
        if(bar.opaque)bar.opaque=NO;
        UIView *line=bar.bottomLineView;
        if(line!=state.line){state.line=line;state.lineHidden=line.hidden;}
        if(!line.hidden)line.hidden=YES;
        // 玻璃的约束依赖原生按钮容器的实际边界；不会把布局中途的零宽当作最终尺寸。
        // 背景留在外层，不进入原生按钮数组/子视图，避免参与原生按钮宽度测量。
        CGFloat height=MIN(44,carrier.bounds.size.height);
        CGRect leftRect=CGRectMake(left.frame.origin.x-(notice?6:0),(carrier.bounds.size.height-height)/2,notice?left.bounds.size.width+12:height,height);
        CGRect rightRect=CGRectMake(right.frame.origin.x,(carrier.bounds.size.height-height)/2,right.bounds.size.width,height);
        BOOL rebind=state.notice!=notice || state.leftAnchor!=left || state.rightAnchor!=right || state.left.superview!=carrier || state.right.superview!=carrier;
        if(rebind)[NSLayoutConstraint deactivateConstraints:state.constraints];
        [DYYYChatChrome placeGlassBackground:state.left frame:leftRect inView:carrier];
        [DYYYChatChrome placeGlassBackground:state.right frame:rightRect inView:carrier];
        if(rebind){
            state.left.translatesAutoresizingMaskIntoConstraints=NO;state.right.translatesAutoresizingMaskIntoConstraints=NO;
            state.constraints=@[
                [state.left.leadingAnchor constraintEqualToAnchor:left.leadingAnchor constant:notice?-6:0],
                [state.left.centerYAnchor constraintEqualToAnchor:carrier.centerYAnchor],
                notice?[state.left.widthAnchor constraintEqualToAnchor:left.widthAnchor constant:12]:[state.left.widthAnchor constraintEqualToConstant:44],
                [state.left.heightAnchor constraintEqualToConstant:44],
                [state.right.leadingAnchor constraintEqualToAnchor:right.leadingAnchor],
                [state.right.trailingAnchor constraintEqualToAnchor:right.trailingAnchor],
                [state.right.centerYAnchor constraintEqualToAnchor:carrier.centerYAnchor],
                [state.right.heightAnchor constraintEqualToConstant:44]];
            [NSLayoutConstraint activateConstraints:state.constraints];state.leftAnchor=left;state.rightAnchor=right;state.notice=notice;
        }
    } @finally {state.busy=NO;}
}
+ (void)scheduleBarSynchronization:(UIView *)bar {
    if(!NSThread.isMainThread)return;
    DYYYMessageHeaderState *state=[self headerState:bar create:NO];
    if(!state || state.pending || state.busy || !bar.window)return;
    state.pending=YES;
    __weak UIView *weakBar=bar;
    dispatch_async(dispatch_get_main_queue(),^{
        UIView *strongBar=weakBar;
        if(!strongBar || [self headerState:strongBar create:NO]!=state)return;
        state.pending=NO;
        [self synchronizeBar:strongBar];
    });
}
+ (void)refresh {
    if(!NSThread.isMainThread)return;
    if(![self cardsEnabled]){
        for(UIView *view in [self lightViews].allObjects)[self resetLightInteraction:view];
        for(UIView *view in [self contentViews].allObjects)[self resetContentView:view];
        for(UITableViewCell *cell in [self cells].allObjects)[self resetCell:cell];
    }
    for(UIViewController *controller in [self controllers].allObjects){
        UITableView *table=((AWEIMChatListViewController *)controller).tableView;
        if([self rowPlans:table create:NO] && !table.hasUncommittedUpdates && !table.dragging && !table.decelerating)[table reloadData];
        [self synchronizeController:controller];
    }
    for(UIView *bar in [self bars].allObjects)[self synchronizeBar:bar];
    [DYYYInteractionNoticeStyle refresh];
}
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};
    NSMutableDictionary *groups=[NSMutableDictionary dictionary];
    NSMutableDictionary *decisions=[NSMutableDictionary dictionary];
    NSUInteger insets=0,backgroundMasks=0;
    for(UITableViewCell *cell in [self cells].allObjects)if(cell.window){
        DYYYMessageCardState *s=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
        if(s.kind)groups[s.kind]=@([groups[s.kind] unsignedIntegerValue]+1);
        for(UIView *view in s.masks.keyEnumerator.allObjects){NSDictionary *mask=[s.masks objectForKey:view];if([mask[@"background"] boolValue] && view.layer.mask==mask[@"applied"])backgroundMasks++;}
    }
    NSMutableArray *content=[NSMutableArray array];
    for(UIView *view in [self contentViews].allObjects)if(view.window){
        DYYYMessageContentState *state=[self contentState:view];if(!state)continue;
        BOOL matches=state.applied && !state.updates.depth && CGAffineTransformEqualToTransform(view.transform,state.appliedTransform);
        if(matches)insets++;
        NSString *decision=matches?@"container_matches":state.decision?:@"matrix_changed";
        if(state.applied && !matches)decision=@"matrix_changed";
        decisions[decision]=@([decisions[decision] unsignedIntegerValue]+1);
        if(content.count>=3)continue;
        NSMutableDictionary *sample=[@{@"scaleX":@(hypot(view.transform.a,view.transform.b)),@"visualFrame":[self valuesForFrame:[view convertRect:view.bounds toView:state.cell]],@"matrixMatches":@(matches),@"updateDepth":@(state.updates.depth),@"paddingTop":@(state.topPadding),@"paddingBottom":@(state.bottomPadding)} mutableCopy];
        for(UIView *child in view.subviews){
            if([child isKindOfClass:NSClassFromString(@"IESIMAsyncDrawableView")] && !sample[@"textFrame"] && !child.hidden)
                sample[@"textFrame"]=[self valuesForFrame:[child convertRect:child.bounds toView:state.cell]];
            if(child.subviews.count>8)continue;
            for(UIView *leaf in child.subviews)if([leaf isKindOfClass:NSClassFromString(@"AWEIMChatCellAvatarView")])
                sample[@"avatarFrame"]=[self valuesForFrame:[leaf convertRect:leaf.bounds toView:state.cell]];
        }
        CALayer *presentation=view.layer.presentationLayer;
        if(presentation){CGAffineTransform transform=presentation.affineTransform;sample[@"presentationScaleX"]=@(hypot(transform.a,transform.b));}
        [content addObject:sample];
    }
    NSMutableArray *headers=[NSMutableArray array];
    for(UIView *bar in [self bars].allObjects)if(bar.window && headers.count<4){
        DYYYMessageHeaderState *s=[self headerState:bar create:NO];
        [headers addObject:@{@"transparent":@(!bar.backgroundColor || CGColorGetAlpha(bar.backgroundColor.CGColor)==0),@"leftGlassWidth":@(s.left.bounds.size.width),@"rightGlassWidth":@(s.right.bounds.size.width),@"rightMounted":@(s.right.superview!=nil)}];
    }
    return @{@"cardsEnabled":@([self cardsEnabled]),@"topEnabled":@([self topEnabled]),@"adapterReady":@([self adapterReady]),@"visibleRowsByGroup":groups,@"insetRows":@(insets),@"contentScale":@0.92,@"contentDecisions":decisions,@"contentContainers":content,@"contentAdapterReady":@([self contentAdapterReady]),@"backgroundMasks":@(backgroundMasks),@"compactLightInteractionViews":@([self lightViews].allObjects.count),@"headers":headers,@"nativeRowGeometry":@YES,@"unreadMutation":@NO};
}
@end
