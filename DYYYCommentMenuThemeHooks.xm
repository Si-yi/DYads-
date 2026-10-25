/*
 菜单分区接口参考 DYKiller DKCommentMenuGrid.xm / DKCommentMenuClean.xm；发送按钮语义类查找参考 DKShareSelectionHooks.xm。
 https://github.com/HierarchThurs/DYKiller

 MIT License
 Copyright (c) 2026 Hierarch

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*/
#import "AwemeHeaders.h"
#import "DYYYCommentMenuTheme.h"
#import "DYYYCommentMenuPalette.h"
#import "DYYYPanelBlur.h"
#import "DYYYCommentMenuGrid.h"
#import "DYYYShareComposer.h"
#import <stdlib.h>
#import <string.h>
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

- (void)setSheetHeight:(CGFloat)height {
    %orig([DYYYCommentMenuGrid constrainedHeight:height controller:(UIViewController *)self]);
}
- (void)updateSheetHeight:(CGFloat)height withMinimumSheetHeight:(CGFloat)minimum animated:(BOOL)animated completion:(id)completion {
    CGFloat compact = [DYYYCommentMenuGrid constrainedHeight:height controller:(UIViewController *)self];
    %orig(compact, MIN(minimum, compact), animated, completion);
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
    [DYYYCommentMenuGrid layoutCell:(UIView *)self];
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYCommentMenuGrid layoutCell:(UIView *)self];
    [DYYYCommentMenuPalette synchronizeCell:(UIView *)self];
}
- (void)prepareForReuse {
    [DYYYCommentMenuGrid restoreCell:(UIView *)self];
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
- (void)viewDidLoad {
    %orig;
    [DYYYCommentMenuTheme installLayoutHooksForController:(UIViewController *)self];
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYCommentMenuTheme installLayoutHooksForController:(UIViewController *)self];
    [DYYYCommentMenuPalette synchronizeContentController:(UIViewController *)self];
    [DYYYCommentMenuGrid synchronizeController:(UIViewController *)self];
}
%end
%end

%group DYYYCommentMenuModelHooks
%hook DYYYCommentMenuListModel
- (void)replaceBySectionViewModels:(NSArray *)sections sync:(BOOL)sync {
    id first = [DYYYCommentMenuGrid registerSections:sections list:self];
    %orig;
    [DYYYCommentMenuGrid didReplaceModelsInSection:first];
}
%end
%hook DYYYCommentMenuNormalSectionModel
- (void)replaceByModels:(NSArray *)models animated:(BOOL)animated sync:(BOOL)sync {
    BOOL managed = [DYYYCommentMenuGrid isManagedSectionModel:self];
    NSArray *rendered = [DYYYCommentMenuGrid modelsForSection:self incoming:models];
    %orig(rendered, managed ? NO : animated, managed ? YES : sync);
    [DYYYCommentMenuGrid didReplaceModelsInSection:self];
}
%end
%end

%group DYYYCommentMenuNativeLayoutHooks
%hook DYYYCommentMenuNativeLayout
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    BOOL managed = [DYYYCommentMenuGrid isMenuLayout:self];
    CGRect query = rect;
    if (managed) {
        // 命中查询可能只有 1pt 宽；先取整行，再按居中后的真实 frame 过滤，不能漏掉移来的末项。
        UICollectionViewLayout *layout = (id)self;
        query.origin.x = CGRectGetMinX(layout.collectionView.bounds);
        query.size.width = CGRectGetWidth(layout.collectionView.bounds);
    }
    NSArray *native = %orig(query);
    if (!managed) return native;
    NSMutableArray *adjusted = [NSMutableArray arrayWithCapacity:native.count];
    BOOL changed = NO;
    for (UICollectionViewLayoutAttributes *item in native) {
        UICollectionViewLayoutAttributes *value = [DYYYCommentMenuGrid adjustAttributes:item layout:self];
        if (CGRectIntersectsRect(value.frame, rect)) [adjusted addObject:value];
        else changed = YES;
        if (value != item) changed = YES;
    }
    return changed ? adjusted : native;
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path {
    UICollectionViewLayoutAttributes *native = %orig;
    return [DYYYCommentMenuGrid adjustAttributes:native layout:self];
}
%end
%end

%group DYYYCommentMenuGridHooks
%hook DYYYCommentMenuNormalSection
- (CGSize)sizeForItemAtIndex:(NSInteger)index model:(id)model collectionViewSize:(CGSize)size {
    CGSize nativeSize = %orig;
    return [DYYYCommentMenuGrid sizeForSection:self index:index original:nativeSize collectionSize:size];
}
- (void)configCell:(id)cell index:(NSInteger)index model:(id)model {
    %orig;
    [DYYYCommentMenuGrid configureCell:cell section:self index:index model:model];
}
- (CGSize)sizeForFooterWithCollectionViewSize:(CGSize)size {
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] && [self numberOfItems] == 0) return CGSizeZero;
    return %orig;
}
%end
%end

%group DYYYCommentMenuSendButtonHooks
%hook DYYYCommentMenuSendButton
- (void)layoutSubviews {
    %orig;
    [DYYYPanelBlur synchronizeView:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYPanelBlur synchronizeView:(UIView *)self];
}
%end
%end

