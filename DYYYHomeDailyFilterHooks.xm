#import "AwemeHeaders.h"
#import "DYYYHomeDailyFilter.h"

%hook AWEFeedTableViewController
- (void)setDataController:(id)controller {
    [DYYYHomeDailyFilter bindFeed:self controller:controller];
    %orig(controller);
}
- (void)viewWillAppear:(BOOL)animated {
    // 首次请求可能早于父控制器挂载；显示前补建原生过滤列表，不改原始作品、游标或播放模型。
    id controller = self.dataController;
    if ([DYYYHomeDailyFilter bindFeed:self controller:controller] &&
        [controller respondsToSelector:@selector(calculateFilteredDataSource)]) {
        [controller calculateFilteredDataSource];
    }
    %orig(animated);
}
%end

%hook AWEListDataController
- (void)setFilteredDataSource:(NSMutableArray *)data {
    NSArray *filtered = [DYYYHomeDailyFilter filterArray:data controller:self];
    %orig(filtered);
}
- (void)calculateFilteredDataSource {
    %orig;
    // 兼容原生直接写 ivar 的版本。只在原生计算结束处理一次，绝不在 getter / 每帧布局中删数据。
    NSMutableArray *source = self.filteredDataSource;
    NSArray *filtered = [DYYYHomeDailyFilter filterArray:source controller:self];
    if (filtered != source) self.filteredDataSource = [filtered mutableCopy];
}
%end
