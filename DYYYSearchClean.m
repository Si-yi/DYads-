/*
移植自 DYKiller/src/Features/SearchClean，适配 DYYY 的设置与偏好键。

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

#import "DYYYSearchClean.h"
#import "AwemeHeaders.h"
#import "DYYYConstants.h"
#import "DYYYOptionsSelectionView.h"
#import "DYYYSettingsHelper.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>

static char kDYYYSearchCameraMaskKey;
static char kDYYYSearchFooterTargetKey;
static char kDYYYSearchFooterHiddenKey;

@implementation DYYYSearchClean

+ (NSDictionary *)dictionary:(id)value {
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}
+ (NSString *)string:(id)value {
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}
+ (NSDictionary *)rankEntry:(id)value {
    NSDictionary *entry = [self dictionary:value];
    NSString *rankID = [self string:entry[@"id"]];
    if (!rankID) return nil;
    NSString *title = [rankID isEqualToString:@"CITY"] ? @"同城榜" : [self string:entry[@"title"]];
    return @{ @"id": rankID, @"title": title ?: rankID };
}
+ (NSArray<NSDictionary *> *)rankCatalog {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:DYYY_SEARCH_RANK_CATALOG_KEY];
    if (![stored isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *catalog = [NSMutableArray array];
    NSMutableSet *known = [NSMutableSet set];
    for (id value in stored) {
        NSDictionary *entry = [self rankEntry:value];
        if (!entry || [known containsObject:entry[@"id"]]) continue;
        [known addObject:entry[@"id"]]; [catalog addObject:entry];
    }
    return catalog;
}
+ (void)recordRanks:(NSArray<NSDictionary *> *)entries {
    if (!entries.count) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    @synchronized (defaults) {
        NSArray *old = [self rankCatalog];
        NSMutableArray *catalog = [old mutableCopy];
        NSMutableDictionary *indices = [NSMutableDictionary dictionary];
        [catalog enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger index, BOOL *stop) {
            indices[entry[@"id"]] = @(index);
        }];
        for (id value in entries) {
            NSDictionary *entry = [self rankEntry:value];
            if (!entry) continue;
            NSNumber *index = indices[entry[@"id"]];
            if (index) catalog[index.unsignedIntegerValue] = entry;
            else { indices[entry[@"id"]] = @(catalog.count); [catalog addObject:entry]; }
        }
        if (![old isEqualToArray:catalog]) [defaults setObject:catalog forKey:DYYY_SEARCH_RANK_CATALOG_KEY];
    }
}
+ (NSString *)rankHideKey:(NSString *)rankID {
    return [DYYY_SEARCH_RANK_HIDE_PREFIX stringByAppendingString:rankID ?: @""];
}
+ (BOOL)rankHidden:(NSString *)rankID {
    return rankID.length && DYYYGetBool([self rankHideKey:rankID]);
}
+ (NSArray *)visibleRanks:(NSArray *)tabs identifier:(NSString *(^)(id))identifier {
    if (DYYYGetBool(DYYY_SEARCH_REMOVE_ALL_RANKS_KEY)) return @[];
    NSMutableArray *visible = [NSMutableArray arrayWithCapacity:tabs.count];
    for (id tab in tabs) if (![self rankHidden:identifier(tab)]) [visible addObject:tab];
    return visible.count == tabs.count ? tabs : visible;
}
+ (BOOL)templateURL:(NSString *)url matchesBundle:(NSString *)bundle {
    if (![url isKindOfClass:NSString.class]) return NO;
    NSURLComponents *parts = [NSURLComponents componentsWithString:url];
    NSString *path = [bundle stringByAppendingString:@"/template.js"];
    if ([[parts.path lastPathComponent] isEqualToString:@"template.js"] &&
        [[parts.path stringByDeletingLastPathComponent].lastPathComponent isEqualToString:bundle]) return YES;
    for (NSURLQueryItem *item in parts.queryItems)
        if ([item.name isEqualToString:@"bundle"] && [item.value isEqualToString:path]) return YES;
    return NO;
}
+ (NSDictionary *)cleanGlobalProps:(NSDictionary *)props url:(NSString *)url {
    if (![props isKindOfClass:NSDictionary.class]) return props;
    BOOL removeHistory = DYYYGetBool(DYYY_SEARCH_REMOVE_HISTORY_KEY);
    BOOL removeGuess = DYYYGetBool(DYYY_SEARCH_REMOVE_GUESS_KEY);
    if (!removeHistory && !removeGuess) return props;
    if (![self templateURL:url matchesBundle:@"search_transfer_growth"] &&
        ![self templateURL:props[@"originUrl"] matchesBundle:@"search_transfer_growth"] &&
        ![self templateURL:props[@"resolvedUrl"] matchesBundle:@"search_transfer_growth"]) return props;
    NSMutableDictionary *result = [props mutableCopy];
    NSMutableDictionary *ab = [[self dictionary:props[@"abParams"]] mutableCopy];
    NSDictionary *page = [self dictionary:ab[@"search_transfer_v2_page_conf"]];
    id components = page[@"pageComponents"];
    if ([components isKindOfClass:NSArray.class]) {
        NSMutableArray *rows = [NSMutableArray array];
        for (id value in components) {
            NSDictionary *row = [self dictionary:value];
            BOOL remove = (removeHistory && [row[@"key"] isEqual:@"history"]) ||
                          (removeGuess && [row[@"key"] isEqual:@"guessSearch"]);
            if (remove) {
                NSMutableDictionary *copy = [row mutableCopy]; copy[@"show"] = @NO; [rows addObject:copy];
            } else [rows addObject:value];
        }
        NSMutableDictionary *copy = [page mutableCopy]; copy[@"pageComponents"] = rows;
        ab[@"search_transfer_v2_page_conf"] = copy;
    }
    if (removeGuess) {
        NSMutableDictionary *experiments = [[self dictionary:ab[@"search_transfer_experiments"]] mutableCopy];
        experiments[@"force_enable_recom_search"] = @0; ab[@"search_transfer_experiments"] = experiments;
    }
    result[@"abParams"] = ab;
    return result;
}

#pragma mark - 搜索入口和榜单按钮

+ (NSInteger)cameraMode {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:DYYY_SEARCH_CAMERA_MODE_KEY];
    if ([value isKindOfClass:NSNumber.class]) return MAX(0, MIN(2, [value integerValue]));
    NSUInteger index = [@[@"显示", @"隐藏", @"移除"] indexOfObject:value ?: @""];
    return index == NSNotFound ? 0 : (NSInteger)index;
}
+ (UIView *)existingCameraForOwner:(id)owner {
    Ivar ivar = class_getInstanceVariable([owner class], "_scanButton");
    if (!ivar || ivar_getTypeEncoding(ivar)[0] != '@') return nil;
    id view = object_getIvar(owner, ivar);
    return [view isKindOfClass:UIView.class] ? view : nil;
}
+ (void)applyCamera:(UIView *)view {
    if (!view) return;
    if (!NSThread.isMainThread) {
        __weak UIView *weakView = view;
        dispatch_async(dispatch_get_main_queue(), ^{ [self applyCamera:weakView]; }); return;
    }
    // alpha=0 会使 UIKit 不再命中；透明遮罩只隐藏外观，保留原位置和点击。
    CALayer *mask = objc_getAssociatedObject(view, &kDYYYSearchCameraMaskKey);
    BOOL owned = mask && view.layer.mask == mask;
    if ([self cameraMode] != 1) {
        if (owned) view.layer.mask = nil;
        objc_setAssociatedObject(view, &kDYYYSearchCameraMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
    }
    if (view.layer.mask && !owned) return;
    if (!mask) {
        mask = [CALayer layer];
        objc_setAssociatedObject(view, &kDYYYSearchCameraMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    mask.frame = CGRectInset(view.bounds, -view.bounds.size.width, -view.bounds.size.height);
    mask.backgroundColor = UIColor.clearColor.CGColor;
    if (!owned) view.layer.mask = mask;
    [CATransaction commit];
}
+ (BOOL)removeRankFooter {
    return DYYYGetBool(DYYY_SEARCH_REMOVE_ALL_RANKS_KEY) || DYYYGetBool(DYYY_SEARCH_REMOVE_RANK_FOOTER_KEY);
}
+ (BOOL)isFooterTarget:(LynxUI *)ui {
    return [objc_getAssociatedObject(ui, &kDYYYSearchFooterTargetKey) boolValue];
}
+ (void)updateFooter:(LynxUI *)ui label:(NSString *)label {
    BOOL candidate = [label isKindOfClass:NSString.class] && [label hasPrefix:@"查看完整"];
    if (!candidate && ![self isFooterTarget:ui]) return;
    NSString *url = nil;
    if (candidate) {
        @try { url = [[ui.context valueForKey:@"rootView"] valueForKey:@"url"]; }
        @catch (__unused NSException *e) {}
    }
    BOOL target = candidate && [self templateURL:url matchesBundle:@"search_transfer_rank"];
    objc_setAssociatedObject(ui, &kDYYYSearchFooterTargetKey, target ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self applyFooter:ui];
}
+ (void)applyFooter:(LynxUI *)ui {
    if (!NSThread.isMainThread) {
        __weak LynxUI *weakUI = ui;
        dispatch_async(dispatch_get_main_queue(), ^{ if (weakUI) [self applyFooter:weakUI]; }); return;
    }
    UIView *view = ui.view;
    if (!view) return;
    BOOL remove = [self isFooterTarget:ui] && [self removeRankFooter];
    NSNumber *original = objc_getAssociatedObject(view, &kDYYYSearchFooterHiddenKey);
    if (remove) {
        if (!original) objc_setAssociatedObject(view, &kDYYYSearchFooterHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.hidden = YES;
    } else if (original) {
        if (view.hidden) view.hidden = original.boolValue;
        objc_setAssociatedObject(view, &kDYYYSearchFooterHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - 隐藏设置中的单个搜索页分区

+ (NSString *)rankDetail {
    NSUInteger count = 0;
    for (NSDictionary *entry in [self rankCatalog]) if ([self rankHidden:entry[@"id"]]) count++;
    return count ? [NSString stringWithFormat:@"已移除 %lu 项", (unsigned long)count] : @"未移除";
}
+ (AWESettingItemModel *)switchWithKey:(NSString *)key title:(NSString *)title note:(NSString *)note {
    return [DYYYSettingsHelper createSettingItem:@{ @"identifier": key, @"title": title, @"subTitle": note ?: @"",
        @"detail": @"", @"cellType": @6, @"imageName": @"ic_eyeslash_outlined_16" }];
}
+ (void)openRanks:(AWESettingItemModel *)entry rootViewController:(UIViewController *)rootVC {
    NSMutableArray *rows = [NSMutableArray array];
    __weak AWESettingItemModel *weakEntry = entry;
    for (NSDictionary *rank in [self rankCatalog]) {
        AWESettingItemModel *row = [self switchWithKey:[self rankHideKey:rank[@"id"]] title:rank[@"title"] note:@"移除此榜单标签及其内容，重启抖音后生效"];
        void (^changed)(void) = [row.switchChangedBlock copy];
        row.switchChangedBlock = ^{
            if (changed) changed();
            weakEntry.detail = [self rankDetail]; [weakEntry refreshCell];
        };
        [rows addObject:row];
    }
    NSString *note = rows.count ? @"新榜单会在打开搜索页时自动收录；修改后重启抖音生效。" : @"尚未收录榜单，请先打开一次抖音搜索页，再返回这里选择。";
    AWESettingSectionModel *section = [DYYYSettingsHelper createSectionWithTitle:@"移除榜单" footerTitle:note items:rows];
    AWESettingBaseViewController *vc = [DYYYSettingsHelper createSubSettingsViewController:@"移除搜索榜单" sections:@[section]];
    UIViewController *presenter = topView() ?: rootVC;
    [(presenter.navigationController ?: rootVC.navigationController) pushViewController:(UIViewController *)vc animated:YES];
}
+ (NSArray<AWESettingItemModel *> *)settingsItemsWithRootViewController:(UIViewController *)rootVC {
    AWESettingItemModel *history = [self switchWithKey:DYYY_SEARCH_REMOVE_HISTORY_KEY title:@"移除历史搜索区域" note:@"保留已存储的搜索历史"];
    AWESettingItemModel *guess = [self switchWithKey:DYYY_SEARCH_REMOVE_GUESS_KEY title:@"移除猜你想搜区域" note:@"同时移除区域占位"];
    AWESettingItemModel *all = [self switchWithKey:DYYY_SEARCH_REMOVE_ALL_RANKS_KEY title:@"移除全部榜单" note:@"包括榜单标签、内容和完整榜单按钮，下方榜单配置保留"];
    AWESettingItemModel *ranks = [DYYYSettingsHelper createSettingItem:@{ @"identifier": DYYY_SEARCH_RANKS_KEY, @"title": @"移除搜索榜单", @"cellType": @26, @"imageName": @"ic_squaresplit_outlined_20" }];
    ranks.type = 0; ranks.detail = [self rankDetail];
    __weak AWESettingItemModel *weakRanks = ranks;
    __weak UIViewController *weakRoot = rootVC;
    ranks.cellTappedBlock = ^{
        AWESettingItemModel *item = weakRanks;
        if (item.isEnable) [self openRanks:item rootViewController:weakRoot];
    };
    AWESettingItemModel *footer = [self switchWithKey:DYYY_SEARCH_REMOVE_RANK_FOOTER_KEY title:@"移除查看完整榜单按钮" note:@"移除搜索榜单底部入口并阻止点击"];
    AWESettingItemModel *voice = [self switchWithKey:DYYY_SEARCH_REMOVE_VOICE_KEY title:@"移除语音输入" note:@"包括搜索页和展开键盘后的语音入口"];
    AWESettingItemModel *camera = [DYYYSettingsHelper createSettingItem:@{ @"identifier": DYYY_SEARCH_CAMERA_MODE_KEY, @"title": @"相机入口", @"cellType": @26, @"imageName": @"ic_cameralogo_outlined_20" }];
    camera.type = 0; camera.detail = @[@"显示", @"隐藏", @"移除"][[self cameraMode]];
    camera.subTitle = @"隐藏保留位置与点击；移除后按原生布局收拢";
    __weak AWESettingItemModel *weakCamera = camera;
    camera.cellTappedBlock = ^{
        [DYYYOptionsSelectionView showWithPreferenceKey:DYYY_SEARCH_CAMERA_MODE_KEY optionsArray:@[@"显示", @"隐藏", @"移除"] headerText:@"搜索页相机入口" onPresentingVC:topView() ?: weakRoot selectionChanged:^(NSString *value) {
            weakCamera.detail = value; [weakCamera refreshCell];
        }];
    };
    return @[history, guess, all, ranks, footer, voice, camera];
}
@end
