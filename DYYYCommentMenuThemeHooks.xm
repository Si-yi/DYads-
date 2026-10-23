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
    [NSNotificationCenter.defaultCenter postNotificationName:@"DYYYCommentInputThemeDidChange" object:nil userInfo:@{
        @"phase": @"commentLongPressMenuThemeApplied",
        @"viewClass": NSStringFromClass(self.class),
        @"requestedStyle": @(style),
        @"effectiveStyle": @(self.viewIfLoaded.traitCollection.userInterfaceStyle),
        @"overrideStyle": @(self.overrideUserInterfaceStyle)
    }];
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style {
    UIUserInterfaceStyle menuStyle = [DYYYCommentMenuTheme styleForController:self];
    %orig(menuStyle == UIUserInterfaceStyleUnspecified ? style : menuStyle);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    // 临时覆盖另一层菜单时保留主题；真正离开窗口才恢复原值。
    if (!self.viewIfLoaded.window) [DYYYCommentMenuTheme restoreController:self];
}

%end
%end

%ctor {
    Class sheetClass = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet");
    if (sheetClass && [sheetClass isSubclassOfClass:UIViewController.class]) {
        %init(DYYYCommentMenuThemeHooks, DYYYCommentLongPressPanelSheet = sheetClass);
    }
}
