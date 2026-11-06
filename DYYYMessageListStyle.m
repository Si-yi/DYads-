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
@property (nonatomic, weak) UIView *line;
@property (nonatomic) BOOL lineHidden;
@property (nonatomic) BOOL busy;
@property (nonatomic, copy) NSString *kind;
@end
@implementation DYYYMessageCardState @end

@interface DYYYMessageHeaderState : NSObject
@property (nonatomic, strong) UIVisualEffectView *left;
@property (nonatomic, strong) UIVisualEffectView *right;
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
+ (BOOL)usesCardsForCell:(UITableViewCell *)cell {
    return NSThread.isMainThread && [self cardsEnabled] && [self adapterReady] && [self owner:cell named:@"AWEIMChatListViewController"] != nil;
}
+ (void)clearFill:(UIView *)view state:(DYYYMessageCardState *)state {
    if(!view)return;
    UIColor *color=view.backgroundColor;
    if(![state.fills objectForKey:view] || (color && CGColorGetAlpha(color.CGColor)>0)) [state.fills setObject:color ?: NSNull.null forKey:view];
    if(color && CGColorGetAlpha(color.CGColor)>0)view.backgroundColor=UIColor.clearColor;
}
+ (void)resetCell:(UITableViewCell *)cell {
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
        state.fills=[NSMapTable weakToStrongObjectsMapTable];state.background=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];state.selected=[[DYYYMessageListCardView alloc] initWithFrame:cell.bounds];
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
            if(view.class==UIView.class && !view.subviews.count && !view.layer.sublayers.count && CGRectEqualToRect(view.frame,cell.contentView.bounds)) [self clearFill:view state:state];
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
+ (void)synchronizeBar:(UIView *)candidate {
    if(!NSThread.isMainThread || ![candidate isKindOfClass:NSClassFromString(@"AWENavigationBar")])return;
    AWENavigationBar *bar=(id)candidate;
    DYYYMessageHeaderState *state=objc_getAssociatedObject(bar,@selector(synchronizeBar:));
    if(state.busy)return;
    UIViewController *owner=[self owner:bar named:@"AWEIMMessageTabViewController"];
    if(![self topEnabled] || !owner || !bar.window){[state.left removeFromSuperview];[state.right removeFromSuperview];return;}
    UIView *carrier=bar.contentView,*left=nil,*right=nil;
    if(!carrier || carrier.bounds.size.height<32 || carrier.bounds.size.height>64){[state.left removeFromSuperview];[state.right removeFromSuperview];return;}
    for(UIView *view in carrier.subviews){
        if([view isKindOfClass:NSClassFromString(@"AWEIMMessageTabExpandedHitContainerView")])left=view;
        if(view.class==UIView.class && view.bounds.size.width<160){
            NSUInteger buttons=0;for(UIView *child in view.subviews)if([child isKindOfClass:UIControl.class]&&!child.hidden)buttons++;
            if(buttons>=2)right=view;
        }
    }
    if(!left || !right || left.hidden || right.hidden || left.alpha<=0.01 || right.alpha<=0.01){[state.left removeFromSuperview];[state.right removeFromSuperview];return;}
    if(!state){state=[DYYYMessageHeaderState new];state.left=[DYYYChatChrome glassBackgroundWithIdentifier:@"DYads.MessageListLeftGlass"];state.right=[DYYYChatChrome glassBackgroundWithIdentifier:@"DYads.MessageListRightGlass"];objc_setAssociatedObject(bar,@selector(synchronizeBar:),state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self bars] addObject:bar];}
    state.busy=YES;
    @try {
        CGFloat height=MIN(44,carrier.bounds.size.height),y=(carrier.bounds.size.height-height)/2;
        CGRect leftRect=CGRectMake(left.frame.origin.x,y,height,height),rightRect=CGRectMake(right.frame.origin.x,y,right.frame.size.width,height);
        [DYYYChatChrome placeGlassBackground:state.left frame:leftRect inView:carrier];
        [DYYYChatChrome placeGlassBackground:state.right frame:rightRect inView:carrier];
    } @finally {state.busy=NO;}
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
    for(UITableViewCell *cell in [self cells].allObjects)if(cell.window){DYYYMessageCardState *s=objc_getAssociatedObject(cell,@selector(synchronizeCell:));if(s.kind)groups[s.kind]=@([groups[s.kind] unsignedIntegerValue]+1);}
    return @{@"cardsEnabled":@([self cardsEnabled]),@"topEnabled":@([self topEnabled]),@"adapterReady":@([self adapterReady]),@"visibleRowsByGroup":groups,@"nativeRowGeometry":@YES,@"unreadMutation":@NO};
}
@end
