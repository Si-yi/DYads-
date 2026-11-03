/*
  播放页目录身份与整行显隐参考 DYKiller：
  src/Features/PlaybackClean/DKPlaybackCatalog.m
  src/Features/PlaybackClean/DKPlaybackCleanRules.m
  https://github.com/HierarchThurs/DYKiller/tree/bb11ab1d9cba9733d6720f0e2746dec21d6c6fe4

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
#import "DYYYPlaybackCatalog.h"
#import "DYYYPlaybackCatalogStore.h"
#import "DYYYCollectionRows.h"
#import "DYYYSettingsHelper.h"
#import "DYYYOptionsSelectionView.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

static char kDYYYCatalogModeKey, kDYYYCatalogMaskKey, kDYYYCatalogBusyKey;
static NSMutableArray *DYYYCatalogRejected;
@interface DYYYPlaybackMaskState : NSObject
@property (nonatomic, strong) CALayer *nativeMask;
@property (nonatomic, strong) CALayer *mask;
@end
@implementation DYYYPlaybackMaskState
@end

@implementation DYYYPlaybackCatalog
+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *e) { return nil; }
}
+ (NSString *)string:(id)value {
    return [value isKindOfClass:NSString.class] ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
}
+ (BOOL)object:(id)object is:(NSString *)name {
    Class cls = NSClassFromString(name); return cls && [object isKindOfClass:cls];
}
+ (id)anchorInRow:(UIView *)row {
    NSMutableArray *views = [NSMutableArray arrayWithObject:row];
    for (NSUInteger depth = 0; depth <= 4 && views.count; depth++) {
        NSMutableArray *next = [NSMutableArray array];
        for (UIView *view in views) {
            if ([self object:view is:@"AWEFeedTemplateAnchorViewV2"]) return view;
            if (next.count + view.subviews.count <= 128) [next addObjectsFromArray:view.subviews];
        }
        views = next;
    }
    return nil;
}
+ (NSDictionary *)entryForRow:(UIView *)row kind:(NSUInteger)kind controller:(id)controller {
    id element = [self value:row key:@"element"];
    NSString *identity = nil, *title = nil;
    if (kind == 0) {
        if ([self object:element is:@"AWEPlayInteractionLearnMoreLynxTopElement"]) {
            identity = @"AWEPlayInteractionLearnMoreLynxTopElement"; title = @"推广卡片";
        } else {
            id info = [self value:[self anchorInRow:row] key:@"templateAnchorInfo"];
            identity = [self string:[self value:info key:@"name"]];
            title = [self string:[self value:[self value:info key:@"titleModel"] key:@"content"]];
            if (!title.length) title = [self string:[self value:[self value:info key:@"descModel"] key:@"content"]];
            if ([identity isEqual:@"openplatform_anchor"]) {
                NSString *extra = [self string:[self value:info key:@"extra"]];
                if (extra.length > 65536) return nil;
                NSData *data = [extra dataUsingEncoding:NSUTF8StringEncoding];
                id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
                id base = [object isKindOfClass:NSDictionary.class] ? object[@"base"] : nil;
                NSString *client = [self string:[self value:base key:@"client_key"]];
                if (!client.length) return nil;
                identity = [identity stringByAppendingFormat:@":%@", client];
                NSString *app = [self string:[self value:base key:@"app_name"]];
                if (app.length) title = app;
            }
        }
    } else {
        identity = [self string:[self value:element key:@"identifier"]];
        if ([self object:element is:@"AWEPlayInteractionNewMixVideoInfoElement"]) identity = @"video_collection";
        if ([self object:element is:@"AWEPlayInteractionRelatedVideoNewBottomElement"]) identity = @"AWEPlayInteractionRelatedVideoNewBottomElement";
        if ([identity isEqual:@"playlet_bar"]) {
            id model = [self value:controller key:@"model"];
            if (!model) return nil;
            id playlet = [self value:model key:@"playletInfoModel"];
            identity = playlet && playlet != NSNull.null ? @"short_play_collection" : @"video_collection";
        }
        id bar = [self value:[self value:[self value:element key:@"providerManager"] key:@"currentProvider"] key:@"barModel"];
        title = [self string:[self value:bar key:@"name"]];
        if (!title.length) title = [self string:[self value:[self value:bar key:@"title"] key:@"text"]];
        if (!title.length) title = [self string:[self value:[self value:bar key:@"mainContent"] key:@"text"]];
        if (!identity.length && title.length) identity = NSStringFromClass([element class]);
    }
    return [DYYYPlaybackCatalogStore descriptorWithKind:kind identifier:identity title:title];
}
+ (NSInteger)cachedModeForRow:(UIView *)row {
    NSNumber *mode = objc_getAssociatedObject(row, &kDYYYCatalogModeKey);
    return mode ? mode.integerValue : -1;
}
+ (void)maskRow:(UIView *)row hide:(BOOL)hide {
    DYYYPlaybackMaskState *state = objc_getAssociatedObject(row, &kDYYYCatalogMaskKey);
    if (hide) {
        if (!state) { state = [DYYYPlaybackMaskState new]; state.mask = [CALayer layer]; objc_setAssociatedObject(row, &kDYYYCatalogMaskKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        if (row.layer.mask != state.mask) { state.nativeMask = row.layer.mask; row.layer.mask = state.mask; }
    } else if (state) {
        if (row.layer.mask == state.mask) row.layer.mask = state.nativeMask;
        objc_setAssociatedObject(row, &kDYYYCatalogMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
+ (void)recordRejectedElement:(id)element {
    if (!element) return;
    if (!DYYYCatalogRejected) DYYYCatalogRejected = [NSMutableArray array];
    NSDictionary *record = @{@"elementClass": NSStringFromClass([element class]), @"reason": @"缺少可用稳定身份或语义名称"};
    if (DYYYCatalogRejected.count < 32 && ![DYYYCatalogRejected containsObject:record]) [DYYYCatalogRejected addObject:record];
}
+ (void)prepareStack:(UIView *)stack {
    if (!NSThread.isMainThread || objc_getAssociatedObject(stack, &kDYYYCatalogBusyKey)) return;
    objc_setAssociatedObject(stack, &kDYYYCatalogBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        UIViewController *controller = nil;
        UIResponder *responder = stack.nextResponder;
        for (NSUInteger i = 0; responder && i < 20; i++, responder = responder.nextResponder) {
            if ([self object:responder is:@"AWEPlayInteractionViewController"]) { controller = (id)responder; break; }
        }
        BOOL bottom = controller && [self value:controller key:@"bottomContainerView"] == stack;
        NSMutableArray *rows = [stack.subviews mutableCopy];
        if ([stack respondsToSelector:@selector(arrangedSubviews)]) for (UIView *row in ((UIStackView *)stack).arrangedSubviews) if (![rows containsObject:row]) [rows addObject:row];
        DYYYPlaybackCatalogStore *store = DYYYPlaybackCatalogStore.sharedStore;
        BOOL visible = controller.isViewLoaded && controller.view.window && !controller.view.hidden && controller.view.alpha > 0.01;
        if (visible) visible = CGRectIntersectsRect([controller.view convertRect:controller.view.bounds toView:controller.view.window], controller.view.window.bounds);
        id displaying = [self value:controller key:@"isDisplaying"];
        id preload = [self value:controller key:@"isPreload"];
        visible = visible && [displaying respondsToSelector:@selector(boolValue)] && [displaying boolValue] && ![preload boolValue];
        for (NSUInteger i = 0; i < rows.count && i < 64; i++) {
            UIView *row = rows[i];
            id element = [self value:row key:@"element"];
            BOOL anchor = [self object:element is:@"AWEPlayInteractionAnchorElement"] || [self object:element is:@"AWEPlayInteractionLearnMoreLynxTopElement"];
            BOOL knownBottom = [self object:element is:@"AWEPlayInteractionNewMixVideoInfoElement"] || [self object:element is:@"AWEPlayInteractionRelatedVideoNewBottomElement"];
            BOOL managed = controller && [self object:row is:@"AWEBaseElementView"] && element && (anchor || bottom || knownBottom);
            NSInteger mode = -1;
            if (managed) {
                NSUInteger kind = anchor ? 0 : 1;
                NSDictionary *entry = [self entryForRow:row kind:kind controller:controller];
                mode = entry ? [store modeForEntry:entry] : [store masterMode:kind];
                if (visible && ![store masterMode:kind]) {
                    if (entry) [store record:entry]; else [self recordRejectedElement:element];
                }
                // 未识别的行不覆盖已有专项合集隐藏逻辑。
                if (!entry && !mode) mode = -1;
            }
            objc_setAssociatedObject(row, &kDYYYCatalogModeKey, mode < 0 ? nil : @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self maskRow:row hide:mode == 1];
        }
    } @finally { objc_setAssociatedObject(stack, &kDYYYCatalogBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
+ (void)refresh { [DYYYCollectionRows refreshVisibleStacks]; }
+ (AWESettingItemModel *)modeItem:(NSString *)key title:(NSString *)title note:(NSString *)note mode:(NSInteger)mode root:(UIViewController *)root {
    AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:@{@"identifier": key, @"title": title, @"subTitle": note ?: @"", @"cellType": @26, @"imageName": @"ic_eyeslash_outlined_16"}];
    item.type = 0; item.detail = @[@"显示", @"隐藏", @"移除"][mode];
    __weak AWESettingItemModel *weakItem = item;
    __weak UIViewController *weakRoot = root;
    item.cellTappedBlock = ^{
        // 选择器原生接口只接收字符串；兼容旧备份中的数值档位和旧布尔开关回退。
        id stored = [NSUserDefaults.standardUserDefaults objectForKey:key];
        if (![stored isKindOfClass:NSString.class] || ![@[@"显示", @"隐藏", @"移除"] containsObject:stored]) {
            NSInteger selected = stored ? [DYYYPlaybackCatalogStore modeFromValue:stored] : mode;
            [NSUserDefaults.standardUserDefaults setObject:@[@"显示", @"隐藏", @"移除"][selected] forKey:key];
        }
        [DYYYOptionsSelectionView showWithPreferenceKey:key optionsArray:@[@"显示", @"隐藏", @"移除"] headerText:title onPresentingVC:weakRoot.navigationController.topViewController ?: weakRoot selectionChanged:^(NSString *value) {
            weakItem.detail = value; [weakItem refreshCell]; [self refresh];
        }];
    };
    return item;
}
+ (NSArray<AWESettingItemModel *> *)settingsItemsWithRoot:(UIViewController *)root {
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger kind = 0; kind < 2; kind++) {
        NSString *title = kind ? @"底部相关栏目目录" : @"昵称上方标签目录";
        AWESettingItemModel *item = [DYYYSettingsHelper createSettingItem:@{@"identifier": [NSString stringWithFormat:@"DYYYPlaybackCatalogPage%lu", (unsigned long)kind], @"title": title, @"cellType": @26, @"imageName": @"ic_collection_outlined_20"}];
        item.type = 0;
        __weak UIViewController *weakRoot = root;
        item.cellTappedBlock = ^{
            DYYYPlaybackCatalogStore *store = DYYYPlaybackCatalogStore.sharedStore;
            NSMutableArray *rows = [NSMutableArray arrayWithObject:[self modeItem:[DYYYPlaybackCatalogStore masterKey:kind] title:@"统一档位" note:@"显示时按每项设置；隐藏保留占位，移除收起整行。" mode:[store masterMode:kind] root:weakRoot]];
            for (NSDictionary *entry in [store entries:kind]) {
                NSString *key = [DYYYPlaybackCatalogStore itemKey:kind identifier:entry[@"id"]];
                // 单项显示独立档位，不把总开关档位误存为每项偏好。
                id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
                NSInteger mode = value ? [DYYYPlaybackCatalogStore modeFromValue:value] : ([NSUserDefaults.standardUserDefaults boolForKey:entry[@"legacy"] ?: @""] ? 2 : 0);
                [rows addObject:[self modeItem:key title:entry[@"title"] note:nil mode:mode root:weakRoot]];
            }
            AWESettingSectionModel *section = [DYYYSettingsHelper createSectionWithTitle:title footerTitle:@"隐藏保留原位置与点击，移除收起整行。正常浏览播放页时收录新类型；缺少稳定身份或名称的项目不登记。修改旧版已隐藏项目后，重新进入作品生效。" items:rows];
            UIViewController *page = (id)[DYYYSettingsHelper createSubSettingsViewController:title sections:@[section]];
            [weakRoot.navigationController pushViewController:page animated:YES];
        };
        [items addObject:item];
    }
    return items;
}
+ (NSDictionary *)diagnostics {
    DYYYPlaybackCatalogStore *store = DYYYPlaybackCatalogStore.sharedStore;
    return @{@"anchors": @([store entries:0].count), @"bottomBars": @([store entries:1].count), @"anchorMode": @([store masterMode:0]), @"bottomMode": @([store masterMode:1]), @"rejected": DYYYCatalogRejected.copy ?: @[]};
}
@end
