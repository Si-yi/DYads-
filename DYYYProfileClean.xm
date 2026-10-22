//
//  DYYYProfileClean.xm
//  个人主页精简：头像加号、昵称下方胶囊、发布引导横幅。移植自 DYKiller 的 DKProfileClean*，
//  只保留「移除」一档并改成开关（开启 = 移除，不显示、不可点击，其余内容按抖音原生排布收拢），只作用于自己的主页。
//
//  · 头像加号：头像扩展 AWEProfileAvatarStoryPublishController 的 canShow 返回 NO，
//    p_shouldAddHollowMasks 也返回 NO，头像上不留加号的镂空；点该处等同点头像。
//  · 昵称下方胶囊：胶囊行组件 AWEProfileHeaderGenericOperationComponent 的 buildVirtualView: 返回 nil
//    （抖音没有胶囊时也是这样返回），昵称区自己收拢。
//  · 发布引导横幅：头部分区列表 sectionViewModelArray 里按分区 VM 类去掉横幅分区，不看文字。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define DYYY_PROFILE_PLUS_KEY @"DYYYHideProfileAvatarPlus"
#define DYYY_PROFILE_CAPSULE_KEY @"DYYYHideProfileCapsule"
#define DYYY_PROFILE_BANNER_KEY @"DYYYHideProfileGuideBanner"

@interface AWEProfileAvatarStoryPublishController : NSObject
- (id)profileContext;
- (BOOL)canShow;
- (BOOL)p_shouldAddHollowMasks;
@end

@interface AWEProfileAvatarSectionControllerV2 : NSObject
- (id)profileContext;
- (void)reloadAvatarExtension;
@end

@interface AWEProfileHeaderGenericOperationComponent : NSObject
- (id)context;
- (void)setNeedsUpdate;
- (id)buildVirtualView:(id)data;
@end

@interface AWEProfileHeaderSectionProviderManager : NSObject
- (id)context;
- (NSArray *)sectionViewModelArray;
@end

@interface AWEProfileHeaderViewModel : NSObject
- (BOOL)isCurrentUser;
- (void)reloadSections;
@end

// 弱表，只在主线程读写。
static NSHashTable *gProfileAvatarSections;
static NSHashTable *gProfileCapsuleComponents;
static NSHashTable *gProfileHeaderViewModels;

static BOOL ProfileSwitchOn(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static BOOL ProfileMine(id context) {
    return [context respondsToSelector:@selector(isCurrentUser)] && [context isCurrentUser];
}

static void ProfileTrack(NSHashTable *__strong *table, id object) {
    if (!object) return;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ ProfileTrack(table, object); });
        return;
    }
    if (!*table) *table = [NSHashTable weakObjectsHashTable];
    [*table addObject:object];
}

#pragma mark - 头像加号

%hook AWEProfileAvatarStoryPublishController

- (BOOL)canShow {
    BOOL canShow = %orig;
    if (!canShow || !ProfileSwitchOn(DYYY_PROFILE_PLUS_KEY)) return canShow;
    return !ProfileMine([self profileContext]);
}

- (BOOL)p_shouldAddHollowMasks {
    BOOL should = %orig;
    if (!should || !ProfileSwitchOn(DYYY_PROFILE_PLUS_KEY)) return should;
    return !ProfileMine([self profileContext]);
}

%end

%hook AWEProfileAvatarSectionControllerV2

- (void)configCell:(id)cell index:(NSInteger)index model:(id)model {
    %orig;
    if (ProfileMine([self profileContext])) ProfileTrack(&gProfileAvatarSections, self);
}

%end

#pragma mark - 昵称下方胶囊

%hook AWEProfileHeaderGenericOperationComponent

- (id)buildVirtualView:(id)data {
    BOOL mine = ProfileMine([self context]);
    if (mine) ProfileTrack(&gProfileCapsuleComponents, self);
    if (mine && ProfileSwitchOn(DYYY_PROFILE_CAPSULE_KEY)) return nil;
    return %orig;
}

%end

#pragma mark - 发布引导横幅

%hook AWEProfileHeaderSectionProviderManager

- (NSArray *)sectionViewModelArray {
    NSArray *sections = %orig;
    if (![sections isKindOfClass:NSArray.class] || !ProfileSwitchOn(DYYY_PROFILE_BANNER_KEY)) return sections;
    if (!ProfileMine([self context])) return sections;

    Class banner = NSClassFromString(@"AWEUserProfileUGCHeaderContributionGuideBannerSectionViewModel");
    if (!banner) return sections;
    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:sections.count];
    for (id section in sections) {
        if (![section isKindOfClass:banner]) [kept addObject:section];
    }
    return kept.count == sections.count ? sections : kept;
}

%end

%hook AWEProfileHeaderViewModel

- (void)reloadSections {
    %orig;
    if (!NSThread.isMainThread || ![self isCurrentUser]) return;
    ProfileTrack(&gProfileHeaderViewModels, self);
}

%end

#pragma mark - 设置改动后立即生效

static void ProfileRefreshAll(void) {
    for (AWEProfileAvatarSectionControllerV2 *section in gProfileAvatarSections.allObjects) {
        if ([section respondsToSelector:@selector(reloadAvatarExtension)]) [section reloadAvatarExtension];
    }
    for (AWEProfileHeaderGenericOperationComponent *component in gProfileCapsuleComponents.allObjects) {
        if ([component respondsToSelector:@selector(setNeedsUpdate)]) [component setNeedsUpdate];
    }
    for (AWEProfileHeaderViewModel *viewModel in gProfileHeaderViewModels.allObjects) {
        if ([viewModel respondsToSelector:@selector(reloadSections)]) [viewModel reloadSections];
    }
}

%ctor {
    static NSString *lastSignature = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(__unused NSNotification *note) {
        NSString *signature = [NSString stringWithFormat:@"%d%d%d", ProfileSwitchOn(DYYY_PROFILE_PLUS_KEY),
                               ProfileSwitchOn(DYYY_PROFILE_CAPSULE_KEY), ProfileSwitchOn(DYYY_PROFILE_BANNER_KEY)];
        if ([signature isEqualToString:lastSignature]) return;
        BOOL first = lastSignature == nil;
        lastSignature = signature;
        if (first) return;
        dispatch_async(dispatch_get_main_queue(), ^{ ProfileRefreshAll(); });
    }];
}
