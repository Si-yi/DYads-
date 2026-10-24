#import "DYYYSameStyleVisibility.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

static char kDYYYSameStyleVisibilityKey;

@interface DYYYSameStyleVisibilityState : NSObject
@property (nonatomic, assign) BOOL nativeHidden;
@property (nonatomic, assign) BOOL forceHidden;
@property (nonatomic, assign) BOOL applying;
@property (nonatomic, assign) NSUInteger updateDepth;
@end

@implementation DYYYSameStyleVisibilityState
@end

@implementation DYYYSameStyleVisibility

+ (NSHashTable<UIView *> *)views {
    static NSHashTable *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}

+ (DYYYSameStyleVisibilityState *)stateForView:(UIView *)view {
    DYYYSameStyleVisibilityState *state = objc_getAssociatedObject(view, &kDYYYSameStyleVisibilityKey);
    if (!state) {
        state = [DYYYSameStyleVisibilityState new];
        state.nativeHidden = view.hidden;
        objc_setAssociatedObject(view, &kDYYYSameStyleVisibilityKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self views] addObject:view];
    }
    return state;
}

+ (BOOL)isRightSameStyleEntry:(UIView *)view {
    if (![view isKindOfClass:NSClassFromString(@"AWEPlayInteractionSingleSongMusicStyleView")]) return NO;
    BOOL inRightStack = NO;
    for (UIView *parent = view.superview; parent; parent = parent.superview) {
        if ([parent isKindOfClass:NSClassFromString(@"AWEElementStackView")] &&
            [parent.accessibilityLabel isEqualToString:@"right"]) {
            inRightStack = YES;
            break;
        }
    }
    if (!inRightStack) return NO;
    // 同一原生组件也展示普通唱片/听抖音，不能仅凭“音乐详情”或类名隐藏。
    // 导出中“拍同款”的标题和点击遮罩均为该组件的直接子视图。
    for (UIView *child in view.subviews) {
        if (child.hidden || child.alpha <= 0.01) continue;
        if ([child.accessibilityLabel isEqualToString:@"拍同款"]) return YES;
        if ([child isKindOfClass:UILabel.class] && [((UILabel *)child).text isEqualToString:@"拍同款"]) return YES;
    }
    return NO;
}

+ (void)writeHidden:(BOOL)hidden view:(UIView *)view state:(DYYYSameStyleVisibilityState *)state {
    if (view.hidden == hidden) return;
    state.applying = YES;
    @try {
        view.hidden = hidden;
    } @finally {
        state.applying = NO;
    }
}

+ (BOOL)hiddenForView:(UIView *)view nativeHidden:(BOOL)hidden {
    if (!NSThread.isMainThread) return hidden;
    DYYYSameStyleVisibilityState *state = objc_getAssociatedObject(view, &kDYYYSameStyleVisibilityKey);
    if (!state || state.applying) return hidden;
    state.nativeHidden = hidden;
    return hidden || state.forceHidden;
}

+ (void)applyToView:(UIView *)view {
    if (!NSThread.isMainThread || !view) return;
    DYYYSameStyleVisibilityState *state = [self stateForView:view];
    if (state.updateDepth) return;
    state.forceHidden = view.window && DYYYGetBool(@"DYYYHideSameStyleButton") && [self isRightSameStyleEntry:view];
    // 隐藏完整组件，连同越出唱片范围的标题与点击遮罩；不移除视图或改约束。
    [self writeHidden:(state.nativeHidden || state.forceHidden) view:view state:state];
}

+ (void)beginNativeUpdate:(UIView *)view {
    if (!NSThread.isMainThread || !view) return;
    DYYYSameStyleVisibilityState *state = [self stateForView:view];
    if (!state.updateDepth++) {
        state.forceHidden = NO;
        [self writeHidden:state.nativeHidden view:view state:state];
    }
}

+ (void)endNativeUpdate:(UIView *)view {
    if (!NSThread.isMainThread || !view) return;
    DYYYSameStyleVisibilityState *state = [self stateForView:view];
    if (state.updateDepth) state.updateDepth--;
    if (!state.updateDepth) [self applyToView:view];
}

+ (void)refreshVisibleViews {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisibleViews]; });
        return;
    }
    for (UIView *view in [self views].allObjects) [self applyToView:view];
}
@end
