/*
 两列功能菜单沿用 DYKiller DKCommentMenuGrid.xm 的原生分区尺寸接口与内容对齐方式。
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
#import "DYYYCommentMenuGrid.h"
#import "DYYYCommentMenuTheme.h"
#import "AwemeHeaders.h"
#import "DYYYCommentMenuItems.h"
#import "DYYYCommentMenuMetrics.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYCommentGridInfoKey;
static char kDYYYCommentGridTransformKey;
static char kDYYYCommentGridListStateKey;
static char kDYYYCommentGridCellStateKey;
static char kDYYYCommentGridMenuStatesKey;
static char kDYYYCommentGridHeightKey;
static NSDictionary *kDYYYCommentGridLastClosed;

@interface DYYYCommentGridModelsState : NSObject
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSMapTable *sources;
@property (nonatomic, weak) id list;
@property (nonatomic, assign) BOOL updating;
@end
@implementation DYYYCommentGridModelsState
@end

@implementation DYYYCommentMenuGrid

+ (BOOL)enabledForSection:(DYYYCommentMenuNormalSection *)section {
    UIViewController *controller = section.viewController;
    return NSThread.isMainThread && [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] &&
        ([DYYYCommentMenuTheme menuControllerForController:controller] != nil ||
         [NSStringFromClass(controller.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCollectionViewController"]);
}

+ (CGSize)sizeForSection:(id)section index:(NSInteger)index original:(CGSize)original collectionSize:(CGSize)size {
    if (![self enabledForSection:section]) return original;
    NSInteger count = [(DYYYCommentMenuNormalSection *)section numberOfItems];
    if (count <= 0 || index < 0 || index >= count || size.width < 280 || original.height < 36) return original;
    // 所有功能项合入同一渲染分区；奇数末项仍保持半宽，由原生布局属性居中。
    CGFloat left = floor((size.width - 32) * 0.5) + 16;
    return CGSizeMake(index % 2 == 0 ? left : size.width - left, original.height);
}

+ (UIView *)mainViewForCell:(UIView *)cell {
    Class base = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
    Ivar ivar = base ? class_getInstanceVariable(base, "$__lazy_storage_$_mainView") : NULL;
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if (!ivar || !type || type[0] != '@' || ![cell isKindOfClass:base]) return nil;
    id main = object_getIvar(cell, ivar);
    return [main isKindOfClass:UIView.class] ? main : nil;
}

+ (void)configureCell:(UIView *)cell section:(id)section index:(NSInteger)index model:(id)model {
    DYYYCommentGridModelsState *state = model ? [[self elementStates] objectForKey:model] : nil;
    if (state) objc_setAssociatedObject(cell, &kDYYYCommentGridCellStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (![cell isKindOfClass:UIView.class]) return;
    if (![self enabledForSection:section]) { [self restoreCell:cell]; return; }
    NSArray *info = @[ @(index), @([(DYYYCommentMenuNormalSection *)section numberOfItems]) ];
    if ([objc_getAssociatedObject(cell, &kDYYYCommentGridInfoKey) isEqual:info]) return;
    [self restoreContentInCell:cell];
    objc_setAssociatedObject(cell, &kDYYYCommentGridInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cell setNeedsLayout];
}

+ (void)restoreContentInCell:(UIView *)cell {
    NSDictionary *saved = objc_getAssociatedObject(cell, &kDYYYCommentGridTransformKey);
    UIView *main = [self mainViewForCell:cell];
    if (saved && main && CGAffineTransformEqualToTransform(main.transform, [saved[@"applied"] CGAffineTransformValue]))
        main.transform = [saved[@"original"] CGAffineTransformValue];
    objc_setAssociatedObject(cell, &kDYYYCommentGridTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)layoutCell:(UIView *)cell {
    NSArray *info = objc_getAssociatedObject(cell, &kDYYYCommentGridInfoKey);
    UIViewController *menu = [DYYYCommentMenuTheme controllerForView:cell];
    if (!info || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] || (!menu && cell.window)) {
        [self restoreCell:cell]; return;
    }
    if (!menu) return; // 创建期间先保留分区信息，实际挂入菜单后再对齐。
    DYYYCommentGridModelsState *state = objc_getAssociatedObject(cell, &kDYYYCommentGridCellStateKey);
    if (state) {
        NSHashTable *states = objc_getAssociatedObject(menu, &kDYYYCommentGridMenuStatesKey);
        if (!states) {
            states = [NSHashTable weakObjectsHashTable];
            objc_setAssociatedObject(menu, &kDYYYCommentGridMenuStatesKey, states, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [states addObject:state];
    }
    UIView *main = [self mainViewForCell:cell];
    if (!main || !main.superview || cell.bounds.size.width < 100) return;
    // 右列内容左移 12pt；只叠加可恢复 transform，原生约束、文字大小和点击逻辑继续生效。
    NSInteger index = [info[0] integerValue], count = [info[1] integerValue];
    BOOL centered = count % 2 == 1 && index == count - 1;
    CGFloat target = centered ? 10 : (index % 2 == 0 ? 16 : 4);
    CGPoint origin = [main.superview convertPoint:CGPointMake(main.center.x - main.bounds.size.width * 0.5,
        main.center.y - main.bounds.size.height * 0.5) toView:cell];
    NSDictionary *saved = objc_getAssociatedObject(cell, &kDYYYCommentGridTransformKey);
    CGAffineTransform current = main.transform;
    CGAffineTransform original = saved && CGAffineTransformEqualToTransform(current, [saved[@"applied"] CGAffineTransformValue]) ?
        [saved[@"original"] CGAffineTransformValue] : current;
    CGAffineTransform applied = original;
    applied.tx += target - origin.x;
    if (!CGAffineTransformEqualToTransform(current, applied)) {
        objc_setAssociatedObject(cell, &kDYYYCommentGridTransformKey,
            @{ @"original": [NSValue valueWithCGAffineTransform:original], @"applied": [NSValue valueWithCGAffineTransform:applied] },
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        main.transform = applied;
    }
}

+ (void)restoreCell:(UIView *)cell {
    [self restoreContentInCell:cell];
    objc_setAssociatedObject(cell, &kDYYYCommentGridInfoKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &kDYYYCommentGridCellStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSMapTable *)sectionStates {
    static NSMapTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSMapTable weakToWeakObjectsMapTable]; });
    return states;
}

+ (NSMapTable *)elementStates {
    static NSMapTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSMapTable weakToWeakObjectsMapTable]; });
    return states;
}

+ (id)registerSections:(NSArray *)sections list:(id)list {
    if (!NSThread.isMainThread || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] ||
        ![sections isKindOfClass:NSArray.class]) return nil;
    Class normal = NSClassFromString(@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionViewModel");
    NSMutableArray *functional = [NSMutableArray array];
    DYYYCommentGridModelsState *state = [DYYYCommentGridModelsState new];
    state.sources = [NSMapTable weakToStrongObjectsMapTable];
    state.list = list;
    for (id section in sections) {
        if (!normal || ![section isKindOfClass:normal]) continue;
        [functional addObject:section];
        DYYYCommentGridModelsState *previous = [[self sectionStates] objectForKey:section];
        NSArray *native = [(DYYYCommentMenuNormalSectionModel *)section modelsArray];
        NSArray *expected = section == previous.sections.firstObject ? [self mergedModels:previous] : @[];
        NSArray *models = previous.list == list && [native isEqualToArray:expected] ? [previous.sources objectForKey:section] : native;
        if (![models isKindOfClass:NSArray.class]) models = @[];
        [state.sources setObject:[models copy] forKey:section];
        [[self sectionStates] setObject:state forKey:section];
        for (id model in models) [[self elementStates] setObject:state forKey:model];
    }
    state.sections = [functional copy];
    objc_setAssociatedObject(list, &kDYYYCommentGridListStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return functional.firstObject;
}

+ (NSArray *)mergedModels:(DYYYCommentGridModelsState *)state {
    NSMutableArray *groups = [NSMutableArray array];
    for (id section in state.sections) [groups addObject:[state.sources objectForKey:section] ?: @[]];
    return [DYYYCommentMenuItems orderedModelsInSections:groups];
}

+ (BOOL)isManagedSectionModel:(id)section {
    return section && NSThread.isMainThread && [[self sectionStates] objectForKey:section] &&
        [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"];
}

+ (NSArray *)modelsForSection:(id)section incoming:(NSArray *)models {
    DYYYCommentGridModelsState *state = section ? [[self sectionStates] objectForKey:section] : nil;
    if (!NSThread.isMainThread || !state || state.updating || ![models isKindOfClass:NSArray.class]) return models;
    [state.sources setObject:[models copy] forKey:section];
    for (id model in models) [[self elementStates] setObject:state forKey:model];
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"]) return models;
    return state.sections.firstObject == section ? models : @[];
}

+ (void)didReplaceModelsInSection:(id)section {
    if (!section) return;
    DYYYCommentGridModelsState *state = [[self sectionStates] objectForKey:section];
    if (!NSThread.isMainThread || !state || state.updating ||
        ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"]) return;
    state.updating = YES;
    @try {
        // 更新同一份原生元素对象，保留它们的动作、禁用与彩色内容；好友分区完全不参与合并。
        // 先移除原分区的显示，再插入合并分区，避免相同原生元素同时出现在两个分区。
        for (id candidate in state.sections) {
            if (candidate == state.sections.firstObject) continue;
            if ([[(DYYYCommentMenuNormalSectionModel *)candidate modelsArray] count])
                [(DYYYCommentMenuNormalSectionModel *)candidate replaceByModels:@[] animated:NO sync:YES];
        }
        id first = state.sections.firstObject;
        NSArray *target = [self mergedModels:state];
        if (first && ![[(DYYYCommentMenuNormalSectionModel *)first modelsArray] isEqualToArray:target])
            [(DYYYCommentMenuNormalSectionModel *)first replaceByModels:target animated:NO sync:YES];
    } @finally { state.updating = NO; }
}

+ (UICollectionView *)collectionForController:(UIViewController *)controller {
    if (![NSStringFromClass(controller.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCollectionViewController"]) return nil;
    for (UIView *view in controller.viewIfLoaded.subviews)
        if ([view isKindOfClass:UICollectionView.class]) return (id)view;
    return nil;
}

+ (BOOL)isMenuLayout:(UICollectionViewLayout *)layout {
    UICollectionView *list = layout.collectionView;
    UIViewController *owner = [list.superview.nextResponder isKindOfClass:UIViewController.class] ? (id)list.superview.nextResponder : nil;
    return NSThread.isMainThread && [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] &&
        list == [self collectionForController:owner];
}

+ (UICollectionViewLayoutAttributes *)adjustAttributes:(UICollectionViewLayoutAttributes *)attributes layout:(UICollectionViewLayout *)layout {
    if (!attributes || ![self isMenuLayout:layout] || attributes.representedElementCategory != UICollectionElementCategoryCell) return attributes;
    UICollectionView *list = layout.collectionView;
    NSInteger count = [list numberOfItemsInSection:attributes.indexPath.section];
    CGRect frame = attributes.frame;
    if (count % 2 == 0 || attributes.indexPath.item != count - 1 || frame.size.height < 36 ||
        frame.size.width < 100 || frame.size.width >= list.bounds.size.width * 0.75) return attributes;
    CGFloat left = (list.bounds.size.width - frame.size.width) * 0.5;
    if (fabs(frame.origin.x - left) < 0.1) return attributes;
    UICollectionViewLayoutAttributes *adjusted = [attributes copy];
    frame.origin.x = left;
    adjusted.frame = frame;
    return adjusted;
}

+ (BOOL)isComposerVisible:(UIView *)composer {
    if (!composer.window || composer.hidden || composer.alpha <= 0.01 || composer.bounds.size.height < 16) return NO;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:composer];
    for (NSUInteger index = 0; index < queue.count && index < 64; index++) {
        UIView *view = queue[index];
        if (view.hidden || view.alpha <= 0.01) continue;
        if ([view isKindOfClass:UIButton.class] && [((UIButton *)view).currentTitle containsString:@"发送"]) return YES;
        if ([view isKindOfClass:UIVisualEffectView.class]) [queue addObject:((UIVisualEffectView *)view).contentView];
        else [queue addObjectsFromArray:view.subviews];
    }
    return NO;
}

+ (CGFloat)renderedHeightForMenu:(UIViewController *)menu {
    Class shell = NSClassFromString(@"DUXVisualEffectView");
    for (UIView *view in menu.viewIfLoaded.subviews)
        if (shell && [view isKindOfClass:shell] && !view.hidden) return CGRectGetHeight(view.bounds);
    return 0;
}

+ (void)synchronizeMenuController:(UIViewController *)controller {
    NSMutableArray *queue = [NSMutableArray arrayWithObject:controller];
    for (NSUInteger index = 0; index < queue.count && index < 24; index++) {
        UIViewController *child = queue[index];
        if ([self collectionForController:child]) { [self synchronizeController:child]; return; }
        [queue addObjectsFromArray:child.childViewControllers];
    }
}

+ (void)synchronizeMenuControllerImmediately:(UIViewController *)controller {
    NSMutableDictionary *record = objc_getAssociatedObject(controller, &kDYYYCommentGridHeightKey);
    if ([record[@"applying"] boolValue]) return;
    BOOL immediate = [record[@"immediate"] boolValue];
    record[@"immediate"] = @YES;
    @try {
        [UIView performWithoutAnimation:^{ [self synchronizeMenuController:controller]; }];
    } @finally {
        if (!immediate) [record removeObjectForKey:@"immediate"];
    }
}

+ (void)applyHeightToMenu:(DYYYCommentLongPressPanelSheet *)sheet record:(NSMutableDictionary *)current {
    if (!sheet.viewIfLoaded.window || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] ||
        sheet.userDragging || [current[@"applying"] boolValue]) return;
    CGFloat height = [current[@"target"] doubleValue];
    CGFloat drawn = [self renderedHeightForMenu:sheet];
    if (![DYYYCommentMenuMetrics needsUpdateForTarget:height propertyHeight:sheet.sheetHeight renderedHeight:drawn]) return;
    if ([current[@"appliedSignature"] isEqual:current[@"targetSignature"]]) {
        if ([current[@"repairSignature"] isEqual:current[@"targetSignature"]]) return;
        current[@"repairSignature"] = current[@"targetSignature"];
    } else [current removeObjectForKey:@"repairSignature"];
    current[@"applying"] = @YES;
    @try {
        [UIView performWithoutAnimation:^{
            current[@"applied"] = @(height);
            current[@"appliedSignature"] = current[@"targetSignature"];
            [sheet updateSheetHeight:height withMinimumSheetHeight:MIN([current[@"minimum"] doubleValue], height) animated:NO completion:nil];
            // 数值未变而外壳仍旧时，通过原生入口重排；applying 阻止嵌套布局再次改高。
            if (fabs([self renderedHeightForMenu:sheet] - height) > 0.5 && [sheet respondsToSelector:@selector(updateSheetFrameAnimated:)]) {
                current[@"repairSignature"] = current[@"targetSignature"];
                [sheet updateSheetFrameAnimated:NO];
            }
        }];
        current[@"renderedHeight"] = @([self renderedHeightForMenu:sheet]);
        current[@"propertyHeight"] = @(sheet.sheetHeight);
        current[@"renderedMinimum"] = @(sheet.minimumSheetHeight);
    } @finally { [current removeObjectForKey:@"applying"]; }
}

+ (void)synchronizeController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYCommentLongPressPanelSheet *menu = (id)[DYYYCommentMenuTheme menuControllerForController:controller];
    UICollectionView *list = [self collectionForController:controller];
    if (!menu || !list.window || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] ||
        list.dragging || list.decelerating || menu.userDragging ||
        ![menu respondsToSelector:@selector(updateSheetHeight:withMinimumSheetHeight:animated:completion:)]) return;
    CGFloat content = list.contentSize.height;
    if (!isfinite(content) || content < 100 || list.bounds.size.height < 100 || menu.sheetHeight <= 0) return;
    NSMutableDictionary *record = objc_getAssociatedObject(menu, &kDYYYCommentGridHeightKey);
    if ([record[@"applying"] boolValue]) return;
    if (!record) {
        CGFloat inset = MIN(64, MAX(0, menu.sheetHeight - list.bounds.size.height));
        record = [@{ @"original": @(menu.sheetHeight), @"minimum": @(menu.minimumSheetHeight), @"inset": @(inset) } mutableCopy];
        objc_setAssociatedObject(menu, &kDYYYCommentGridHeightKey, record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat rawContent = content, composerHeight = 0, firstRowBottom = 0, actionBottom = 0;
    NSArray *attributes = [list.collectionViewLayout layoutAttributesForElementsInRect:CGRectMake(0, 0, list.bounds.size.width, rawContent)];
    for (UICollectionViewLayoutAttributes *item in attributes) {
        if (item.representedElementCategory != UICollectionElementCategoryCell || item.size.height < 36 ||
            item.size.width < 100 || item.size.width >= list.bounds.size.width * 0.75) continue;
        CGFloat bottom = CGRectGetMaxY(item.frame);
        actionBottom = MAX(actionBottom, bottom);
        if (!firstRowBottom || bottom < firstRowBottom) firstRowBottom = bottom;
    }
    content = [DYYYCommentMenuMetrics contentHeightForActionBottom:actionBottom
        safeAreaBottom:list.window.safeAreaInsets.bottom rawContent:rawContent];
    Class composerClass = NSClassFromString(@"AWEIMShareImpl.ShareAdditionTextView");
    for (UIView *view in list.superview.subviews) {
        if (!composerClass || ![view isKindOfClass:composerClass] || ![self isComposerVisible:view]) continue;
        // 不再使用 list.bounds.height - composer.y：键盘会移动输入区，这个差值不是发送区高度。
        composerHeight = CGRectGetHeight(view.bounds) + list.window.safeAreaInsets.bottom;
        for (UIView *plate in list.superview.subviews) {
            if (plate == view || ![NSStringFromClass(plate.class) isEqualToString:@"UIView"] || plate.hidden || plate.alpha <= 0.01 || plate.subviews.count) continue;
            CGFloat height = CGRectGetHeight(plate.bounds);
            if (fabs(CGRectGetMinY(plate.frame) - CGRectGetMinY(view.frame)) < 2 &&
                CGRectGetWidth(plate.bounds) >= CGRectGetWidth(list.bounds) * 0.9 &&
                height >= CGRectGetHeight(view.bounds) && height <= CGRectGetHeight(view.bounds) + 64)
                composerHeight = MAX(composerHeight, height);
        }
        break;
    }
    CGFloat target = [DYYYCommentMenuMetrics compactHeightForContent:content inset:[record[@"inset"] doubleValue]
        firstRowBottom:firstRowBottom composerHeight:composerHeight
        maximum:MIN([record[@"original"] doubleValue], list.window.bounds.size.height * 0.9)];
    record[@"selectionActive"] = @(composerHeight > 0);
    record[@"composerHeight"] = @(composerHeight);
    record[@"contentHeight"] = @(content);
    record[@"rawContentHeight"] = @(rawContent);
    record[@"actionBottom"] = @(actionBottom);
    record[@"target"] = @(target);
    CGFloat rendered = [self renderedHeightForMenu:menu];
    record[@"renderedHeight"] = @(rendered);
    record[@"propertyHeight"] = @(menu.sheetHeight);
    NSArray *signature = @[ @(target), @(composerHeight > 0), @(list.bounds.size.width) ];
    record[@"targetSignature"] = signature;
    BOOL needsUpdate = [DYYYCommentMenuMetrics needsUpdateForTarget:target propertyHeight:menu.sheetHeight renderedHeight:rendered];
    if (!needsUpdate) return;
    if ([record[@"immediate"] boolValue]) {
        [self applyHeightToMenu:menu record:record]; return;
    }
    if ([record[@"scheduled"] boolValue]) return;
    record[@"scheduled"] = @YES;
    __weak DYYYCommentLongPressPanelSheet *weakMenu = menu;
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYCommentLongPressPanelSheet *sheet = weakMenu;
        NSMutableDictionary *current = objc_getAssociatedObject(sheet, &kDYYYCommentGridHeightKey);
        if (current != record) return;
        current[@"scheduled"] = @NO;
        [self applyHeightToMenu:sheet record:current];
    });
}

+ (CGFloat)constrainedHeight:(CGFloat)height controller:(UIViewController *)controller {
    NSMutableDictionary *record = objc_getAssociatedObject(controller, &kDYYYCommentGridHeightKey);
    DYYYCommentLongPressPanelSheet *sheet = (id)controller;
    if (!isfinite(height) || height <= 0 || !record[@"applied"] || sheet.userDragging || sheet.isBeingDismissed ||
        ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"]) return height;
    record[@"lastNativeHeightRequest"] = @(height);
    if (height > [record[@"original"] doubleValue]) record[@"original"] = @(height);
    // 原生刷新仍可能写入旧单列高度，在同一个入口使用目标值，避免布局后反复改高/改低。
    return [DYYYCommentMenuMetrics constrainedNativeHeight:height target:[record[@"target"] doubleValue] managed:YES];
}

+ (CGFloat)constrainedMinimumHeight:(CGFloat)height controller:(UIViewController *)controller {
    NSMutableDictionary *record = objc_getAssociatedObject(controller, &kDYYYCommentGridHeightKey);
    DYYYCommentLongPressPanelSheet *sheet = (id)controller;
    BOOL managed = record[@"applied"] && !sheet.userDragging && !sheet.isBeingDismissed &&
        [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"];
    if (managed) record[@"lastNativeMinimumRequest"] = @(height);
    return [DYYYCommentMenuMetrics constrainedNativeHeight:height target:[record[@"target"] doubleValue] managed:managed];
}

+ (void)restoreController:(UIViewController *)controller {
    NSMutableDictionary *record = objc_getAssociatedObject(controller, &kDYYYCommentGridHeightKey);
    DYYYCommentLongPressPanelSheet *menu = (id)controller;
    if (record) {
        kDYYYCommentGridLastClosed = @{ @"height": [record copy], @"propertyHeight": @(menu.sheetHeight),
            @"renderedHeight": @([self renderedHeightForMenu:menu]), @"capturedAt": @([NSDate date].timeIntervalSince1970) };
    }
    objc_setAssociatedObject(controller, &kDYYYCommentGridHeightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (record[@"applied"] && fabs(menu.sheetHeight - [record[@"applied"] doubleValue]) < 0.5)
        [menu updateSheetHeight:[record[@"original"] doubleValue] withMinimumSheetHeight:[record[@"minimum"] doubleValue] animated:NO completion:nil];
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"]) {
        NSHashTable *states = objc_getAssociatedObject(controller, &kDYYYCommentGridMenuStatesKey);
        for (DYYYCommentGridModelsState *state in states.allObjects) {
            state.updating = YES;
            @try {
                for (id section in state.sections)
                    [(DYYYCommentMenuNormalSectionModel *)section replaceByModels:[state.sources objectForKey:section] ?: @[] animated:NO sync:YES];
            } @finally { state.updating = NO; }
        }
    }
}

+ (NSDictionary *)lastClosedDiagnostics {
    return kDYYYCommentGridLastClosed ?: @{};
}

+ (NSDictionary *)diagnosticsForController:(UIViewController *)controller {
    NSDictionary *record = objc_getAssociatedObject(controller, &kDYYYCommentGridHeightKey);
    NSHashTable *states = objc_getAssociatedObject(controller, &kDYYYCommentGridMenuStatesKey);
    NSMutableArray *counts = [NSMutableArray array];
    for (DYYYCommentGridModelsState *state in states.allObjects) [counts addObject:@([self mergedModels:state].count)];
    return @{ @"height": record ?: @{}, @"mergedItemCounts": counts };
}
@end
