#import "AwemeHeaders.h"
#import "DYYYFeedTagGlass.h"
#import "DYYYAvatarRing.h"

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

%ctor {
    // 均位于 AwemeCore，按实际存在的类分别安装，不依赖未出现的标签种类。
    if (NSClassFromString(@"AWEPlayInteractionTagsStackView")) {
        %init(DYYYTagStackGlassHooks);
    }
    if (NSClassFromString(@"AWEPlayInteractionGeneralTagView")) {
        %init(DYYYGeneralTagGlassHooks);
    }
    if (NSClassFromString(@"AWEPlayInteractionTagsContainerLabelView")) {
        %init(DYYYContainerTagGlassHooks);
    }
    if (NSClassFromString(@"AFDColorRingView")) {
        %init(DYYYAvatarRingHooks);
    }
}
