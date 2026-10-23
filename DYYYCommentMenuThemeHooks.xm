#import "AwemeHeaders.h"
#import "DYYYCommentMenuTheme.h"

%group DYYYCommentMenuThemeHooks
%hook DYYYCommentLongPressPanelSheet

- (void)viewDidLoad {
    UIUserInterfaceStyle style = [DYYYCommentMenuTheme prepareController:self];
    if (style == UIUserInterfaceStyleUnspecified) {
        %orig;
        return;
    }
    // 原生创建菜单时就使用正确的 trait，兼顾创建时解析的颜色与动态颜色。
    [[UITraitCollection traitCollectionWithUserInterfaceStyle:style] performAsCurrentTraitCollection:^{
        %orig;
    }];
    [DYYYCommentMenuTheme synchronizeController:self];
}

- (void)viewWillAppear:(BOOL)animated {
    UIUserInterfaceStyle style = [DYYYCommentMenuTheme prepareController:self];
    if (style == UIUserInterfaceStyleUnspecified) {
        %orig(animated);
        return;
    }
    [[UITraitCollection traitCollectionWithUserInterfaceStyle:style] performAsCurrentTraitCollection:^{
        %orig(animated);
    }];
    [DYYYCommentMenuTheme synchronizeController:self];
    UIViewController *menuController = (UIViewController *)self;
    [NSNotificationCenter.defaultCenter postNotificationName:@"DYYYCommentInputThemeDidChange" object:nil userInfo:@{
        @"phase": @"commentLongPressMenuThemeApplied",
        @"viewClass": NSStringFromClass([menuController class]),
        @"requestedStyle": @(style),
        @"effectiveStyle": @(menuController.viewIfLoaded.traitCollection.userInterfaceStyle),
        @"overrideStyle": @(menuController.overrideUserInterfaceStyle)
    }];
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style {
    UIUserInterfaceStyle menuStyle = [DYYYCommentMenuTheme styleForController:self];
    %orig(menuStyle == UIUserInterfaceStyleUnspecified ? style : menuStyle);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    // 临时覆盖另一层菜单时保留主题；真正离开窗口才恢复原值。
    UIViewController *menuController = (UIViewController *)self;
    if (!menuController.viewIfLoaded.window) [DYYYCommentMenuTheme restoreController:menuController];
}

%end
%end

%ctor {
    Class sheetClass = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet");
    if (sheetClass && [sheetClass isSubclassOfClass:UIViewController.class]) {
        %init(DYYYCommentMenuThemeHooks, DYYYCommentLongPressPanelSheet = sheetClass);
    }
}
