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
#import "DYYYArticleBackdrop.h"
#import "AwemeHeaders.h"
#import "DYYYConstants.h"
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#include <string.h>

%group DYYYSearchRanks
%hook AWESearchMiddleNATabViewComponent
+ (id)filerTabDataModel:(id)viewModel {
    AWESearchMiddleNATabDataModel *model = %orig(viewModel);
    if (![model respondsToSelector:@selector(tabs)]) return model;
    NSArray *tabs = model.tabs;
    if (![tabs isKindOfClass:NSArray.class]) return model;
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:tabs.count];
    for (AWESearchMiddleNASingleTabModel *tab in tabs) {
        if ([tab respondsToSelector:@selector(tabId)] && [tab respondsToSelector:@selector(tabName)] &&
            [tab.tabId isKindOfClass:NSString.class] && tab.tabId.length)
            [entries addObject:@{ @"id": tab.tabId, @"title": tab.tabName ?: tab.tabId }];
    }
    [DYYYSearchClean recordRanks:entries];
    NSArray *visible = [DYYYSearchClean visibleRanks:tabs identifier:^NSString *(id value) {
        return [value respondsToSelector:@selector(tabId)] ? [(AWESearchMiddleNASingleTabModel *)value tabId] : nil;
    }];
    if (visible == tabs) return model;
    if (!visible.count) return nil;
    if (![model respondsToSelector:@selector(copyWithZone:)]) return model;
    AWESearchMiddleNATabDataModel *copy = [model copy];
    if (copy == model) return model;
    copy.tabs = visible;
    BOOL hasLanding = NO;
    for (AWESearchMiddleNASingleTabModel *tab in visible)
        if ([tab.tabId isEqualToString:copy.landingTab]) hasLanding = YES;
    if (!hasLanding) copy.landingTab = ((AWESearchMiddleNASingleTabModel *)visible.firstObject).tabId;
    return copy;
}
%end
%end

%group DYYYSearchLynxProps
%hook BDXLynxKitParams
- (NSDictionary *)globalProps {
    NSDictionary *props = %orig;
    return [DYYYSearchClean cleanGlobalProps:props url:self.originURL];
}
%end
%end

%group DYYYSearchVoice
%hook AWEVoiceSearchManager
- (BOOL)shouldHiddenWithPagePositionType:(long long)position {
    if (DYYYGetBool(DYYY_SEARCH_REMOVE_VOICE_KEY) &&
        ([self isVoiceSearchMiddlePagePosition:position] || [self isVoiceSearchSugPagePosition:position])) return YES;
    return %orig(position);
}
%end
%end

%group DYYYSearchCameraPermission
%hook AWESearchRootStateContext
- (BOOL)allowShowScanButton {
    if ([DYYYSearchClean cameraMode] == 2) return NO;
    return %orig;
}
%end
%end

%group DYYYSearchCameraLegacy
%hook AWESearchViewController
- (UIButton *)scanButton {
    UIButton *button = %orig;
    [DYYYSearchClean applyCamera:button];
    return button;
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYSearchClean applyCamera:[DYYYSearchClean existingCameraForOwner:self]];
}
%end
%end

%group DYYYSearchCameraTopBar
%hook AWESearchTopBarScanElement
- (UIButton *)scanButton {
    UIButton *button = %orig;
    [DYYYSearchClean applyCamera:button];
    return button;
}
- (void)hostViewDidLayoutSubviews {
    %orig;
    [DYYYSearchClean applyCamera:[DYYYSearchClean existingCameraForOwner:self]];
}
%end
%end

%group DYYYSearchFooter
%hook LynxUI
- (void)setAccessibilityLabel:(NSString *)label requestReset:(BOOL)reset {
    %orig(label, reset);
    [DYYYSearchClean updateFooter:self label:label];
}
- (void)propsDidUpdate {
    %orig;
    if ([DYYYSearchClean isFooterTarget:self]) [DYYYSearchClean applyFooter:self];
}
- (BOOL)shouldHitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if ([DYYYSearchClean isFooterTarget:self] && [DYYYSearchClean removeRankFooter]) return NO;
    return %orig(point, event);
}
%end
%end

