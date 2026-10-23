/*
 原生高度回调与分区布局适配参考 DYKiller DKCommentHeaderClean.xm。
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
#import "DYYYCommentHeaderLayout.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

static char kDYYYCommentHeaderLayoutKey;

@interface DYYYCommentHeaderLayout ()
@property (nonatomic, weak) DYYYCommentHeaderSectionController *section;
@property (nonatomic, weak) UICollectionViewCell *cell;
@property (nonatomic, weak) id model;
@property (nonatomic, copy) DYYYCommentHeaderHeightCallback nativeHeight;
@property (nonatomic, copy) DYYYCommentHeaderTopCallback nativeTop;
@property (nonatomic, assign) double measuredHeight;
@property (nonatomic, assign) BOOL nativeOnlyCount;
@property (nonatomic, assign) BOOL nativeHasBusiness;
@property (nonatomic, assign) BOOL hasTopState;
@property (nonatomic, assign) BOOL collapsed;
@property (nonatomic, assign) BOOL scheduled;
@property (nonatomic, assign) BOOL syncScheduled;
@property (nonatomic, weak) id notifiedModel;
@property (nonatomic, assign) BOOL notifiedCollapsed;
@property (nonatomic, assign) BOOL hasNotifiedLayout;
@end

@implementation DYYYCommentHeaderLayout

#pragma mark - 原生分区状态

+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *exception) { return nil; }
}

+ (DYYYCommentHeaderLayout *)stateForSection:(id)section {
    if (!NSThread.isMainThread || !section) return nil;
    DYYYCommentHeaderLayout *state = objc_getAssociatedObject(section, &kDYYYCommentHeaderLayoutKey);
    if (!state) {
        state = [DYYYCommentHeaderLayout new];
        state.section = section;
        objc_setAssociatedObject(section, &kDYYYCommentHeaderLayoutKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIViewController *owner = [self value:section key:@"viewController"];
    if ([owner isKindOfClass:UIViewController.class] &&
        [NSStringFromClass(owner.class) isEqualToString:@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController"]) {
        objc_setAssociatedObject(owner, &kDYYYCommentHeaderLayoutKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (BOOL)isCollapsed {
    return self.collapsed && DYYYGetBool(@"DYYYHideCommentViews");
}

- (void)scheduleLayout {
    if (self.scheduled) return;
    self.scheduled = YES;
    __weak DYYYCommentHeaderLayout *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYCommentHeaderLayout *state = weakSelf;
        if (!state) return;
        state.scheduled = NO;
        if (!state.section || !state.cell) return;
        BOOL collapsed = [state isCollapsed];
        if (state.hasNotifiedLayout && state.notifiedModel == state.model && state.notifiedCollapsed == collapsed) return;
        state.hasNotifiedLayout = YES;
        state.notifiedModel = state.model;
        state.notifiedCollapsed = collapsed;
        if (state.hasTopState && state.nativeTop) {
            state.nativeTop(collapsed ? NO : state.nativeOnlyCount, collapsed ? NO : state.nativeHasBusiness);
        }
        if (state.nativeHeight) state.nativeHeight(collapsed ? 0.0 : state.measuredHeight);
        // 只在折叠状态变化时通知原生分区重排，不在每次 layout 中请求更新。
        [state.section updateLayout:NO completion:nil];
    });
}

+ (void)bindCell:(UICollectionViewCell *)cell model:(id)model section:(id)section {
    DYYYCommentHeaderLayout *state = [self stateForSection:section];
    if (!state || !cell) return;
    if (state.cell != cell || state.model != model) {
        if (state.cell) objc_setAssociatedObject(state.cell, &kDYYYCommentHeaderLayoutKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (state.model != model && state.collapsed) {
            state.collapsed = NO;
            [state scheduleLayout];
        }
    }
    state.cell = cell;
    state.model = model;
    objc_setAssociatedObject(cell, &kDYYYCommentHeaderLayoutKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 仅收起已隐藏且不含其他内容的业务行

+ (BOOL)containsOnlyHiddenBusiness:(UIView *)root {
    static NSSet<NSString *> *businessClasses;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        businessClasses = [NSSet setWithArray:@[
            @"AWEShowPlayletCommentHeaderView", @"AWECommentGuideLunaAnchorView", @"AWEPOIEntryAnchorView",
            @"AWECommentPanelHeaderSwiftImpl.CommentHeaderGeneralView",
            @"AWECommentPanelHeaderSwiftImpl.CommentHeaderGoodsView",
            @"AWECommentPanelHeaderSwiftImpl.CommentHeaderTemplateAnchorView"
        ]];
    });
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithArray:root.subviews];
    BOOL foundBusiness = NO;
    for (NSUInteger index = 0; index < pending.count; index++) {
        // 无法完整确认结构时保留原生高度，不能截断未知业务内容。
        if (index >= 80) return NO;
        UIView *view = pending[index];
        if ([businessClasses containsObject:NSStringFromClass(view.class)]) {
            if (!view.hidden) return NO;
            foundBusiness = YES;
            continue;
        }
        if (view.hidden || view.alpha <= 0.01) continue;
        // 计数尚未填入文字、或有未知的自绘业务视图时，也不能把整行移除。
        if ([NSStringFromClass(view.class) isEqualToString:@"AWECommentSwiftBizUI.CommentInteractionBaseLabel"]) return NO;
        BOOL knownContainer = view.class == UIView.class || [view isKindOfClass:UIStackView.class] ||
            [view isKindOfClass:UILabel.class] || [view isKindOfClass:UIImageView.class];
        if (!knownContainer) return NO;
        if ([view respondsToSelector:@selector(attributedText)]) {
            id text = [(id)view attributedText];
            if ([text isKindOfClass:NSAttributedString.class] && [text length] > 0) return NO;
        }
        if ([view isKindOfClass:UILabel.class] && ((UILabel *)view).text.length) return NO;
        if ([view isKindOfClass:UIImageView.class] && ((UIImageView *)view).image) return NO;
        [pending addObjectsFromArray:view.subviews];
    }
    return foundBusiness;
}

+ (void)synchronizeCell:(UICollectionViewCell *)cell {
    if (!NSThread.isMainThread || !cell) return;
    DYYYCommentHeaderLayout *state = objc_getAssociatedObject(cell, &kDYYYCommentHeaderLayoutKey);
    if (!state || state.cell != cell) return;
    BOOL collapsed = NO;
    if (DYYYGetBool(@"DYYYHideCommentViews")) {
        id models = [self value:state.section key:@"modelsArray"];
        BOOL singleItem = [models isKindOfClass:NSArray.class] && [models count] == 1 && [models firstObject] == state.model;
        collapsed = singleItem && [self containsOnlyHiddenBusiness:cell.contentView];
    }
    if (state.collapsed == collapsed) return;
    state.collapsed = collapsed;
    [state scheduleLayout];
}

+ (void)businessViewDidHide:(UIView *)view {
    if (!NSThread.isMainThread || !DYYYGetBool(@"DYYYHideCommentViews")) return;
    DYYYCommentHeaderLayout *state = nil;
    for (UIView *parent = view.superview; parent; parent = parent.superview) {
        state = objc_getAssociatedObject(parent, &kDYYYCommentHeaderLayoutKey);
        if (state) break;
        if ([parent isKindOfClass:UICollectionView.class]) return;
    }
    if (!state || state.syncScheduled) return;
    state.syncScheduled = YES;
    __weak DYYYCommentHeaderLayout *weakState = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYCommentHeaderLayout *current = weakState;
        if (!current) return;
        current.syncScheduled = NO;
        [DYYYCommentHeaderLayout synchronizeCell:current.cell];
    });
}

#pragma mark - 高度与回调

+ (double)height:(double)height section:(id)section {
    if (!NSThread.isMainThread) return height;
    DYYYCommentHeaderLayout *state = objc_getAssociatedObject(section, &kDYYYCommentHeaderLayoutKey);
    state.measuredHeight = height;
    return [state isCollapsed] ? 0.0 : height;
}

+ (CGSize)size:(CGSize)size model:(id)model section:(id)section {
    if (!NSThread.isMainThread) return size;
    DYYYCommentHeaderLayout *state = objc_getAssociatedObject(section, &kDYYYCommentHeaderLayoutKey);
    if (state.model == model && [state isCollapsed]) size.height = 0.0;
    return size;
}

+ (DYYYCommentHeaderHeightCallback)heightCallback:(DYYYCommentHeaderHeightCallback)callback section:(id)section {
    DYYYCommentHeaderLayout *state = [self stateForSection:section];
    if (!state) return callback;
    state.nativeHeight = callback;
    if (!callback) return nil;
    __weak DYYYCommentHeaderLayout *weakState = state;
    return ^(double height) {
        DYYYCommentHeaderLayout *current = weakState;
        if (NSThread.isMainThread) current.measuredHeight = height;
        callback(NSThread.isMainThread && [current isCollapsed] ? 0.0 : height);
    };
}

+ (DYYYCommentHeaderTopCallback)topCallback:(DYYYCommentHeaderTopCallback)callback section:(id)section {
    DYYYCommentHeaderLayout *state = [self stateForSection:section];
    if (!state) return callback;
    state.nativeTop = callback;
    if (!callback) return nil;
    __weak DYYYCommentHeaderLayout *weakState = state;
    return ^(BOOL onlyCount, BOOL hasBusiness) {
        DYYYCommentHeaderLayout *current = weakState;
        if (NSThread.isMainThread) {
            current.nativeOnlyCount = onlyCount;
            current.nativeHasBusiness = hasBusiness;
            current.hasTopState = YES;
        }
        BOOL collapsed = NSThread.isMainThread && [current isCollapsed];
        callback(collapsed ? NO : onlyCount, collapsed ? NO : hasBusiness);
    };
}

+ (double)topHeight:(double)height controller:(UIViewController *)controller {
    if (!NSThread.isMainThread) return height;
    DYYYCommentHeaderLayout *state = objc_getAssociatedObject(controller, &kDYYYCommentHeaderLayoutKey);
    if (![state isCollapsed] || !state.section) return height;
    // 顶部业务高度归零，但保留原生评论/AI 解析分页的高度。
    return [(DYYYCommentHeaderInnerController *)controller heightForSegmentedControl];
}

@end
