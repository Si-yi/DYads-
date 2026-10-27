#import "AwemeHeaders.h"
#import "DYYYChatInputGlass.h"

%group DYYYChatInputGlassHooks
%hook IESIMInputViewController
- (void)viewDidLayoutSubviews {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig;
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [DYYYChatInputGlass synchronizeController:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    [DYYYChatInputGlass restoreController:self];
    %orig(animated);
    [DYYYChatInputGlass restoreController:self];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig(previous);
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
- (void)refreshbackground:(BOOL)refresh {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig(refresh);
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
- (void)setHasBackgroundImage:(BOOL)hasImage {
    [DYYYChatInputGlass beginUpdate:self];
    @try {
        %orig(hasImage);
    } @finally {
        [DYYYChatInputGlass endUpdate:self];
    }
}
%end
%end

@implementation DYYYChatInputGlass (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL installed;
    if (!installed && NSClassFromString(@"IESIMInputViewController")) {
        %init(DYYYChatInputGlassHooks);
        installed = YES;
    }
}
@end

%ctor {
    [DYYYChatInputGlass installHooks];
}
