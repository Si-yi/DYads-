#import "DYYYAvatarRing.h"
#import <objc/runtime.h>

static char kDYYYAvatarRingOriginalsKey;
static char kDYYYAvatarRingUpdateDepthKey;

@implementation DYYYAvatarRing

+ (NSHashTable<UIView *> *)rings {
    static NSHashTable *rings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ rings = [NSHashTable weakObjectsHashTable]; });
    return rings;
}

+ (BOOL)isFeedAvatarRing:(UIView *)ring {
    Class picture = NSClassFromString(@"AWEPlayInteractionUserProfilePictureView");
    for (UIView *parent = ring.superview; parent; parent = parent.superview)
        if (picture && [parent isKindOfClass:picture]) return YES;
    return NO;
}

+ (void)restoreRing:(UIView *)ring {
    if (!NSThread.isMainThread || !ring) return;
    NSMapTable<UIView *, NSNumber *> *originals = objc_getAssociatedObject(ring, &kDYYYAvatarRingOriginalsKey);
    objc_setAssociatedObject(ring, &kDYYYAvatarRingOriginalsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UIView *renderer in originals.keyEnumerator.allObjects) {
        if (renderer.hidden) renderer.hidden = [[originals objectForKey:renderer] boolValue];
    }
}

+ (void)applyToRing:(UIView *)ring {
    if (!NSThread.isMainThread || !ring) return;
    if ([objc_getAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey) unsignedIntegerValue]) return;
    [[self rings] addObject:ring];
    if (!ring.window || ![self isFeedAvatarRing:ring] ||
        ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYHideAvatarColorRing"]) {
        [self restoreRing:ring];
        return;
    }
    NSMapTable<UIView *, NSNumber *> *originals = objc_getAssociatedObject(ring, &kDYYYAvatarRingOriginalsKey);
    if (!originals) {
        originals = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(ring, &kDYYYAvatarRingOriginalsKey, originals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // 导出确认其子视图只有静态渐变圈、动画圈和挂件。头像是外层的兄弟视图。
    // 不隐藏 ring 本身、不改 alpha/手势，保留原有点击动作与命中范围。
    for (UIView *renderer in ring.subviews) {
        if (![originals objectForKey:renderer] || !renderer.hidden)
            [originals setObject:@(renderer.hidden) forKey:renderer];
        if (!renderer.hidden) renderer.hidden = YES;
    }
}

+ (void)beginNativeUpdate:(UIView *)ring {
    if (!NSThread.isMainThread || !ring) return;
    NSUInteger depth = [objc_getAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey) unsignedIntegerValue];
    objc_setAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey, @(depth + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!depth) [self restoreRing:ring];
}

+ (void)endNativeUpdate:(UIView *)ring {
    if (!NSThread.isMainThread || !ring) return;
    NSUInteger depth = [objc_getAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey) unsignedIntegerValue];
    if (depth > 1) {
        objc_setAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey, @(depth - 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self applyToRing:ring];
    }
}

+ (void)refreshVisibleRings {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshVisibleRings]; });
        return;
    }
    for (UIView *ring in [self rings].allObjects) [self applyToRing:ring];
}
@end
