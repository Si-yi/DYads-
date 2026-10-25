#import "DYYYSameStyleVisibility.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

static char kDYYYSameStyleOriginalsKey;
static char kDYYYSameStyleUpdateDepthKey;

@implementation DYYYSameStyleVisibility

+ (NSHashTable<UIView *> *)views {
    static NSHashTable *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}

+ (BOOL)isRightMusicView:(UIView *)view {
    if (![view isKindOfClass:NSClassFromString(@"AWEPlayInteractionSingleSongMusicStyleView")]) return NO;
    for (UIView *parent = view.superview; parent; parent = parent.superview) {
        if ([parent isKindOfClass:NSClassFromString(@"AWEElementStackView")] &&
            [parent.accessibilityLabel isEqualToString:@"right"]) return YES;
    }
    return NO;
}

+ (void)restoreView:(UIView *)view {
    NSMapTable<UILabel *, NSNumber *> *originals = objc_getAssociatedObject(view, &kDYYYSameStyleOriginalsKey);
    objc_setAssociatedObject(view, &kDYYYSameStyleOriginalsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UILabel *label in originals.keyEnumerator.allObjects) {
        if (label.hidden) label.hidden = [[originals objectForKey:label] boolValue];
    }
}

+ (void)applyToView:(UIView *)view {
    if (!NSThread.isMainThread || !view) return;
    if ([objc_getAssociatedObject(view, &kDYYYSameStyleUpdateDepthKey) unsignedIntegerValue]) return;
    [[self views] addObject:view];
    if (!view.window || !DYYYGetBool(@"DYYYHideSameStyleButton") || ![self isRightMusicView:view]) {
        [self restoreView:view];
        return;
    }
    NSMapTable<UILabel *, NSNumber *> *originals = objc_getAssociatedObject(view, &kDYYYSameStyleOriginalsKey);
    // 组件中的标题不再按文案匹配：拍同款、玩同款、听音乐等均只隐藏文字。
    // 保留按钮/缩略图/点击遮罩及无障碍动作。当前已确认文字均为直接子 UILabel。
    for (UILabel *label in originals.keyEnumerator.allObjects) {
        if (label.superview == view) continue;
        if (label.hidden) label.hidden = [[originals objectForKey:label] boolValue];
        [originals removeObjectForKey:label];
    }
    for (UIView *child in view.subviews) {
        if (![child isKindOfClass:UILabel.class]) continue;
        UILabel *label = (UILabel *)child;
        if (!originals) {
            originals = [NSMapTable weakToStrongObjectsMapTable];
            objc_setAssociatedObject(view, &kDYYYSameStyleOriginalsKey, originals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (![originals objectForKey:label] || !label.hidden) [originals setObject:@(label.hidden) forKey:label];
        if (!label.hidden) label.hidden = YES;
    }
}

+ (void)beginNativeUpdate:(UIView *)view {
    if (!NSThread.isMainThread || !view) return;
    NSUInteger depth = [objc_getAssociatedObject(view, &kDYYYSameStyleUpdateDepthKey) unsignedIntegerValue];
    objc_setAssociatedObject(view, &kDYYYSameStyleUpdateDepthKey, @(depth + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!depth) [self restoreView:view];
}

+ (void)endNativeUpdate:(UIView *)view {
    if (!NSThread.isMainThread || !view) return;
    NSUInteger depth = [objc_getAssociatedObject(view, &kDYYYSameStyleUpdateDepthKey) unsignedIntegerValue];
    if (depth > 1) {
        objc_setAssociatedObject(view, &kDYYYSameStyleUpdateDepthKey, @(depth - 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(view, &kDYYYSameStyleUpdateDepthKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self applyToView:view];
    }
}

+ (void)refreshVisibleViews {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisibleViews]; });
        return;
    }
    for (UIView *view in [self views].allObjects) [self applyToView:view];
}
@end
