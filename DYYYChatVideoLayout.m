#import "DYYYChatVideoLayout.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYChatPlayerFrameKey;
static char kDYYYChatReplyBackgroundKey;

@implementation DYYYChatVideoLayout

+ (UIViewController *)detailForController:(UIViewController *)controller {
    Class detail = NSClassFromString(@"AWEAwemeIMDetailTableViewController");
    for (NSUInteger depth = 0; controller && depth < 12; depth++, controller = controller.parentViewController) {
        if (detail && [controller isKindOfClass:detail]) return controller;
    }
    return nil;
}
+ (UIViewController *)replyInDetail:(UIViewController *)detail {
    Class reply = NSClassFromString(@"AWEIMFeedVideoQuickReplayInputViewController");
    for (UIViewController *child in detail.childViewControllers) if (reply && [child isKindOfClass:reply]) return child;
    return nil;
}
+ (CGFloat)replyHeightInDetail:(UIViewController *)detail {
    UIViewController *reply = [self replyInDetail:detail];
    if (!reply.isViewLoaded || reply.view.hidden) return 0;
    CGFloat height = CGRectGetHeight(reply.view.bounds);
    // 输入键盘、半屏面板和横屏不参与全屏补高。
    return isfinite(height) && height > 0 && height <= 150 ? height : 0;
}
+ (BOOL)playerRoot:(UIView *)view controller:(UIViewController *)controller {
    if (!controller.isViewLoaded) return NO;
    BOOL root = view == controller.view;
    BOOL surface = [NSStringFromClass(view.class) isEqual:@"TTPlayerView"];
    if (!root && !surface) return NO;
    NSString *name = NSStringFromClass(controller.class);
    BOOL cell = [name isEqual:@"AWEAwemeDetailCellViewController"];
    BOOL player = [name isEqual:@"AWEDPlayerViewController_Merge"] || [name isEqual:@"AWEDPlayerFeedPlayerViewController"] || [name isEqual:@"AWEPlayVideoViewController"];
    return ((cell || player) && root) || (player && surface);
}
+ (CGRect)adjustedFrame:(CGRect)frame view:(UIView *)view controller:(UIViewController *)controller {
    NSDictionary *saved = objc_getAssociatedObject(view, &kDYYYChatPlayerFrameKey);
    if (!saved && ![self playerRoot:view controller:controller]) return frame;
    CGRect native = saved && CGRectEqualToRect(frame, [saved[@"applied"] CGRectValue]) ? [saved[@"native"] CGRectValue] : frame;
    UIViewController *detail = [self detailForController:controller];
    CGFloat reserve = [self replyHeightInDetail:detail];
    UIView *parent = view.superview;
    CGFloat target = CGRectGetHeight(parent.bounds);
    CGFloat gap = target - CGRectGetHeight(native);
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"];
    BOOL match = enabled && reserve > 0 && parent && isfinite(target) && target > 0 &&
        CGRectGetHeight(detail.view.bounds) > CGRectGetWidth(detail.view.bounds) &&
        fabs(CGRectGetMinY(native)) <= 0.5 && fabs(CGRectGetMinX(native)) <= 0.5 &&
        fabs(CGRectGetWidth(native) - CGRectGetWidth(parent.bounds)) <= 0.5 &&
        CGRectGetHeight(native) > target * 0.5 && fabs(gap - reserve) <= 1;
    if (!match) {
        if (saved) objc_setAssociatedObject(view, &kDYYYChatPlayerFrameKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return native;
    }
    CGRect applied = native; applied.size.height = target;
    if (!saved || !CGRectEqualToRect([saved[@"native"] CGRectValue], native) || !CGRectEqualToRect([saved[@"applied"] CGRectValue], applied)) {
        objc_setAssociatedObject(view, &kDYYYChatPlayerFrameKey,
            @{ @"native": [NSValue valueWithCGRect:native], @"applied": [NSValue valueWithCGRect:applied] }, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return applied;
}
+ (void)layoutCellController:(UIViewController *)controller {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self layoutCellController:controller]; }); return; }
    if (!controller.isViewLoaded || ![self detailForController:controller]) return;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:controller];
    for (NSUInteger i = 0; i < queue.count && i < 20; i++) {
        UIViewController *child = queue[i];
        if (!child.isViewLoaded) continue;
        if ([self playerRoot:child.view controller:child]) {
            CGRect frame = [self adjustedFrame:child.view.frame view:child.view controller:child];
            if (!CGRectEqualToRect(child.view.frame, frame)) child.view.frame = frame;
            for (UIView *subview in child.view.subviews) {
                if (![NSStringFromClass(subview.class) isEqual:@"TTPlayerView"]) continue;
                CGRect player = [self adjustedFrame:subview.frame view:subview controller:child];
                if (!CGRectEqualToRect(subview.frame, player)) subview.frame = player;
            }
        }
        if ([NSStringFromClass(child.class) isEqual:@"AWEPlayInteractionViewController"]) [self layoutInteractionController:child];
        else [queue addObjectsFromArray:child.childViewControllers];
    }
}
+ (void)layoutInteractionController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller.isViewLoaded || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"]) return;
    UIViewController *detail = [self detailForController:controller];
    CGFloat reserve = [self replyHeightInDetail:detail];
    if (!reserve || !detail.isViewLoaded) return;
    // 只铺开视频，文案和进度仍固定在原生回复栏上沿，避免落到按钮下面。
    CGFloat height = CGRectGetHeight(detail.view.bounds) - reserve;
    CGRect frame = controller.view.frame;
    if (height > 0 && CGRectGetHeight(frame) > height + 0.5 && fabs(frame.origin.y) < 0.5) {
        frame.size.height = height;
        controller.view.frame = frame;
    }
}
+ (BOOL)ownsReplyBackground:(UIView *)view {
    return objc_getAssociatedObject(view, &kDYYYChatReplyBackgroundKey) != nil && [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"];
}
+ (void)updateReplyBackground:(UIViewController *)controller {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self updateReplyBackground:controller]; }); return; }
    if (!controller.isViewLoaded) return;
    UIView *view = controller.view;
    NSDictionary *saved = objc_getAssociatedObject(view, &kDYYYChatReplyBackgroundKey);
    BOOL clear = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"] && [self detailForController:controller];
    if (clear) {
        if (!saved) objc_setAssociatedObject(view, &kDYYYChatReplyBackgroundKey,
            @{ @"color": view.backgroundColor ?: NSNull.null, @"opaque": @(view.opaque) }, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (![view.backgroundColor isEqual:UIColor.clearColor]) view.backgroundColor = UIColor.clearColor;
        if (view.opaque) view.opaque = NO;
    } else if (saved) {
        objc_setAssociatedObject(view, &kDYYYChatReplyBackgroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.backgroundColor = saved[@"color"] == NSNull.null ? nil : saved[@"color"];
        view.opaque = [saved[@"opaque"] boolValue];
    }
}
@end
