#import "DYYYDetailCaptionLayout.h"
#import "DYYYDetailCaptionMetrics.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYDetailCaptionStateKey;
static char kDYYYDetailCaptionControllerDepthKey;

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
+ (UIView *)pageForController:(UIViewController *)controller {
    Class cellClass = NSClassFromString(@"AWEAwemeDetailCellViewController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController)
        if (cellClass && [controller isKindOfClass:cellClass]) return controller.viewIfLoaded;
    return nil;
}
+ (BOOL)visibleView:(UIView *)view withinPage:(UIView *)page {
    if (!view.window || !page || ![view isDescendantOfView:page]) return NO;
    // 原生会隐藏相邻缓存 Cell；不必等它进入屏幕中央才给页内内容排版。
    for (UIView *parent = view; parent && parent != page; parent = parent.superview)
        if (parent.hidden || parent.alpha <= 0.01) return NO;
    return YES;
}
+ (void)setManagedTransform:(CGAffineTransform)transform view:(UIView *)view {
    if (!CGAffineTransformEqualToTransform(view.transform, transform))
        [UIView performWithoutAnimation:^{ view.transform = transform; }];
}
+ (BOOL)isEmptyProgressPlaceholder:(UIView *)view {
    // 动图保留一个无子视图、无绘制层的 3pt 分页空壳，不是实际分页线。
    CALayer *layer = view.layer;
    CGColorRef background = layer.backgroundColor;
    return !view.subviews.count && !layer.sublayers.count && !layer.contents && !layer.mask &&
        (!background || CGColorGetAlpha(background) <= 0.01) && layer.borderWidth == 0 && layer.shadowOpacity == 0;
}
+ (CGFloat)captionBottomForRow:(UIView *)row inPage:(UIView *)page {
    CGFloat rowBottom = CGRectGetMaxY([row convertRect:row.bounds toView:page]);
    CGFloat textBottom = 0;
    BOOL plainText = YES;
    for (UIView *child in row.subviews) {
        if (child.hidden || child.alpha <= 0.01 || CGRectIsEmpty(child.bounds)) continue;
        if (![child isKindOfClass:UILabel.class]) { plainText = NO; break; }
        textBottom = MAX(textBottom, CGRectGetMaxY([child convertRect:child.bounds toView:page]));
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
            [self setManagedTransform:[saved[@"native"] CGAffineTransformValue] view:view];
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
+ (void)moveView:(UIView *)view down:(CGFloat)shift inPage:(UIView *)page state:(DYYYDetailCaptionState *)state {
    if (!view.superview) return;
    CGPoint zero = [view.superview convertPoint:CGPointZero fromView:page];
    CGPoint moved = [view.superview convertPoint:CGPointMake(0, shift) fromView:page];
    CGAffineTransform native = view.transform, applied = native;
    applied.tx += moved.x - zero.x; applied.ty += moved.y - zero.y;
    [state.transforms setObject:@{@"native": [NSValue valueWithCGAffineTransform:native], @"applied": [NSValue valueWithCGAffineTransform:applied]} forKey:view];
    [self setManagedTransform:applied view:view];
}
+ (void)applyState:(DYYYDetailCaptionState *)state {
    if (!state || state.busy || state.depth) return;
    UIViewController *owner = [DYYYUtils firstAvailableViewControllerFromView:state.stack];
    if ([objc_getAssociatedObject(owner, &kDYYYDetailCaptionControllerDepthKey) unsignedIntegerValue]) return;
    state.busy = YES;
    @try {
        [self restoreState:state];
        state.diagnostics = @{@"active": @NO};
        UIView *stack = state.stack;
        UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:stack];
        UIViewController *detail = [self detailForController:controller];
        state.controller = controller; state.detail = detail;
        UIView *page = [self pageForController:controller];
        if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFloatingCommentInput"] ||
            ![self isAuthorDetail:detail] || ![self isPhotoController:controller] || ![self visibleView:detail.viewIfLoaded] ||
            ![self visibleView:stack withinPage:page]) return;
        UIWindow *window = stack.window;
        if (CGRectGetHeight(window.bounds) <= CGRectGetWidth(window.bounds)) return;
        if (page.window != window || fabs(CGRectGetWidth(page.bounds) - CGRectGetWidth(detail.view.bounds)) > 1) return;
        UIView *input = [self collapsedInputInDetail:detail];
        if (!input || input.window != window) return;
        CGRect inputRect = [input convertRect:input.bounds toView:detail.view];
        CGFloat inputTop = [DYYYDetailCaptionMetrics pageInputTopForViewportInputTop:CGRectGetMinY(inputRect)
            viewportMinY:CGRectGetMinY(detail.view.bounds) viewportHeight:CGRectGetHeight(detail.view.bounds)
            pageMinY:CGRectGetMinY(page.bounds) pageHeight:CGRectGetHeight(page.bounds)];
        if (!isfinite(inputTop)) return;
        CGFloat captionBottom = 0;
        for (UIView *row in stack.subviews) {
            if (row.hidden || row.alpha <= 0.01 || CGRectIsEmpty(row.bounds)) continue;
            captionBottom = MAX(captionBottom, [self captionBottomForRow:row inPage:page]);
        }
        if (captionBottom <= 0) return;
        CGFloat progressBottom = 0;
        CGFloat progressLimit = CGRectGetMaxY([controller.view convertRect:controller.view.bounds toView:page]);
        NSMutableArray<UIView *> *progressViews = [NSMutableArray array];
        Class progressClass = NSClassFromString(@"AWEStoryProgressContainerView");
        Class slideClass = NSClassFromString(@"AWEStoryProgressSlideView");
        BOOL hasProgress = NO;
        NSUInteger emptyProgressCount = 0;
        for (UIView *view in stack.superview.subviews) {
            if (!progressClass || ![view isKindOfClass:progressClass] || ![self visibleView:view withinPage:page] || CGRectIsEmpty(view.bounds)) continue;
            if ([self isEmptyProgressPlaceholder:view]) { emptyProgressCount++; continue; }
            hasProgress = YES;
            for (UIView *slide in view.subviews) {
                if (!slideClass || ![slide isKindOfClass:slideClass] || ![self visibleView:slide withinPage:page]) continue;
                for (UIView *line in slide.subviews) {
                    if (![line isKindOfClass:UICollectionView.class] || ![self visibleView:line withinPage:page] ||
                        CGRectIsEmpty(line.bounds) || CGRectGetHeight(line.bounds) > 8) continue;
                    if (![progressViews containsObject:slide]) [progressViews addObject:slide];
                    progressBottom = MAX(progressBottom, CGRectGetMaxY([line convertRect:line.bounds toView:page]));
                }
            }
        }
        if (hasProgress && !progressViews.count) {
            state.diagnostics = @{@"active": @NO, @"reason": @"unrecognized_progress"};
            return; // 未识别的实际分页布局保留原位。
        }
        if (!isfinite(captionBottom) || !isfinite(progressBottom) || !isfinite(progressLimit)) return;
        CGFloat shift = [DYYYDetailCaptionMetrics downwardShiftForCaptionBottom:captionBottom inputTop:inputTop
            progressBottom:progressBottom progressLimit:progressLimit enabled:YES];
        state.diagnostics = @{@"active": @(shift > 0.1), @"shift": @(shift), @"captionBottom": @(captionBottom),
            @"inputTop": @(inputTop), @"progressBottom": @(progressBottom), @"coordinateSpace": @"detail_cell_page",
            @"progressLimit": @(progressLimit), @"progressCount": @(progressViews.count), @"emptyProgressCount": @(emptyProgressCount)};
        if (shift <= 0.1) return;
        [self moveView:stack down:shift inPage:page state:state];
        for (UIView *progress in progressViews) [self moveView:progress down:shift inPage:page state:state];
    } @finally { state.busy = NO; }
}
+ (void)synchronizeStack:(UIView *)stack {
    if (NSThread.isMainThread) [self applyState:[self stateForStack:stack create:YES]];
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
+ (void)beginControllerLayout:(UIViewController *)controller {
    if (!NSThread.isMainThread || ![self isAuthorDetail:[self detailForController:controller]]) return;
    NSUInteger depth = [objc_getAssociatedObject(controller, &kDYYYDetailCaptionControllerDepthKey) unsignedIntegerValue];
    objc_setAssociatedObject(controller, &kDYYYDetailCaptionControllerDepthKey, @(depth + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!depth) [self restoreController:controller];
}
+ (void)endControllerLayout:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    NSUInteger depth = [objc_getAssociatedObject(controller, &kDYYYDetailCaptionControllerDepthKey) unsignedIntegerValue];
    objc_setAssociatedObject(controller, &kDYYYDetailCaptionControllerDepthKey, depth > 1 ? @(depth - 1) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (depth <= 1) [self synchronizeController:controller];
}
+ (void)synchronizePageController:(UIViewController *)page {
    if (!NSThread.isMainThread || ![self isAuthorDetail:[self detailForController:page]]) return;
    NSMutableArray<UIViewController *> *queue = [NSMutableArray arrayWithObject:page];
    for (NSUInteger index = 0; index < queue.count && index < 64; index++) {
        UIViewController *controller = queue[index];
        if (!controller.isViewLoaded) continue;
        if ([controller isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) [self synchronizeController:controller];
        else [queue addObjectsFromArray:controller.childViewControllers];
    }
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
