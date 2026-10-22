#import "DYYYAutoMessage.h"

// 推荐页出现时触发一次启动检查；内部会按每日标记去重。
%hook AWENormalModeTabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [DYYYAutoMessage runDailyMessageCheckIfNeeded];
}

%end
