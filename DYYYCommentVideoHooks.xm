#import "DYYYCommentVideoLayout.h"
#import "AwemeHeaders.h"

%group DYYYCommentVideoPlayerHooks
%hook AWEDPlayerViewController_Merge
- (void)videoDidShrink {
    if ([DYYYCommentVideoLayout freezeController:self]) return;
    %orig;
}
- (void)videoDidMagnify {
    %orig;
    [DYYYCommentVideoLayout didMagnifyController:self];
}
- (void)willDisplay {
    %orig;
    [DYYYCommentVideoLayout synchronizeController:self];
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYCommentVideoLayout synchronizeController:self];
}
%end
%end

%group DYYYCommentVideoRichHooks
%hook RichContentContainerViewController
- (void)updateShrinkState:(BOOL)shrink insets:(UIEdgeInsets)insets animated:(BOOL)animated {
    if (shrink && [DYYYCommentVideoLayout freezeController:self]) return;
    %orig;
}
- (void)updateShrinkState:(BOOL)shrink insets:(UIEdgeInsets)insets animated:(BOOL)animated animationDuration:(double)duration {
    if (shrink && [DYYYCommentVideoLayout freezeController:self]) return;
    %orig;
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYCommentVideoLayout synchronizeController:self];
}
%end
%end

@implementation DYYYCommentVideoLayout (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL videoInstalled, richInstalled;
    Class video = NSClassFromString(@"AWEDPlayerViewController_Merge");
    if (!videoInstalled && [video instancesRespondToSelector:@selector(videoDidShrink)] &&
        [video instancesRespondToSelector:@selector(videoDidMagnify)] && [video instancesRespondToSelector:@selector(willDisplay)]) {
        %init(DYYYCommentVideoPlayerHooks);
        videoInstalled = YES;
    }
    Class rich = NSClassFromString(@"RichContentContainerViewController");
    if (!richInstalled && [rich instancesRespondToSelector:@selector(updateShrinkState:insets:animated:)] &&
        [rich instancesRespondToSelector:@selector(updateShrinkState:insets:animated:animationDuration:)]) {
        %init(DYYYCommentVideoRichHooks);
        richInstalled = YES;
    }
}
@end

%ctor {
    [DYYYCommentVideoLayout installHooks];
}
