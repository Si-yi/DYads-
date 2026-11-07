#import "DYYYMessageListStyle.h"
#import "DYYYMessageListCardView.h"
#import "DYYYMessageListMetrics.h"
#import "DYYYChatChrome.h"
#import "DYYYChatEnhancementPolicy.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

@interface DYYYMessageCardState : NSObject
@property (nonatomic, strong) UIView *nativeBackground;
@property (nonatomic, strong) UIView *nativeSelected;
@property (nonatomic, strong) DYYYMessageListCardView *background;
@property (nonatomic, strong) DYYYMessageListCardView *selected;
@property (nonatomic, strong) NSMapTable<UIView *, id> *fills;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *masks;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *translations;
@property (nonatomic, weak) UIView *line;
@property (nonatomic) BOOL lineHidden;
@property (nonatomic) BOOL busy;
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, copy) NSString *contentDecision;
@end
@implementation DYYYMessageCardState @end

@interface DYYYMessageHeaderState : NSObject
@property (nonatomic, strong) UIVisualEffectView *left;
@property (nonatomic, strong) UIVisualEffectView *right;
@property (nonatomic, strong) NSMapTable<UIView *, id> *fills;
@property (nonatomic, weak) UIView *line;
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
+ (void)restoreInsets:(DYYYMessageCardState *)state {
    for(UIView *view in state.translations.keyEnumerator.allObjects){
        NSDictionary *saved=[state.translations objectForKey:view];
        if(CGAffineTransformEqualToTransform(view.transform,[saved[@"applied"] CGAffineTransformValue]))view.transform=[saved[@"native"] CGAffineTransformValue];
    }
    [state.translations removeAllObjects];
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
+ (void)prepareCellLayout:(UITableViewCell *)cell {
    if(!NSThread.isMainThread)return;
    DYYYMessageCardState *state=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
    if(!state || state.busy)return;
    state.busy=YES;
    [self restoreInsets:state];
    [self restoreMasks:state];
    state.busy=NO;
}
+ (void)insetContent:(AWEIMChatListCommonCell *)cell state:(DYYYMessageCardState *)state {
    // 异步平铺分支不保证 avatarContainer 属性就是已挂载的头像容器。
    // 只枚举已显示的直接内容组件，同一行统一缩放，保持原生内容和动作。
    if(!CGPointEqualToPoint(cell.contentView.bounds.origin,CGPointZero) || cell.contentView.subviews.count>64){state.contentDecision=@"unsupported_container";[self restoreInsets:state];return;}
    NSMutableArray *placements=[NSMutableArray array];
    for(UIView *view in cell.contentView.subviews){
        NSDictionary *mask=[state.masks objectForKey:view];
        if(view==state.line || [mask[@"background"] boolValue] || view.hidden || view.alpha<=0.01 || view.bounds.size.width<=0 || view.bounds.size.height<=0)continue;
        NSDictionary *old=[state.translations objectForKey:view];
        BOOL owns=old && CGAffineTransformEqualToTransform(view.transform,[old[@"applied"] CGAffineTransformValue]);
        CGAffineTransform native=owns?[old[@"native"] CGAffineTransformValue]:view.transform;
        if(!CGAffineTransformIsIdentity(native) || !CGPointEqualToPoint(view.layer.anchorPoint,CGPointMake(0.5,0.5))){state.contentDecision=@"native_transform_or_anchor";[self restoreInsets:state];return;}
        // center/bounds 不随 transform 改变，不能按已缩过的 frame 重算或再次扣偏移。
        CGRect rect=CGRectMake(view.center.x-view.bounds.size.width/2,view.center.y-view.bounds.size.height/2,view.bounds.size.width,view.bounds.size.height);
        NSDictionary *plan=[DYYYMessageListMetrics contentTransformForX:rect.origin.x y:rect.origin.y width:rect.size.width height:rect.size.height rowWidth:cell.bounds.size.width rowHeight:cell.bounds.size.height];
        if(!plan.count){state.contentDecision=@"unsupported_geometry";[self restoreInsets:state];return;}
        [placements addObject:@{@"view":view,@"plan":plan,@"native":[NSValue valueWithCGAffineTransform:native]}];
    }
    if(!placements.count){state.contentDecision=@"empty";[self restoreInsets:state];return;}
    for(NSDictionary *placement in placements){
        UIView *view=placement[@"view"];NSDictionary *plan=placement[@"plan"];
        CGFloat scale=[plan[@"scale"] doubleValue];
        CGAffineTransform applied=CGAffineTransformMake(scale,0,0,scale,[plan[@"translationX"] doubleValue],[plan[@"translationY"] doubleValue]);
        if(!CGAffineTransformEqualToTransform(view.transform,applied))view.transform=applied;
        [state.translations setObject:@{@"native":placement[@"native"],@"applied":[NSValue valueWithCGAffineTransform:applied]} forKey:view];
    }
    state.contentDecision=@"applied";
}
+ (void)resetCell:(UITableViewCell *)cell {
    if(!NSThread.isMainThread)return;
    DYYYMessageCardState *state=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
    if(!state || state.busy)return;
    [self prepareCellLayout:cell];
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
+ (void)synchronizeCell:(UITableViewCell *)base {
    if(!NSThread.isMainThread || ![base isKindOfClass:NSClassFromString(@"AWEIMChatListCommonCell")])return;
    AWEIMChatListCommonCell *cell=(id)base;
    DYYYMessageCardState *state=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
    if(state.busy)return;
    AWEIMChatListViewController *owner=(id)[self owner:cell named:@"AWEIMChatListViewController"];
    if(![self cardsEnabled] || !owner || !cell.window || ![self adapterReady]){[self resetCell:cell];return;}
    UITableView *table=owner.tableView;
    NSIndexPath *index=[table indexPathForCell:cell];
    NSArray *chats=owner.chatList;
    if(![table isKindOfClass:UITableView.class] || ![chats isKindOfClass:NSArray.class] || !index || index.row>=chats.count ||
        [table numberOfRowsInSection:index.section]!=chats.count || table.hasUncommittedUpdates)return;
    AWEIMChatModel *chat=cell.cellViewModel.chat;
    if(chats[index.row]!=chat){[self resetCell:cell];return;}
    NSString *kind=[self kindForChat:chat],*previous=index.row?[self kindForChat:chats[index.row-1]]:nil;
    NSString *next=index.row+1<chats.count?[self kindForChat:chats[index.row+1]]:nil;
    NSDictionary *segment=[DYYYMessageListMetrics segmentForKind:kind previous:previous next:next width:cell.bounds.size.width height:cell.bounds.size.height];
    if(!segment.count){[self resetCell:cell];return;}
    if(!state){
        state=[DYYYMessageCardState new];state.nativeBackground=cell.backgroundView;state.nativeSelected=cell.selectedBackgroundView;
        state.fills=[NSMapTable weakToStrongObjectsMapTable];state.masks=[NSMapTable weakToStrongObjectsMapTable];state.translations=[NSMapTable weakToStrongObjectsMapTable];state.background=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];state.selected=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];
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
        for(UIView *view in cell.contentView.subviews)
            if(view.class==UIView.class && !view.subviews.count && !view.layer.contents && !view.layer.sublayers.count && CGRectEqualToRect(view.frame,cell.contentView.bounds))
                [self maskBackground:view state:state];
        UIView *line=cell.horizontalLine;
        if(line!=state.line){state.line=line;state.lineHidden=line.hidden;}
        if(!line.hidden)line.hidden=YES;
        [self insetContent:cell state:state];
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
+ (UIColor *)nativeBackgroundColor:(UIColor *)color forBar:(UIView *)bar {
    if(!NSThread.isMainThread || ![self topEnabled] || ![self owner:bar named:@"AWEIMMessageTabViewController"])return color;
    DYYYMessageHeaderState *state=[self headerState:bar create:YES];
    if(state.busy)return color;
    [state.fills setObject:color?:NSNull.null forKey:bar];
    return UIColor.clearColor;
}
+ (BOOL)nativeOpaque:(BOOL)opaque forBar:(UIView *)bar {
    if(!NSThread.isMainThread || ![self topEnabled] || ![self owner:bar named:@"AWEIMMessageTabViewController"])return opaque;
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
    if(![self topEnabled] || ![self owner:bar named:@"AWEIMMessageTabViewController"] || !bar.window){[self restoreHeader:bar state:state];return;}
    UIView *carrier=bar.contentView,*left=nil,*right=bar.rightBtnsContainerView;
    if(!carrier || carrier.bounds.size.height<32 || carrier.bounds.size.height>64){[self restoreHeader:bar state:state];return;}
    for(UIView *view in carrier.subviews)
        if([view isKindOfClass:NSClassFromString(@"AWEIMMessageTabExpandedHitContainerView")])left=view;
    NSUInteger buttons=0;
    for(UIView *child in right.subviews)if([child isKindOfClass:UIControl.class]&&!child.hidden)buttons++;
    if(!left || right.superview!=carrier || buttons<2 || left.hidden || right.hidden || left.alpha<=0.01 || right.alpha<=0.01){[self restoreHeader:bar state:state];return;}
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
        CGRect leftRect=CGRectMake(left.frame.origin.x,(carrier.bounds.size.height-height)/2,height,height);
        CGRect rightRect=CGRectMake(right.frame.origin.x,(carrier.bounds.size.height-height)/2,right.bounds.size.width,height);
        BOOL rebind=state.leftAnchor!=left || state.rightAnchor!=right || state.left.superview!=carrier || state.right.superview!=carrier;
        if(rebind)[NSLayoutConstraint deactivateConstraints:state.constraints];
        [DYYYChatChrome placeGlassBackground:state.left frame:leftRect inView:carrier];
        [DYYYChatChrome placeGlassBackground:state.right frame:rightRect inView:carrier];
        if(rebind){
            state.left.translatesAutoresizingMaskIntoConstraints=NO;state.right.translatesAutoresizingMaskIntoConstraints=NO;
            state.constraints=@[
                [state.left.leadingAnchor constraintEqualToAnchor:left.leadingAnchor],
                [state.left.centerYAnchor constraintEqualToAnchor:carrier.centerYAnchor],
                [state.left.widthAnchor constraintEqualToConstant:44],
                [state.left.heightAnchor constraintEqualToConstant:44],
                [state.right.leadingAnchor constraintEqualToAnchor:right.leadingAnchor],
                [state.right.trailingAnchor constraintEqualToAnchor:right.trailingAnchor],
                [state.right.centerYAnchor constraintEqualToAnchor:carrier.centerYAnchor],
                [state.right.heightAnchor constraintEqualToConstant:44]];
            [NSLayoutConstraint activateConstraints:state.constraints];state.leftAnchor=left;state.rightAnchor=right;
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
    if(![self cardsEnabled])for(UITableViewCell *cell in [self cells].allObjects)[self resetCell:cell];
    for(UIViewController *controller in [self controllers].allObjects)[self synchronizeController:controller];
    for(UIView *bar in [self bars].allObjects)[self synchronizeBar:bar];
}
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};
    NSMutableDictionary *groups=[NSMutableDictionary dictionary];
    NSMutableDictionary *decisions=[NSMutableDictionary dictionary];
    NSUInteger insets=0,backgroundMasks=0;
    for(UITableViewCell *cell in [self cells].allObjects)if(cell.window){
        DYYYMessageCardState *s=objc_getAssociatedObject(cell,@selector(synchronizeCell:));
        if(s.kind)groups[s.kind]=@([groups[s.kind] unsignedIntegerValue]+1);
        if(s.contentDecision)decisions[s.contentDecision]=@([decisions[s.contentDecision] unsignedIntegerValue]+1);
        if(s.translations.count)insets++;
        for(UIView *view in s.masks.keyEnumerator.allObjects){NSDictionary *mask=[s.masks objectForKey:view];if([mask[@"background"] boolValue] && view.layer.mask==mask[@"applied"])backgroundMasks++;}
    }
    NSMutableArray *headers=[NSMutableArray array];
    for(UIView *bar in [self bars].allObjects)if(bar.window && headers.count<4){
        DYYYMessageHeaderState *s=[self headerState:bar create:NO];
        [headers addObject:@{@"transparent":@(!bar.backgroundColor || CGColorGetAlpha(bar.backgroundColor.CGColor)==0),@"leftGlassWidth":@(s.left.bounds.size.width),@"rightGlassWidth":@(s.right.bounds.size.width),@"rightMounted":@(s.right.superview!=nil)}];
    }
    return @{@"cardsEnabled":@([self cardsEnabled]),@"topEnabled":@([self topEnabled]),@"adapterReady":@([self adapterReady]),@"visibleRowsByGroup":groups,@"insetRows":@(insets),@"contentScale":@0.92,@"contentDecisions":decisions,@"backgroundMasks":@(backgroundMasks),@"headers":headers,@"nativeRowGeometry":@YES,@"unreadMutation":@NO};
}
@end
