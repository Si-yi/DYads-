#import "AwemeHeaders.h"
#import "DYYYFeedTagGlass.h"
#import "DYYYAvatarRing.h"
#import "DYYYSameStyleVisibility.h"

%group DYYYTagStackGlassHooks
%hook AWEPlayInteractionTagsStackView
- (void)layoutSubviews {
    %orig;
    [DYYYFeedTagGlass decorateStack:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYFeedTagGlass decorateStack:(UIView *)self];
}
%end
%end

%group DYYYGeneralTagGlassHooks
%hook AWEPlayInteractionGeneralTagView
- (void)layoutSubviews {
    %orig;
    [DYYYFeedTagGlass decorateTag:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYFeedTagGlass decorateTag:(UIView *)self];
}
%end
%end

%group DYYYContainerTagGlassHooks
%hook AWEPlayInteractionTagsContainerLabelView
- (void)layoutSubviews {
    %orig;
    [DYYYFeedTagGlass decorateTag:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYFeedTagGlass decorateTag:(UIView *)self];
}
%end
%end

%group DYYYAvatarRingHooks
%hook AFDColorRingView
- (void)layoutSubviews {
    %orig;
    [DYYYAvatarRing applyToRing:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYAvatarRing applyToRing:(UIView *)self];
}
- (void)updateDisplayConfig:(id)config {
    [DYYYAvatarRing beginNativeUpdate:(UIView *)self];
    %orig(config);
    [DYYYAvatarRing endNativeUpdate:(UIView *)self];
}
- (void)startAnimationWithType:(NSInteger)type {
    [DYYYAvatarRing beginNativeUpdate:(UIView *)self];
    %orig(type);
    [DYYYAvatarRing endNativeUpdate:(UIView *)self];
}
- (void)stopAnimation {
    [DYYYAvatarRing beginNativeUpdate:(UIView *)self];
    %orig;
    [DYYYAvatarRing endNativeUpdate:(UIView *)self];
}
- (void)addAttachmentView {
    [DYYYAvatarRing beginNativeUpdate:(UIView *)self];
    %orig;
    [DYYYAvatarRing endNativeUpdate:(UIView *)self];
}
- (void)prepareForReuse {
    [DYYYAvatarRing restoreRing:(UIView *)self];
    %orig;
    [DYYYAvatarRing restoreRing:(UIView *)self];
}
%end
%end

%group DYYYSameStyleVisibilityHooks
%hook AWEPlayInteractionSingleSongMusicStyleView
- (void)layoutSubviews {
    %orig;
    [DYYYSameStyleVisibility applyToView:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYSameStyleVisibility applyToView:(UIView *)self];
}
- (void)setAwemeModel:(id)model {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(model);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
- (void)updatePlayInteractionTitle:(id)title {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(title);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
- (void)updatePlayInteractionDecorationHidden:(BOOL)hidden {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(hidden);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
- (void)updatePlayInteractionLayout:(double)layout {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(layout);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
%end
%end

%group DYYYStyleOneMusicVisibilityHooks
%hook AWEPlayInteractionStyleOneMusicView
- (void)layoutSubviews {
    %orig;
    [DYYYSameStyleVisibility applyToView:(UIView *)self];
}
- (void)didMoveToWindow {
    %orig;
    [DYYYSameStyleVisibility applyToView:(UIView *)self];
}
- (void)setAwemeModel:(id)model {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(model);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
- (void)updatePlayInteractionTitle:(id)title {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(title);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
- (void)updatePlayInteractionDecorationHidden:(BOOL)hidden {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(hidden);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
- (void)updatePlayInteractionLayout:(double)layout {
    [DYYYSameStyleVisibility beginNativeUpdate:(UIView *)self];
    %orig(layout);
    [DYYYSameStyleVisibility endNativeUpdate:(UIView *)self];
}
%end
%end

@implementation DYYYFeedTagGlass (DecorationHooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; }); return;
    }
    static BOOL stackInstalled, generalInstalled, containerInstalled, ringInstalled, musicInstalled, styleOneMusicInstalled;
    // 均位于 AwemeCore，按实际存在的类分别安装，不依赖未出现的标签种类。
    if (!stackInstalled && NSClassFromString(@"AWEPlayInteractionTagsStackView")) {
        %init(DYYYTagStackGlassHooks);
        stackInstalled = YES;
    }
    if (!generalInstalled && NSClassFromString(@"AWEPlayInteractionGeneralTagView")) {
        %init(DYYYGeneralTagGlassHooks);
        generalInstalled = YES;
    }
    if (!containerInstalled && NSClassFromString(@"AWEPlayInteractionTagsContainerLabelView")) {
        %init(DYYYContainerTagGlassHooks);
        containerInstalled = YES;
    }
    if (!ringInstalled && NSClassFromString(@"AFDColorRingView")) {
        %init(DYYYAvatarRingHooks);
        ringInstalled = YES;
    }
    if (!musicInstalled && NSClassFromString(@"AWEPlayInteractionSingleSongMusicStyleView")) {
        %init(DYYYSameStyleVisibilityHooks);
        musicInstalled = YES;
    }
    if (!styleOneMusicInstalled && NSClassFromString(@"AWEPlayInteractionStyleOneMusicView")) {
        %init(DYYYStyleOneMusicVisibilityHooks);
        styleOneMusicInstalled = YES;
    }
}
@end

%ctor {
    [DYYYFeedTagGlass installHooks];
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYFeedTagGlass installHooks]; });
}
