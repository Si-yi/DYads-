#import "DYYYCommentMenuTheme.h"
#import "DYYYCommentMenuPalette.h"
#import "DYYYPanelBlur.h"
#import "AwemeHeaders.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>

static char kDYYYCommentMenuStyleKey;
static char kDYYYCommentMenuOriginalControllerStyleKey;
static char kDYYYCommentMenuOriginalViewStyleKey;

@implementation DYYYCommentMenuTheme

#pragma mark - 菜单主题

+ (BOOL)canManageController:(UIViewController *)controller {
    return NSThread.isMainThread &&
        [NSStringFromClass(controller.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet"] &&
        (DYYYGetBool(@"DYYYEnableCommentBlur") || DYYYGetBool(@"DYYYEnableFloatingCommentInput") || DYYYGetBool(@"DYYYEnableCommentMenuBlur"));
}

+ (UIUserInterfaceStyle)styleForController:(UIViewController *)controller {
    if (![self canManageController:controller]) return UIUserInterfaceStyleUnspecified;
    NSNumber *style = objc_getAssociatedObject(controller, &kDYYYCommentMenuStyleKey);
    return style ? (UIUserInterfaceStyle)style.integerValue : UIUserInterfaceStyleUnspecified;
}

+ (UIUserInterfaceStyle)prepareController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return UIUserInterfaceStyleUnspecified;
    if (![self canManageController:controller]) {
        [self restoreController:controller];
        return UIUserInterfaceStyleUnspecified;
    }
    // 评论列表已经按抖音主题绘制；菜单不能再从固定为浅色的主窗口推断主题。
    UIUserInterfaceStyle style = [DYYYUtils isDarkMode] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    if (!objc_getAssociatedObject(controller, &kDYYYCommentMenuOriginalControllerStyleKey)) {
        objc_setAssociatedObject(controller, &kDYYYCommentMenuOriginalControllerStyleKey,
            @(controller.overrideUserInterfaceStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(controller, &kDYYYCommentMenuStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self synchronizeController:controller];
    return style;
}

+ (void)synchronizeController:(UIViewController *)controller {
    UIUserInterfaceStyle style = [self styleForController:controller];
    if (style == UIUserInterfaceStyleUnspecified) return;
    if (controller.overrideUserInterfaceStyle != style) controller.overrideUserInterfaceStyle = style;
    // viewIfLoaded 不会在主题设置过程中触发 loadView 重入。
    UIView *view = controller.viewIfLoaded;
    if (view) {
        if (!objc_getAssociatedObject(view, &kDYYYCommentMenuOriginalViewStyleKey)) {
            objc_setAssociatedObject(view, &kDYYYCommentMenuOriginalViewStyleKey,
                @(view.overrideUserInterfaceStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (view.overrideUserInterfaceStyle != style) view.overrideUserInterfaceStyle = style;
        [DYYYCommentMenuPalette applyInView:view controller:controller];
        [DYYYPanelBlur synchronizeController:controller];
    }
}

+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller) return;
    [DYYYPanelBlur restoreController:controller];
    [DYYYCommentMenuPalette restoreController:controller];
    NSNumber *original = objc_getAssociatedObject(controller, &kDYYYCommentMenuOriginalControllerStyleKey);
    objc_setAssociatedObject(controller, &kDYYYCommentMenuStyleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &kDYYYCommentMenuOriginalControllerStyleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (original) controller.overrideUserInterfaceStyle = (UIUserInterfaceStyle)original.integerValue;
    UIView *view = controller.viewIfLoaded;
    NSNumber *originalView = objc_getAssociatedObject(view, &kDYYYCommentMenuOriginalViewStyleKey);
    if (view && originalView) {
        objc_setAssociatedObject(view, &kDYYYCommentMenuOriginalViewStyleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.overrideUserInterfaceStyle = (UIUserInterfaceStyle)originalView.integerValue;
    }
}

+ (UIViewController *)menuControllerForController:(UIViewController *)controller {
    for (NSUInteger depth = 0; controller && depth < 16; depth++, controller = controller.parentViewController)
        if ([NSStringFromClass(controller.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet"])
            return controller;
    return nil;
}

+ (UIViewController *)controllerForView:(UIView *)view {
    for (UIResponder *responder = view.nextResponder; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class]) continue;
        UIViewController *menu = [self menuControllerForController:(UIViewController *)responder];
        if (menu && menu.viewIfLoaded && [view isDescendantOfView:menu.viewIfLoaded]) return menu;
    }
    return nil;
}

@end
