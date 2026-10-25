#import "DYYYAvatarRing.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char kDYYYAvatarRingMaskKey;
static char kDYYYAvatarRingOriginalMaskKey;
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
    CALayer *mask = objc_getAssociatedObject(ring, &kDYYYAvatarRingMaskKey);
    id original = objc_getAssociatedObject(ring, &kDYYYAvatarRingOriginalMaskKey);
    if (mask && ring.layer.mask == mask) ring.layer.mask = original == NSNull.null ? nil : original;
    objc_setAssociatedObject(ring, &kDYYYAvatarRingMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(ring, &kDYYYAvatarRingOriginalMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)applyToRing:(UIView *)ring {
    if (!NSThread.isMainThread || !ring) return;
    if ([objc_getAssociatedObject(ring, &kDYYYAvatarRingUpdateDepthKey) unsignedIntegerValue]) return;
    [[self rings] addObject:ring];
    if (!ring.window || ![self isFeedAvatarRing:ring] ||
        ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYHideAvatarColorRing"]) {
        [self restoreRing:ring]; return;
    }
    CALayer *mask = objc_getAssociatedObject(ring, &kDYYYAvatarRingMaskKey);
    if (!mask) {
        mask = [CALayer layer];
        mask.name = @"DYYY.AvatarRing.DrawingMask";
        mask.backgroundColor = UIColor.clearColor.CGColor;
        objc_setAssociatedObject(ring, &kDYYYAvatarRingMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (ring.layer.mask != mask) {
        objc_setAssociatedObject(ring, &kDYYYAvatarRingOriginalMaskKey, ring.layer.mask ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ring.layer.mask = mask;
    }
    if (!CGRectEqualToRect(mask.frame, ring.bounds)) mask.frame = ring.bounds;
    [CATransaction commit];
    // 导出确认头像是 ring 的兄弟。透明 mask 仅遮住光圈绘制，原生晚写子视图 hidden
    // 不会重新露圈；根视图的 hidden/alpha/手势和头像按钮均保持原状。
}

+ (NSDictionary *)diagnostics {
    NSUInteger visible = 0, masked = 0;
    for (UIView *ring in [self rings].allObjects) {
        if (!ring.window || ![self isFeedAvatarRing:ring]) continue;
        visible++;
        CALayer *mask = objc_getAssociatedObject(ring, &kDYYYAvatarRingMaskKey);
        if (mask && ring.layer.mask == mask) masked++;
    }
    return @{ @"enabled": @([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYHideAvatarColorRing"]),
        @"classAvailable": @(NSClassFromString(@"AFDColorRingView") != Nil), @"visibleRings": @(visible), @"maskedRings": @(masked) };
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