@implementation DYYYSearchClean (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; }); return;
    }
    // 复用搜索框架延迟加载通知，文章 Hook 仅安装一次。
    [DYYYArticleBackdrop installHooks];
    static BOOL ranksInstalled, propsInstalled, voiceInstalled, permissionInstalled, legacyInstalled, topBarInstalled, footerInstalled;
    Class ranks = NSClassFromString(@"AWESearchMiddleNATabViewComponent");
    if (!ranksInstalled && class_getClassMethod(ranks, @selector(filerTabDataModel:))) {
        %init(DYYYSearchRanks);
        ranksInstalled = YES;
    }
    Class props = NSClassFromString(@"BDXLynxKitParams");
    if (!propsInstalled && class_getInstanceMethod(props, @selector(globalProps)) && class_getInstanceMethod(props, @selector(originURL))) {
        %init(DYYYSearchLynxProps);
        propsInstalled = YES;
    }
    Class voice = NSClassFromString(@"AWEVoiceSearchManager");
    if (!voiceInstalled && class_getInstanceMethod(voice, @selector(shouldHiddenWithPagePositionType:)) &&
        class_getInstanceMethod(voice, @selector(isVoiceSearchMiddlePagePosition:)) && class_getInstanceMethod(voice, @selector(isVoiceSearchSugPagePosition:))) {
        %init(DYYYSearchVoice);
        voiceInstalled = YES;
    }
    Class context = NSClassFromString(@"AWESearchRootStateContext");
    if (!permissionInstalled && class_getInstanceMethod(context, @selector(allowShowScanButton))) {
        %init(DYYYSearchCameraPermission);
        permissionInstalled = YES;
    }
    Class legacy = NSClassFromString(@"AWESearchViewController");
    if (!legacyInstalled && class_getInstanceMethod(legacy, @selector(scanButton)) && class_getInstanceMethod(legacy, @selector(viewDidLayoutSubviews))) {
        %init(DYYYSearchCameraLegacy);
        legacyInstalled = YES;
    }
    Class topBar = NSClassFromString(@"AWESearchTopBarScanElement");
    if (!topBarInstalled && class_getInstanceMethod(topBar, @selector(scanButton)) && class_getInstanceMethod(topBar, @selector(hostViewDidLayoutSubviews))) {
        %init(DYYYSearchCameraTopBar);
        topBarInstalled = YES;
    }
    Class lynx = NSClassFromString(@"LynxUI");
    if (!footerInstalled && class_getInstanceMethod(lynx, @selector(setAccessibilityLabel:requestReset:)) &&
        class_getInstanceMethod(lynx, @selector(propsDidUpdate)) && class_getInstanceMethod(lynx, @selector(shouldHitTest:withEvent:)) &&
        class_getInstanceMethod(lynx, @selector(view)) && class_getInstanceMethod(lynx, @selector(context))) {
        %init(DYYYSearchFooter);
        footerInstalled = YES;
    }
}
@end

// dyld 的 C 回调仅识别框架并调度；业务与 Hook 安装放在 DYYY 类方法内。
static void DYYYSearchImageAdded(const struct mach_header *header, intptr_t slide) {
    Dl_info image = {0};
    if (!dladdr(header, &image) || !image.dli_fname) return;
    const char *slash = strrchr(image.dli_fname, '/');
    const char *name = slash ? slash + 1 : image.dli_fname;
    if (strncmp(name, "AWESearch", 9) && strncmp(name, "Lynx", 4) && strncmp(name, "BDX", 3)) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYSearchClean installHooks]; });
}
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYSearchClean installHooks]; });
    _dyld_register_func_for_add_image(DYYYSearchImageAdded);
}
