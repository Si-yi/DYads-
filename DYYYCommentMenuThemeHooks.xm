#import "AwemeHeaders.h"
#import "DYYYCommentMenuTheme.h"
#import "DYYYCommentMenuPalette.h"
#import "DYYYPanelBlur.h"
#import <objc/runtime.h>

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

- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYCommentMenuTheme synchronizeController:(UIViewController *)self];
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    // 临时覆盖另一层菜单时保留主题；真正离开窗口才恢复原值。
    UIViewController *menuController = (UIViewController *)self;
    if (!menuController.viewIfLoaded.window) [DYYYCommentMenuTheme restoreController:menuController];
}

%end
%end

%group DYYYCommentMenuCardThemeHooks
%hook DYYYCommentMenuCardCell
- (void)layoutSubviews {
    %orig;
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)prepareForReuse {
    [DYYYPanelBlur restoreView:(UIView *)self];
    [DYYYCommentMenuPalette restoreView:(UIView *)self];
    %orig;
}
%end
%end

// 好友昵称、最近分享和火花说明在内层 CollectionView 布局时才写入颜色。
// 只在评论长按菜单内接管；同一 Cell 用于普通分享页时恢复原值。
%group DYYYCommentMenuContactThemeHooks
%hook DYYYCommentMenuContactCell
- (void)setSelected:(BOOL)selected {
    %orig(selected);
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)layoutSubviews {
    %orig;
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)prepareForReuse {
    [DYYYPanelBlur restoreView:(UIView *)self];
    [DYYYCommentMenuPalette restoreView:(UIView *)self];
    %orig;
}
%end
%end

%group DYYYCommentMenuRecentShareThemeHooks
%hook DYYYCommentMenuRecentShareCell
- (void)layoutSubviews {
    %orig;
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)prepareForReuse {
    [DYYYPanelBlur restoreView:(UIView *)self];
    [DYYYCommentMenuPalette restoreView:(UIView *)self];
    %orig;
}
%end
%end

%group DYYYCommentMenuSelectionHooks
%hook DYYYCommentMenuSelectionSection
- (UIView *)createAdditionTextAndAppendToViewHierarchyWithShareContactList:(id)list {
    UIView *overlay = %orig;
    [DYYYCommentMenuPalette synchronizeSelectionSection:self overlay:overlay];
    return overlay;
}
- (void)shareContactList:(id)list stateDidChangeFromState:(NSUInteger)fromState toState:(NSUInteger)toState {
    %orig;
    [DYYYCommentMenuPalette synchronizeSelectionSection:self overlay:nil];
}
%end
%end

%group DYYYCommentMenuCollectionHooks
%hook DYYYCommentMenuCollectionController
- (void)viewDidLayoutSubviews {
    %orig;
    // 列表的遮罩和发送区可能在 Sheet 布局之后才落位；这里只同步一次，不安排轮询。
    [DYYYCommentMenuPalette synchronizeContentController:(UIViewController *)self];
}
%end
%end

@implementation DYYYCommentMenuTheme (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL sheetInstalled, cardInstalled, contactInstalled, selectionInstalled, recentInstalled, collectionInstalled;
    Class sheetClass = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet");
    if (!sheetInstalled && sheetClass && [sheetClass isSubclassOfClass:UIViewController.class]) {
        %init(DYYYCommentMenuThemeHooks, DYYYCommentLongPressPanelSheet = sheetClass);
        sheetInstalled = YES;
    }
    Class cellClass = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
    if (!cardInstalled && cellClass && [cellClass isSubclassOfClass:UICollectionViewCell.class]) {
        %init(DYYYCommentMenuCardThemeHooks, DYYYCommentMenuCardCell = cellClass);
        cardInstalled = YES;
    }
    Class contactClass = NSClassFromString(@"AWEIMShareImpl.ShareContactListTargetCell");
    if (!contactInstalled && contactClass && [contactClass isSubclassOfClass:UICollectionViewCell.class]) {
        %init(DYYYCommentMenuContactThemeHooks, DYYYCommentMenuContactCell = contactClass);
        contactInstalled = YES;
    }
    Class selectionClass = NSClassFromString(@"AWEIMShareImpl.ShareCommentHorizontalSectionController");
    if (!selectionInstalled && selectionClass && class_getInstanceMethod(selectionClass, @selector(createAdditionTextAndAppendToViewHierarchyWithShareContactList:)) &&
        class_getInstanceMethod(selectionClass, @selector(shareContactList:stateDidChangeFromState:toState:))) {
        %init(DYYYCommentMenuSelectionHooks, DYYYCommentMenuSelectionSection = selectionClass);
        selectionInstalled = YES;
    }
    Class recentClass = NSClassFromString(@"AWEIMShareImpl.ShareContactListRecentShareCell");
    if (!recentInstalled && recentClass && [recentClass isSubclassOfClass:UICollectionViewCell.class]) {
        %init(DYYYCommentMenuRecentShareThemeHooks, DYYYCommentMenuRecentShareCell = recentClass);
        recentInstalled = YES;
    }
    Class collectionClass = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCollectionViewController");
    if (!collectionInstalled && collectionClass && [collectionClass isSubclassOfClass:UIViewController.class]) {
        %init(DYYYCommentMenuCollectionHooks, DYYYCommentMenuCollectionController = collectionClass);
        collectionInstalled = YES;
    }
}
@end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYCommentMenuTheme installHooks]; });
}
