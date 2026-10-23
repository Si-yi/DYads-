#import "AwemeHeaders.h"
#import "DYYYPanelBlur.h"
#import <objc/runtime.h>

%group DYYYSharePanelBlurHooks
%hook AWESharePanelContainerViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    [DYYYPanelBlur synchronizeController:(UIViewController *)self];
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYPanelBlur synchronizeController:(UIViewController *)self];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    UIViewController *controller = (UIViewController *)self;
    if (!controller.viewIfLoaded.window) [DYYYPanelBlur restoreController:controller];
}
%end
%end

%group DYYYShareContentBlurHooks
%hook AWESharePanelViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYPanelBlur synchronizeController:(UIViewController *)self];
}
%end
%end

%group DYYYShareFunctionBlurHooks
%hook AWESharePanelFunctionCell
- (void)layoutSubviews {
    %orig;
    [DYYYPanelBlur synchronizeView:(UIView *)self];
}
- (void)prepareForReuse {
    [DYYYPanelBlur restoreView:(UIView *)self];
    %orig;
}
%end
%end

@implementation DYYYPanelBlur (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL containerInstalled, contentInstalled, functionInstalled;
    Class container = NSClassFromString(@"AWESharePanelContainerViewController");
    if (!containerInstalled && container && [container isSubclassOfClass:UIViewController.class]) {
        %init(DYYYSharePanelBlurHooks);
        containerInstalled = YES;
    }
    Class content = NSClassFromString(@"AWESharePanelViewController");
    if (!contentInstalled && content && [content isSubclassOfClass:UIViewController.class]) {
        %init(DYYYShareContentBlurHooks);
        contentInstalled = YES;
    }
    Class function = NSClassFromString(@"AWESharePanelFunctionCell");
    if (!functionInstalled && function && [function isSubclassOfClass:UICollectionViewCell.class]) {
        %init(DYYYShareFunctionBlurHooks);
        functionInstalled = YES;
    }
}
@end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYPanelBlur installHooks]; });
}