%group DYYYCommentMenuComposerHooks
%hook DYYYCommentMenuComposerView
- (void)didMoveToSuperview {
    %orig;
    [DYYYCommentMenuPalette synchronizeComposer:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYCommentMenuPalette synchronizeComposer:(UIView *)self];
}
- (void)setHidden:(BOOL)hidden {
    BOOL changed = ((UIView *)self).hidden != hidden;
    %orig;
    if (changed) [DYYYCommentMenuPalette synchronizeComposer:(UIView *)self];
}
- (void)setAlpha:(CGFloat)alpha {
    BOOL wasVisible = ((UIView *)self).alpha > 0.01;
    %orig;
    if (wasVisible != (alpha > 0.01)) [DYYYCommentMenuPalette synchronizeComposer:(UIView *)self];
}
%end
%end

%group DYYYCommentMenuShareTextHooks
%hook DYYYCommentMenuShareTextView
- (void)setTextColor:(UIColor *)color {
    UIColor *readable = [DYYYShareComposer adjustTextColor:color input:(UITextView *)self];
    %orig(readable);
}
- (void)setTypingAttributes:(NSDictionary *)attributes {
    NSDictionary *readable = [DYYYShareComposer adjustTypingAttributes:attributes input:(UITextView *)self];
    %orig(readable);
}
- (void)layoutSubviews {
    %orig;
    [DYYYShareComposer synchronizeInput:(UITextView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYShareComposer synchronizeInput:(UITextView *)self];
}
%end
%end

@implementation DYYYCommentMenuTheme (Hooks)
+ (Class)commentMenuSendButtonClass {
    Class composer = NSClassFromString(@"AWEIMShareImpl.ShareAdditionTextView");
    const char *image = composer ? class_getImageName(composer) : NULL;
    if (!image) return Nil;
    unsigned int count = 0;
    const char **names = objc_copyClassNamesForImage(image, &count);
    Class found = Nil;
    for (unsigned int index = 0; index < count; index++) {
        if (!strstr(names[index], "AWEIMShareImpl") || !strstr(names[index], "ShareAdditionTextButton")) continue;
        Class candidate = objc_getClass(names[index]);
        if ([candidate isSubclassOfClass:UIButton.class]) { found = candidate; break; }
    }
    free(names);
    return found;
}

+ (void)installLayoutHooksForController:(UIViewController *)controller {
    static Class installed;
    UICollectionView *list = [DYYYCommentMenuGrid collectionForController:controller];
    Class nativeClass = list.collectionViewLayout.class;
    if (installed || !nativeClass || ![nativeClass isSubclassOfClass:UICollectionViewLayout.class]) return;
    %init(DYYYCommentMenuNativeLayoutHooks, DYYYCommentMenuNativeLayout = nativeClass);
    installed = nativeClass;
    // 只在首次安装时重新计算一次；不替换原生布局，不在布局回调中反复失效。
    [list.collectionViewLayout invalidateLayout];
}

+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL sheetInstalled, cardInstalled, contactInstalled, selectionInstalled, recentInstalled, collectionInstalled, gridInstalled, sendInstalled, modelsInstalled, shareTextInstalled, composerInstalled;
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
    Class listModel = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.AWECommentLongPressPanelListViewModel");
    Class normalModel = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionViewModel");
    if (!modelsInstalled && listModel && normalModel &&
        class_getInstanceMethod(listModel, @selector(replaceBySectionViewModels:sync:)) &&
        class_getInstanceMethod(normalModel, @selector(modelsArray)) &&
        class_getInstanceMethod(normalModel, @selector(replaceByModels:animated:sync:))) {
        %init(DYYYCommentMenuModelHooks, DYYYCommentMenuListModel = listModel, DYYYCommentMenuNormalSectionModel = normalModel);
        modelsInstalled = YES;
    }
    Class sectionClass = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionController");
    if (!gridInstalled && sectionClass && cellClass &&
        class_getInstanceMethod(sectionClass, @selector(sizeForItemAtIndex:model:collectionViewSize:)) &&
        class_getInstanceMethod(sectionClass, @selector(configCell:index:model:)) &&
        class_getInstanceMethod(sectionClass, @selector(numberOfItems)) &&
        class_getInstanceMethod(sectionClass, @selector(sizeForFooterWithCollectionViewSize:)) &&
        class_getInstanceMethod(sectionClass, @selector(viewController)) &&
        class_getInstanceVariable(cellClass, "$__lazy_storage_$_mainView")) {
        %init(DYYYCommentMenuGridHooks, DYYYCommentMenuNormalSection = sectionClass);
        gridInstalled = YES;
    }
    Class composerClass = NSClassFromString(@"AWEIMShareImpl.ShareAdditionTextView");
    if (!composerInstalled && composerClass && [composerClass isSubclassOfClass:UIVisualEffectView.class]) {
        %init(DYYYCommentMenuComposerHooks, DYYYCommentMenuComposerView = composerClass);
        composerInstalled = YES;
    }
    Class shareText = NSClassFromString(@"AWEIMShareImpl.ShareTextView");
    if (!shareTextInstalled && shareText && [shareText isSubclassOfClass:UITextView.class]) {
        %init(DYYYCommentMenuShareTextHooks, DYYYCommentMenuShareTextView = shareText);
        shareTextInstalled = YES;
    }
    Class sendClass = [self commentMenuSendButtonClass];
    if (!sendInstalled && sendClass) {
        %init(DYYYCommentMenuSendButtonHooks, DYYYCommentMenuSendButton = sendClass);
        sendInstalled = YES;
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
