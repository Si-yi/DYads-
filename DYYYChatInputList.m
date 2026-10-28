/*
消息列表底部延伸与滚动补偿参考 DYKiller ChatInput/DKChatInputList.xm：
https://github.com/HierarchThurs/DYKiller/blob/261c2d565798237d9d4192a9ee712393838b6e1a/src/Features/ChatInput/DKChatInputList.xm
按独立开关适配聊天输入底部与透明顶栏后方列表，不改变输入行位置。

MIT License

Copyright (c) 2026 Hierarch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
#import "DYYYChatInputList.h"
#import "DYYYChatInputMetrics.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYChatListStateKey;

@interface DYYYChatListState : NSObject
@property (nonatomic, weak) AWEIMMessageBaseViewController *host;
@property (nonatomic, weak) IESIMInputViewController *input;
@property (nonatomic, weak) UIView *container;
@property (nonatomic, weak) UITableView *table;
@property (nonatomic) CGRect nativeContainerFrame;
@property (nonatomic) CGRect nativeTableFrame;
@property (nonatomic) CGRect appliedContainerFrame;
@property (nonatomic) CGRect appliedTableFrame;
@property (nonatomic) UIEdgeInsets nativeInset;
@property (nonatomic) UIEdgeInsets nativeIndicator;
@property (nonatomic) UIEdgeInsets appliedInset;
@property (nonatomic) UIEdgeInsets appliedIndicator;
@property (nonatomic) CGFloat extension;
@property (nonatomic) CGFloat topExtension;
@property (nonatomic) BOOL topActive;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) BOOL busy;
@property (nonatomic) BOOL glassActive;
@end
@implementation DYYYChatListState
@end

@implementation DYYYChatInputList
+ (NSHashTable *)states {
    static NSHashTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}
+ (AWEIMMessageBaseViewController *)hostForInput:(UIViewController *)input {
    Class hostClass = NSClassFromString(@"AWEIMMessageBaseViewController");
    for (NSUInteger depth = 0; input && depth < 10; depth++, input = input.parentViewController)
        if (hostClass && [input isKindOfClass:hostClass]) return (id)input;
    return nil;
}
+ (DYYYChatListState *)stateForHost:(AWEIMMessageBaseViewController *)host create:(BOOL)create {
    if (!host) return nil;
    DYYYChatListState *state = objc_getAssociatedObject(host, &kDYYYChatListStateKey);
    if (!state && create) {
        state = [DYYYChatListState new];
        state.host = host;
        objc_setAssociatedObject(host, &kDYYYChatListStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self states] addObject:state];
    }
    return state;
}
+ (void)restoreState:(DYYYChatListState *)state {
    if (!state || (state.extension <= 0 && state.topExtension <= 0)) return;
    CGFloat top = state.topExtension;
    state.topExtension = 0;
    state.extension = 0; // 原生 setter 引发的嵌套回调不能再次扣除。
    UIView *container = state.container;
    UITableView *table = state.table;
    CGPoint offset = table.contentOffset;
    if (fabs(container.frame.origin.y - state.appliedContainerFrame.origin.y) < 0.5) offset.y += top;
    // 非本模块写入的新值由原生接管；不拿旧快照覆盖旋转/键盘的新尺寸。
    CGRect containerFrame = container.frame;
    CGRect tableFrame = table.frame;
    if (fabs(containerFrame.origin.y - state.appliedContainerFrame.origin.y) < 0.5)
        containerFrame.origin.y = state.nativeContainerFrame.origin.y;
    if (fabs(containerFrame.size.height - state.appliedContainerFrame.size.height) < 0.5) {
        containerFrame.size.height = state.nativeContainerFrame.size.height;
    }
    if (!CGRectEqualToRect(container.frame, containerFrame)) container.frame = containerFrame;
    if (fabs(tableFrame.size.height - state.appliedTableFrame.size.height) < 0.5) {
        tableFrame.size.height = state.nativeTableFrame.size.height;
        table.frame = tableFrame;
    }
    UIEdgeInsets inset = table.contentInset;
    if (fabs(inset.top - state.appliedInset.top) < 0.5) inset.top = state.nativeInset.top;
    if (fabs(inset.bottom - state.appliedInset.bottom) < 0.5) {
        inset.bottom = state.nativeInset.bottom;
    }
    if (!UIEdgeInsetsEqualToEdgeInsets(table.contentInset, inset)) table.contentInset = inset;
    UIEdgeInsets indicator = table.verticalScrollIndicatorInsets;
    if (fabs(indicator.top - state.appliedIndicator.top) < 0.5) indicator.top = state.nativeIndicator.top;
    if (fabs(indicator.bottom - state.appliedIndicator.bottom) < 0.5) {
        indicator.bottom = state.nativeIndicator.bottom;
    }
    if (!UIEdgeInsetsEqualToEdgeInsets(table.verticalScrollIndicatorInsets, indicator)) table.verticalScrollIndicatorInsets = indicator;
    if (!CGPointEqualToPoint(table.contentOffset, offset)) table.contentOffset = offset;
}
+ (void)applyState:(DYYYChatListState *)state {
    if (!state || state.busy || state.depth) return;
    state.busy = YES;
    @try {
        AWEIMMessageBaseViewController *host = state.host;
        IESIMInputViewController *input = state.input;
        BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"];
        BOOL folded = [input respondsToSelector:@selector(currentInputType)] &&
            (input.currentInputType == 0 || input.currentInputType == 3);
        BOOL bottomWanted = enabled && state.glassActive && input.viewIfLoaded.window && folded;
        BOOL topWanted = state.topActive && [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableChatTopGlass"];
        if ((!bottomWanted && !topWanted) || !host.viewIfLoaded.window) {
            [self restoreState:state];
            return;
        }
        UIViewController *list = [host respondsToSelector:@selector(messageListVC)] ? host.messageListVC : nil;
        Class listClass = NSClassFromString(@"AWEIMMessageListViewController");
        UITableView *table = listClass && [list isKindOfClass:listClass] && [list respondsToSelector:@selector(tableView)]
            ? ((AWEIMMessageListViewController *)list).tableView : nil;
        UIView *container = list.viewIfLoaded;
        UIView *root = host.viewIfLoaded;
        if (![table isKindOfClass:UITableView.class] || table.superview != container || container.superview != root ||
            (bottomWanted && input.view.superview != root) || CGRectGetHeight(root.bounds) <= CGRectGetWidth(root.bounds) ||
            !CGAffineTransformIsIdentity(table.transform) || !CGAffineTransformIsIdentity(container.transform)) {
            [self restoreState:state];
            return;
        }
        // 同一原生几何只延伸一次；输入框自身 layout 不反复拆建视口。
        if ((state.extension > 0 || state.topExtension > 0) && state.container == container && state.table == table &&
            CGRectEqualToRect(container.frame, state.appliedContainerFrame) && CGRectEqualToRect(table.frame, state.appliedTableFrame) &&
            UIEdgeInsetsEqualToEdgeInsets(table.contentInset, state.appliedInset) &&
            UIEdgeInsetsEqualToEdgeInsets(table.verticalScrollIndicatorInsets, state.appliedIndicator) &&
            (topWanted == (state.topExtension > 0)) && (bottomWanted == (state.extension > 0))) return;
        [self restoreState:state];
        CGRect frame = container.frame;
        CGRect tableFrame = table.frame;
        if (fabs(tableFrame.origin.y - container.bounds.origin.y) > 1 || fabs(tableFrame.origin.x - container.bounds.origin.x) > 1 ||
            fabs(CGRectGetWidth(tableFrame) - CGRectGetWidth(container.bounds)) > 1 ||
            fabs(CGRectGetHeight(tableFrame) - CGRectGetHeight(container.bounds)) > 1 ||
            fabs(CGRectGetWidth(frame) - CGRectGetWidth(root.bounds)) > 1) return;
        CGFloat extension = bottomWanted ? [DYYYChatInputMetrics bottomExtensionForHostBottom:CGRectGetMaxY(root.bounds)
            listTop:CGRectGetMinY(frame) listBottom:CGRectGetMaxY(frame) inputTop:CGRectGetMinY(input.view.frame)
            inputBottom:CGRectGetMaxY(input.view.frame) folded:folded] : 0;
        CGFloat top = topWanted ? CGRectGetMinY(frame) - CGRectGetMinY(root.bounds) : 0;
        if (!isfinite(top) || top < 0 || top > 180) top = 0;
        if (extension <= 0 && top <= 0) return;
        UIEdgeInsets inset = table.contentInset;
        UIEdgeInsets indicator = table.verticalScrollIndicatorInsets;
        if (!isfinite(inset.bottom) || !isfinite(indicator.bottom) || !isfinite(inset.top) || !isfinite(indicator.top)) return;
        CGPoint offset = table.contentOffset;
        state.container = container;
        state.table = table;
        state.nativeContainerFrame = frame;
        state.nativeTableFrame = tableFrame;
        state.nativeInset = inset;
        state.nativeIndicator = indicator;
        frame.origin.y -= top;
        frame.size.height += extension + top;
        tableFrame.size.height += extension + top;
        inset.top += top;
        indicator.top += top;
        offset.y -= top;
        inset.bottom += extension;
        indicator.bottom += extension;
        state.appliedContainerFrame = frame;
        state.appliedTableFrame = tableFrame;
        state.appliedInset = inset;
        state.appliedIndicator = indicator;
        state.extension = extension;
        state.topExtension = top;
        container.frame = frame;
        table.frame = tableFrame;
        table.contentInset = inset;
        table.verticalScrollIndicatorInsets = indicator;
        // 保留阅读位置；高度与底部留白同量增加，最后一条消息仍可滚到输入框上方。
        if (!CGPointEqualToPoint(table.contentOffset, offset)) table.contentOffset = offset;
    } @finally { state.busy = NO; }
}
+ (void)synchronizeInputController:(UIViewController *)input active:(BOOL)active {
    if (!NSThread.isMainThread) return;
    DYYYChatListState *state = [self stateForHost:[self hostForInput:input] create:active];
    if (!state) return;
    state.input = (id)input;
    state.glassActive = active;
    [UIView performWithoutAnimation:^{ [self applyState:state]; }];
}
+ (void)synchronizeHost:(UIViewController *)host topActive:(BOOL)active {
    if (!NSThread.isMainThread) return;
    DYYYChatListState *state = [self stateForHost:(id)host create:active];
    if (!state) return;
    state.topActive = active;
    [UIView performWithoutAnimation:^{ [self applyState:state]; }];
}
+ (id)beginNativeLayoutForComponent:(id)component {
    if (!NSThread.isMainThread || ![component respondsToSelector:@selector(context)]) return nil;
    id context = ((AWEIMComponentBase *)component).context;
    UIViewController *host = [context respondsToSelector:@selector(hostViewController)] ? [context hostViewController] : nil;
    if (!host || ![host isKindOfClass:NSClassFromString(@"AWEIMMessageBaseViewController")]) return nil;
    DYYYChatListState *state = [self stateForHost:(id)host create:[NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingChatInput"]];
    if (!state || state.busy) return nil;
    if (state.depth++ == 0) {
        state.busy = YES;
        @try { [UIView performWithoutAnimation:^{ [self restoreState:state]; }]; }
        @finally { state.busy = NO; }
    }
    return state;
}
+ (void)endNativeLayout:(id)token {
    if (!NSThread.isMainThread || ![token isKindOfClass:DYYYChatListState.class]) return;
    DYYYChatListState *state = token;
    if (state.depth) state.depth--;
    if (!state.depth) [UIView performWithoutAnimation:^{ [self applyState:state]; }];
}
+ (CGRect)frameForBottomTips:(UIView *)tips proposedFrame:(CGRect)frame {
    if (!NSThread.isMainThread || fabs(frame.origin.y - tips.frame.origin.y) < 0.5) return frame;
    UIViewController *list = (id)tips.superview.nextResponder;
    if (![list isKindOfClass:NSClassFromString(@"AWEIMMessageListViewController")]) return frame;
    DYYYChatListState *state = [self stateForHost:[self hostForInput:list] create:NO];
    if (state && !state.busy && !state.depth && state.container == tips.superview) frame.origin.y += state.topExtension - state.extension;
    return frame;
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSMutableArray *result = [NSMutableArray array];
    for (DYYYChatListState *state in [self states].allObjects) {
        if (!state.host.viewIfLoaded.window) continue;
        [result addObject:@{ @"extension": @(state.extension), @"topExtension": @(state.topExtension), @"listFrame": NSStringFromCGRect(state.container.frame),
            @"tableFrame": NSStringFromCGRect(state.table.frame), @"bottomInset": @(state.table.contentInset.bottom),
            @"inputType": @([state.input respondsToSelector:@selector(currentInputType)] ? state.input.currentInputType : -1) }];
    }
    Class layout = NSClassFromString(@"AWEIMMessageListLayoutComponent");
    return @{ @"states": result, @"layoutClassAvailable": @(layout != Nil),
        @"snapshotLayoutAvailable": @([layout instancesRespondToSelector:@selector(p_layoutWithAnimation:coordinate:)]),
        @"pageLayoutAvailable": @([layout instancesRespondToSelector:@selector(updatePageLayout:)]) };
}
@end
