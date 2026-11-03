#import "AwemeHeaders.h"
#import "DYYYFeedCardLayout.h"
#import "DYYYChatVideoLayout.h"
#import <objc/runtime.h>
#import <string.h>

%hook AWEFeedTableView
- (void)setFrame:(CGRect)frame {
    [DYYYFeedCardLayout rememberFrame:frame table:self];
    %orig(frame);
}
%end

%group DYYYPOICardFit
%hook AWEFeedPOIDynamicCardCellViewController
- (void)viewWillLayoutSubviews {
    [DYYYFeedCardLayout layoutController:self afterLayout:NO];
    %orig;
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYFeedCardLayout layoutController:self afterLayout:YES];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [DYYYFeedCardLayout restoreController:self];
}
%end
%end

%group DYYYChatVideoBackdropLayout
%hook AWEPlayVideoViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYChatVideoLayout syncPlayerBackdrop:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [DYYYChatVideoLayout removePlayerBackdrop:self];
}
%end
%end
%group DYYYChatVideoBackdropUpdate
%hook AWEPlayVideoViewController
- (void)updatePlayerBackgroundViewIfNeededWhenLandscape:(BOOL)landscape fromHomepageHot:(BOOL)home {
    %orig(landscape, home);
    [DYYYChatVideoLayout syncPlayerBackdrop:self];
}
%end
%end
%group DYYYChatVideoBackdropSet
%hook AWEPlayVideoViewController
- (void)setPlayerBackgroundView:(UIView *)view {
    %orig(view);
    [DYYYChatVideoLayout syncPlayerBackdrop:self];
}
%end
%end

%ctor {
    %init;
    Class poi = NSClassFromString(@"AWEFeedPOIDynamicCardCellViewController");
    if ([poi isSubclassOfClass:UIViewController.class]) { %init(DYYYPOICardFit); }
    Class player = NSClassFromString(@"AWEPlayVideoViewController");
    if ([player isSubclassOfClass:UIViewController.class]) {
        %init(DYYYChatVideoBackdropLayout);
        Method method = class_getInstanceMethod(player, @selector(updatePlayerBackgroundViewIfNeededWhenLandscape:fromHomepageHot:));
        NSMethodSignature *signature = method ? [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)] : nil;
        if (signature.numberOfArguments == 4 && strcmp(signature.methodReturnType, "v") == 0 &&
            strchr("Bc", [signature getArgumentTypeAtIndex:2][0]) && strchr("Bc", [signature getArgumentTypeAtIndex:3][0])) { %init(DYYYChatVideoBackdropUpdate); }
        method = class_getInstanceMethod(player, @selector(setPlayerBackgroundView:));
        signature = method ? [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)] : nil;
        if (signature.numberOfArguments == 3 && strcmp(signature.methodReturnType, "v") == 0 && [signature getArgumentTypeAtIndex:2][0] == '@') { %init(DYYYChatVideoBackdropSet); }
    }
}
