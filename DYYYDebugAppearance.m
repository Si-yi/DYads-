#import "DYYYDebugAppearance.h"
#import <objc/runtime.h>

static char kDYYYDebugAppearanceKey;

@interface DYYYDebugAppearance ()
@property (nonatomic, weak) UIWindowScene *scene;
@end

@implementation DYYYDebugAppearance

#pragma mark - 调试弹层主题

+ (NSHashTable<UIViewController *> *)controllers {
    static NSHashTable<UIViewController *> *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}

- (void)applyToController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller) return;
    UIWindowScene *scene = controller.viewIfLoaded.window.windowScene ?: self.scene;
    UIUserInterfaceStyle style = scene ? scene.traitCollection.userInterfaceStyle : UIScreen.mainScreen.traitCollection.userInterfaceStyle;
    if (style == UIUserInterfaceStyleUnspecified) style = UIUserInterfaceStyleLight;
    if (controller.overrideUserInterfaceStyle != style) controller.overrideUserInterfaceStyle = style;
    UIView *view = controller.viewIfLoaded;
    if (view && view.overrideUserInterfaceStyle != style) view.overrideUserInterfaceStyle = style;
}

+ (void)prepareController:(UIViewController *)controller sourceWindow:(UIWindow *)window {
    if (!NSThread.isMainThread || !controller) return;
    DYYYDebugAppearance *appearance = [DYYYDebugAppearance new];
    appearance.scene = window.windowScene;
    objc_setAssociatedObject(controller, &kDYYYDebugAppearanceKey, appearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self controllers] addObject:controller];
    [appearance applyToController:controller];
}

+ (void)refreshPresentedControllers {
    if (!NSThread.isMainThread) return;
    for (UIViewController *controller in [self controllers].allObjects) {
        DYYYDebugAppearance *appearance = objc_getAssociatedObject(controller, &kDYYYDebugAppearanceKey);
        [appearance applyToController:controller];
    }
}

@end
