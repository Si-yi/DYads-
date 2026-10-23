#import "AwemeHeaders.h"
#import "DYYYArticleBackdrop.h"
#import <objc/runtime.h>

%group DYYYArticleBackdropHooks
%hook DYYYFeedArticleViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYArticleBackdrop synchronizeController:(UIViewController *)self refresh:NO];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [DYYYArticleBackdrop synchronizeController:(UIViewController *)self refresh:YES];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [DYYYArticleBackdrop removeFromController:(UIViewController *)self];
}
- (void)lynxEngineDidMount:(id)engine {
    %orig(engine);
    [DYYYArticleBackdrop synchronizeController:(UIViewController *)self refresh:YES];
}
- (void)updateModel:(id)model {
    [DYYYArticleBackdrop removeFromController:(UIViewController *)self];
    %orig(model);
    [DYYYArticleBackdrop synchronizeController:(UIViewController *)self refresh:YES];
}
- (void)prepareForReuse {
    [DYYYArticleBackdrop removeFromController:(UIViewController *)self];
    %orig;
}
%end
%end

@implementation DYYYArticleBackdrop (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; });
        return;
    }
    static BOOL installed = NO;
    Class article = NSClassFromString(@"AWESearchFeedArticleViewController");
    if (installed || !article || ![article isSubclassOfClass:UIViewController.class]) return;
    if (!class_getInstanceMethod(article, @selector(lynxEngineDidMount:)) ||
        !class_getInstanceMethod(article, @selector(updateModel:)) ||
        !class_getInstanceMethod(article, @selector(prepareForReuse))) return;
    %init(DYYYArticleBackdropHooks, DYYYFeedArticleViewController = article);
    installed = YES;
}
@end
