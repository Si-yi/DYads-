#import "DYYYDetailCaptionLayout.h"
#import "DYYYDetailCaptionMetrics.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYDetailCaptionStateKey;

@interface DYYYDetailCaptionState : NSObject
@property (nonatomic, weak) UIView *stack;
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UIViewController *detail;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *transforms;
@property (nonatomic, copy) NSDictionary *diagnostics;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) BOOL busy;
@end
@implementation DYYYDetailCaptionState
@end

@implementation DYYYDetailCaptionLayout
+ (NSHashTable<DYYYDetailCaptionState *> *)states {
    static NSHashTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}
+ (UIViewController *)detailForController:(UIViewController *)controller {
    Class detailClass = NSClassFromString(@"AWEAwemeDetailTableViewController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController)
        if (detailClass && [controller isKindOfClass:detailClass]) return controller;
    return nil;
}
+ (BOOL)isAuthorDetail:(UIViewController *)detail {
    if (!detail) return NO;
    NSArray *pages = detail.navigationController.viewControllers;
    NSUInteger index = [pages indexOfObjectIdenticalTo:detail];
    if (index == NSNotFound || index == 0) return NO;
    UIViewController *source = pages[index - 1];
    Class author = NSClassFromString(@"AWEUserDetailViewControllerV2");
    Class own = NSClassFromString(@"AWEUserHomeViewControllerV2");
    return (author && [source isKindOfClass:author]) || (own && [source isKindOfClass:own]);
}
+ (BOOL)isPhotoController:(UIViewController *)controller {
    if (![controller isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) return NO;
    AWEAwemeModel *model = ((AWEPlayInteractionViewController *)controller).model;
    if (!model) return NO;
    BOOL live = [model respondsToSelector:@selector(isLivePhoto)] && model.isLivePhoto;
    BOOL animated = [model respondsToSelector:@selector(animatedImageVideoInfo)] && model.video && model.animatedImageVideoInfo;
    return model.awemeType == 68 || live || animated;
}
+ (BOOL)visibleView:(UIView *)view {
    if (!view.window) return NO;
    for (UIView *parent = view; parent; parent = parent.superview)
        if (parent.hidden || parent.alpha <= 0.01) return NO;
    return YES;
}
+ (BOOL)isEmptyProgressPlaceholder:(UIView *)view {
    // 动图保留一个无子视图、无绘制层的 3pt 分页空壳，不是实际分页线。
    CALayer *layer = view.layer;
    CGColorRef background = layer.backgroundColor;
    return !view.subviews.count && !layer.sublayers.count && !layer.contents && !layer.mask &&
        (!background || CGColorGetAlpha(background) <= 0.01) && layer.borderWidth == 0 && layer.shadowOpacity == 0;
}
+ (CGFloat)captionBottomForRow:(UIView *)row inDetail:(UIViewController *)detail {
    CGFloat rowBottom = CGRectGetMaxY([row convertRect:row.bounds toView:detail.view]);
    CGFloat textBottom = 0;
    BOOL plainText = YES;
    for (UIView *child in row.subviews) {
        if (child.hidden || child.alpha <= 0.01 || CGRectIsEmpty(child.bounds)) continue;
        if (![child isKindOfClass:UILabel.class]) { plainText = NO; break; }
        textBottom = MAX(textBottom, CGRectGetMaxY([child convertRect:child.bounds toView:detail.view]));
    }
    return [DYYYDetailCaptionMetrics captionBottomForRowBottom:rowBottom plainTextBottom:plainText && textBottom > 0 ? textBottom : NAN];
}
+ (UIView *)collapsedInputInDetail:(UIViewController *)detail {
    Class backgroundClass = NSClassFromString(@"AWECommentInputBackgroundView");
    for (UIView *root in detail.viewIfLoaded.subviews) {
        if (!backgroundClass || ![root isKindOfClass:backgroundClass] || ![self visibleView:root]) continue;
        NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
        UIView *chrome = nil;
        for (NSUInteger index = 0; index < queue.count && index < 128; index++) {
            UIView *view = queue[index];
            if (view.hidden || view.alpha <= 0.01) continue;
            if (view.isFirstResponder) return nil;
            NSString *name = NSStringFromClass(view.class);
            if ([name isEqualToString:@"AWECommentInputViewSwiftImpl.CommentInputContainerView"] && CGRectGetHeight(view.bounds) > 120) return nil;
            if ([name isEqualToString:@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer"] && CGRectGetHeight(view.bounds) > 64) return nil;
            if ([view.accessibilityIdentifier isEqualToString:@"DYYY.AdaptiveCommentInput.r9"]) { chrome = view; continue; }
            [queue addObjectsFromArray:view.subviews];
        }
        if (chrome && [self visibleView:chrome] && CGRectGetHeight(chrome.bounds) >= 30 && CGRectGetHeight(chrome.bounds) <= 64) return chrome;
    }
    return nil;
}
+ (void)restoreState:(DYYYDetailCaptionState *)state {
    for (UIView *view in state.transforms.keyEnumerator.allObjects) {
        NSDictionary *saved = [state.transforms objectForKey:view];
        if (CGAffineTransformEqualToTransform(view.transform, [saved[@"applied"] CGAffineTransformValue]))
            view.transform = [saved[@"native"] CGAffineTransformValue];
    }
    [state.transforms removeAllObjects];
}
+ (DYYYDetailCaptionState *)stateForStack:(UIView *)stack create:(BOOL)create {
    DYYYDetailCaptionState *state = objc_getAssociatedObject(stack, &kDYYYDetailCaptionStateKey);
    if (state || !create || ![stack.accessibilityLabel isEqualToString:@"left"] ||
        ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingCommentInput"]) return state;
    UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:stack];
    UIViewController *detail = [self detailForController:controller];
    if (![self isAuthorDetail:detail] || ![self isPhotoController:controller]) return nil;
    state = [DYYYDetailCaptionState new];
    state.stack = stack; state.controller = controller; state.detail = detail;
    state.transforms = [NSMapTable weakToStrongObjectsMapTable];
    objc_setAssociatedObject(stack, &kDYYYDetailCaptionStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self states] addObject:state];
    return state;
}
+ (void)moveView:(UIView *)view down:(CGFloat)shift inDetail:(UIViewController *)detail state:(DYYYDetailCaptionState *)state {
    if (!view.superview) return;
    CGPoint zero = [view.superview convertPoint:CGPointZero fromView:detail.view];
    CGPoint moved = [view.superview convertPoint:CGPointMake(0, shift) fromView:detail.view];
    CGAffineTransform native = view.transform, applied = native;
    applied.tx += moved.x - zero.x; applied.ty += moved.y - zero.y;
    [state.transforms setObject:@{@"native": [NSValue valueWithCGAffineTransform:native], @"applied": [NSValue valueWithCGAffineTransform:applied]} forKey:view];
    view.transform = applied;
}
+ (void)applyState:(DYYYDetailCaptionState *)state {
    if (!state || state.busy || state.depth) return;
    state.busy = YES;
    @try {
        [self restoreState:state];
        state.diagnostics = @{@"active": @NO};
        UIView *stack = state.stack;
        UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:stack];
        UIViewController *detail = [self detailForController:controller];
        state.controller = controller; state.detail = detail;
        if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingCommentInput"] ||
            ![self isAuthorDetail:detail] || ![self isPhotoController:controller] || ![self visibleView:stack]) return;
        UIWindow *window = stack.window;
        if (CGRectGetHeight(window.bounds) <= CGRectGetWidth(window.bounds)) return;
        CGRect visible = [controller.view convertRect:controller.view.bounds toView:window];
        CGPoint center = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds));
        if (!CGRectContainsPoint(visible, center)) return;
        UIView *input = [self collapsedInputInDetail:detail];
        if (!input || input.window != window) return;
        CGRect inputRect = [input convertRect:input.bounds toView:detail.view];
        CGFloat captionBottom = 0;
        for (UIView *row in stack.subviews) {
            if (row.hidden || row.alpha <= 0.01 || CGRectIsEmpty(row.bounds)) continue;
            captionBottom = MAX(captionBottom, [self captionBottomForRow:row inDetail:detail]);
        }
        if (captionBottom <= 0) return;
        CGFloat progressBottom = 0;
        CGFloat progressLimit = CGRectGetMaxY([controller.view convertRect:controller.view.bounds toView:detail.view]);
        NSMutableArray<UIView *> *progressViews = [NSMutableArray array];
        Class progressClass = NSClassFromString(@"AWEStoryProgressContainerView");
        Class slideClass = NSClassFromString(@"AWEStoryProgressSlideView");
        BOOL hasProgress = NO;
        NSUInteger emptyProgressCount = 0;
        for (UIView *view in stack.superview.subviews) {
            if (!progressClass || ![view isKindOfClass:progressClass] || ![self visibleView:view] || CGRectIsEmpty(view.bounds)) continue;
            if ([self isEmptyProgressPlaceholder:view]) { emptyProgressCount++; continue; }
            hasProgress = YES;
            for (UIView *slide in view.subviews) {
                if (!slideClass || ![slide isKindOfClass:slideClass] || ![self visibleView:slide]) continue;
                for (UIView *line in slide.subviews) {
                    if (![line isKindOfClass:UICollectionView.class] || ![self visibleView:line] ||
                        CGRectIsEmpty(line.bounds) || CGRectGetHeight(line.bounds) > 8) continue;
                    if (![progressViews containsObject:slide]) [progressViews addObject:slide];
                    progressBottom = MAX(progressBottom, CGRectGetMaxY([line convertRect:line.bounds toView:detail.view]));
                }
            }
        }
        if (hasProgress && !progressViews.count) {
            state.diagnostics = @{@"active": @NO, @"reason": @"unrecognized_progress"};
            return; // 未识别的实际分页布局保留原位。
        }
        if (!isfinite(captionBottom) || !isfinite(CGRectGetMinY(inputRect)) || !isfinite(progressBottom) || !isfinite(progressLimit)) return;
        CGFloat shift = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:captionBottom inputTop:CGRectGetMinY(inputRect)
            progressBottom:progressBottom progressLimit:progressLimit enabled:YES];
        state.diagnostics = @{@"active": @(shift > 0.1), @"shift": @(shift), @"captionBottom": @(captionBottom),
            @"inputTop": @(CGRectGetMinY(inputRect)), @"progressBottom": @(progressBottom),
            @"progressLimit": @(progressLimit), @"progressCount": @(progressViews.count), @"emptyProgressCount": @(emptyProgressCount)};
        if (shift <= 0.1) return;
        [self moveView:stack down:shift inDetail:detail state:state];
        for (UIView *progress in progressViews) [self moveView:progress down:shift inDetail:detail state:state];
    } @finally { state.busy = NO; }
}
+ (void)beginStackLayout:(UIView *)stack {
    if (!NSThread.isMainThread) return;
    DYYYDetailCaptionState *state = [self stateForStack:stack create:YES];
    if (!state || state.busy) return;
    if (state.depth++ == 0) [self restoreState:state];
}
+ (void)endStackLayout:(UIView *)stack {
    if (!NSThread.isMainThread) return;
    DYYYDetailCaptionState *state = [self stateForStack:stack create:NO];
    if (!state || state.busy) return;
    if (state.depth) state.depth--;
    if (!state.depth) [self applyState:state];
}
+ (void)restoreStack:(UIView *)stack {
    if (!NSThread.isMainThread) return;
    DYYYDetailCaptionState *state = [self stateForStack:stack create:NO];
    if (state && !state.busy) [self restoreState:state];
}
+ (void)synchronizeController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller.isViewLoaded) return;
    Class stackClass = NSClassFromString(@"AWEElementStackView");
    for (UIView *view in controller.view.subviews)
        if (stackClass && [view isKindOfClass:stackClass] && [view.accessibilityLabel isEqualToString:@"left"])
            [self applyState:[self stateForStack:view create:YES]];
}
+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    for (DYYYDetailCaptionState *state in [self states].allObjects)
        if (state.controller == controller && !state.busy) [self restoreState:state];
}
+ (void)synchronizeInputRoot:(UIView *)root {
    if (!NSThread.isMainThread || !root) return;
    UIViewController *detail = nil;
    for (UIView *view = root; view && !detail; view = view.superview)
        detail = [self detailForController:[DYYYUtils firstAvailableViewControllerFromView:view]];
    if (!detail) return;
    for (DYYYDetailCaptionState *state in [self states].allObjects)
        if (state.detail == detail) [self applyState:state];
}
+ (NSDictionary *)diagnostics {
    NSMutableArray *visible = [NSMutableArray array];
    for (DYYYDetailCaptionState *state in [self states].allObjects)
        if (state.stack.window && state.diagnostics) [visible addObject:state.diagnostics];
    return @{@"states": visible};
}
@end
