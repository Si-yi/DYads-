/*
评论缩放抑制参考 HierarchThurs/DYKiller 的 DKVideoGeometry.xm / DKVideoPageChrome.xm，
使用独立偏好键，不改变首页全屏及评论毛玻璃开关。
https://github.com/HierarchThurs/DYKiller

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
#import "DYYYCommentVideoLayout.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYCommentVideoStateKey;

@interface DYYYCommentVideoState : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) UIView *gradient;
@property (nonatomic) CGRect nativeFrame;
@property (nonatomic) CGRect appliedFrame;
@property (nonatomic) CGFloat gradientAlpha;
@property (nonatomic) BOOL hasFrame;
@property (nonatomic) BOOL hasGradient;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYCommentVideoState
@end

@implementation DYYYCommentVideoLayout
+ (BOOL)enabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDisableCommentVideoShrink"];
}
+ (NSHashTable *)states {
    static NSHashTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}
+ (DYYYCommentVideoState *)stateForView:(UIView *)view create:(BOOL)create {
    DYYYCommentVideoState *state = objc_getAssociatedObject(view, &kDYYYCommentVideoStateKey);
    if (!state && create && view) {
        state = [DYYYCommentVideoState new];
        state.view = view;
        objc_setAssociatedObject(view, &kDYYYCommentVideoStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self states] addObject:state];
    }
    return state;
}
+ (BOOL)isContentController:(id)controller {
    for (NSString *name in @[@"AWEDPlayerViewController_Merge", @"AWEDPlayerFeedPlayerViewController",
        @"AWEAwemePlayVideoViewController", @"RichContentContainerViewController"]) {
        Class cls = NSClassFromString(name);
        if (cls && [controller isKindOfClass:cls]) return YES;
    }
    return NO;
}
+ (BOOL)eligibleController:(UIViewController *)controller {
    UIView *view = controller.viewIfLoaded;
    // PiP/系统横屏浮窗独立管理自己的尺寸，不能撑成视频页。
    return [self isContentController:controller] && view.superview &&
        CGRectGetWidth(view.bounds) > 0 && CGRectGetHeight(view.bounds) > 0 && CGAffineTransformIsIdentity(view.transform) &&
        (!view.window || view.window.windowLevel == UIWindowLevelNormal);
}
+ (CGRect)targetFrameForView:(UIView *)view proposed:(CGRect)frame {
    UIView *parent = view.superview;
    CGRect target = parent.bounds;
    if (!parent || !isfinite(target.origin.x) || !isfinite(target.origin.y) || !isfinite(target.size.width) ||
        !isfinite(target.size.height) || target.size.width <= 0 || target.size.height <= 0) return CGRectNull;
    // 私信视频已有全屏补高：缩小来意沿用之前已批准的满宽空间，不能缩掉回复栏预留。
    CGRect candidate = frame;
    if (fabs(candidate.origin.x - target.origin.x) > 0.5 || fabs(candidate.origin.y - target.origin.y) > 0.5 ||
        fabs(candidate.size.width - target.size.width) > 0.5) candidate = view.frame;
    if (fabs(candidate.origin.x - target.origin.x) <= 0.5 && fabs(candidate.origin.y - target.origin.y) <= 0.5 &&
        fabs(candidate.size.width - target.size.width) <= 0.5 && isfinite(candidate.size.height) &&
        candidate.size.height > target.size.height && candidate.size.height <= target.size.height + 160)
        target.size.height = candidate.size.height;
    return target;
}
+ (void)restoreState:(DYYYCommentVideoState *)state {
    if (!state || state.busy) return;
    state.busy = YES;
    @try {
        UIView *view = state.view;
        if (state.hasFrame && CGRectEqualToRect(view.frame, state.appliedFrame) && !CGRectEqualToRect(view.frame, state.nativeFrame))
            view.frame = state.nativeFrame;
        if (state.hasGradient && state.gradient.alpha == 1) state.gradient.alpha = state.gradientAlpha;
        state.hasFrame = NO;
        state.hasGradient = NO;
        state.gradient = nil;
    } @finally { state.busy = NO; }
}
+ (CGRect)adjustedFrame:(CGRect)frame view:(UIView *)view {
    if (!NSThread.isMainThread || ![self enabled] || !isfinite(frame.origin.x) || !isfinite(frame.origin.y) ||
        !isfinite(frame.size.width) || !isfinite(frame.size.height) || frame.size.width <= 0 || frame.size.height <= 0) return frame;
    // 只处理控制器自己的根视图，绝不把播放器子树、按钮或文字拉成全屏。
    UIResponder *owner = view.nextResponder;
    if (![owner isKindOfClass:UIViewController.class] || ((UIViewController *)owner).viewIfLoaded != view ||
        ![self eligibleController:(id)owner]) return frame;
    DYYYCommentVideoState *state = [self stateForView:view create:YES];
    if (state.busy) return frame;
    CGRect target = [self targetFrameForView:view proposed:frame];
    if (CGRectIsNull(target)) return frame;
    state.nativeFrame = frame;
    state.appliedFrame = target;
    state.hasFrame = YES;
    // 原生 setFrame 仍执行，只在唯一背景容器上换算来意，避免布局请求被吞掉。
    return target;
}
+ (void)synchronizeController:(UIViewController *)controller {
    if (!NSThread.isMainThread || ![self isContentController:controller]) return;
    UIView *view = controller.viewIfLoaded;
    DYYYCommentVideoState *state = [self stateForView:view create:NO];
    if (![self enabled]) { [self restoreState:state]; return; }
    if (![self eligibleController:controller] || state.busy) return;
    CGRect target = [self targetFrameForView:view proposed:view.frame];
    if (CGRectIsNull(target) || CGRectEqualToRect(target, view.frame)) return;
    state = [self stateForView:view create:YES];
    if (!state.hasFrame) state.nativeFrame = view.frame;
    state.appliedFrame = target;
    state.hasFrame = YES;
    state.busy = YES;
    @try { view.frame = target; } @finally { state.busy = NO; }
}
+ (BOOL)freezeController:(UIViewController *)controller {
    if (!NSThread.isMainThread || ![self enabled] || ![self eligibleController:controller]) return NO;
    [self synchronizeController:controller];
    if ([controller respondsToSelector:@selector(gradientBackgroundView)]) {
        UIView *gradient = ((AWEDPlayerViewController_Merge *)controller).gradientBackgroundView;
        if (gradient && gradient.alpha < 1) {
            DYYYCommentVideoState *state = [self stateForView:controller.viewIfLoaded create:YES];
            state.gradient = gradient;
            state.gradientAlpha = gradient.alpha;
            state.hasGradient = YES;
            gradient.alpha = 1;
        }
    }
    return YES;
}
+ (void)didMagnifyController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYCommentVideoState *state = [self stateForView:controller.viewIfLoaded create:NO];
    // 关闭评论后的背景由原生 magnify 回调决定，不能在以后关闭开关时还原旧的缩小态 alpha。
    state.hasGradient = NO;
    state.gradient = nil;
    [self synchronizeController:controller];
}
+ (void)refreshVisiblePlayers {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisiblePlayers]; });
        return;
    }
    if (![self enabled]) {
        for (DYYYCommentVideoState *state in [self states].allObjects) [self restoreState:state];
        return;
    }
    // 仅用户切换设置时做一次有界控制器遍历；不轮询、不加载未显示的 view。
    UIViewController *root = [DYYYUtils getActiveWindow].rootViewController;
    NSMutableArray *queue = [NSMutableArray array];
    if (root) [queue addObject:root];
    for (NSUInteger index = 0; index < queue.count && index < 128; index++) {
        UIViewController *controller = queue[index];
        [self synchronizeController:controller];
        for (UIViewController *child in controller.childViewControllers)
            if (![queue containsObject:child] && queue.count < 128) [queue addObject:child];
    }
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSMutableArray *frames = [NSMutableArray array];
    for (DYYYCommentVideoState *state in [self states].allObjects) {
        if (!state.view.window || !state.hasFrame) continue;
        [frames addObject:@{ @"nativeFrame": NSStringFromCGRect(state.nativeFrame),
            @"appliedFrame": NSStringFromCGRect(state.appliedFrame), @"actualFrame": NSStringFromCGRect(state.view.frame) }];
    }
    return @{ @"enabled": @([self enabled]), @"frames": frames };
}
@end
