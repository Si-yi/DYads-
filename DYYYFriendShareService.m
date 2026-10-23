#import "DYYYFriendShareService.h"
#import "DYYYIMService.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"

@interface DYYYFriendShareService ()
@property (nonatomic, weak) AWEFeedTableViewController *home;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *queued;
@property (nonatomic, strong) NSMutableSet<NSString *> *inFlight;
@property (nonatomic, copy) NSArray *originalFeed;
@property (nonatomic, strong) NSMutableOrderedSet *batchOrder;
@property (nonatomic, strong) NSMutableDictionary *batchModels;
@property (nonatomic) BOOL arranging;
@property (nonatomic) BOOL openingPending;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) NSUInteger attempts;
@property (nonatomic) BOOL scanScheduled;
@property (nonatomic, copy) NSString *displayedID;
@property (nonatomic) NSTimeInterval displayedSince;
@property (nonatomic) BOOL backgrounded;
@property (nonatomic) BOOL userDragging;
@end

@implementation DYYYFriendShareService
+ (instancetype)shared {
    static DYYYFriendShareService *service;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        service = [self new];
        service.queued = [NSMutableOrderedSet orderedSet];
        service.inFlight = [NSMutableSet set];
        service.openingPending = YES;
        service.backgrounded = YES;
    });
    return service;
}
+ (BOOL)enabled { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYFriendShareFeedEnabled"]; }
+ (BOOL)automatic { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYFriendShareAutoRefreshEnabled"]; }
+ (NSString *)itemID:(id)model {
    @try {
        id value = [model valueForKey:@"itemID"];
        return [value isKindOfClass:NSString.class] ? value : ([value isKindOfClass:NSNumber.class] ? [value stringValue] : nil);
    } @catch (__unused NSException *exception) { return nil; }
}
+ (NSString *)key:(NSString *)name {
    NSString *account = [DYYYIMService accountID];
    return account.length ? [NSString stringWithFormat:@"%@.%@", name, account] : nil;
}
+ (NSMutableSet *)storedIDs:(NSString *)name {
    NSString *key = [self key:name];
    return [NSMutableSet setWithArray:key ? ([NSUserDefaults.standardUserDefaults arrayForKey:key] ?: @[]) : @[]];
}
+ (void)saveIDs:(NSSet *)ids name:(NSString *)name {
    NSString *key = [self key:name];
    if (key) [NSUserDefaults.standardUserDefaults setObject:ids.allObjects forKey:key];
}
+ (BOOL)syncAccount {
    NSString *account = [DYYYIMService accountID];
    DYYYFriendShareService *s = [self shared];
    if (![s.account isEqual:account]) {
        s.account = account;
        [s.queued removeAllObjects];
        [s.inFlight removeAllObjects];
        s.originalFeed = nil;
        s.batchOrder = nil;
        s.batchModels = nil;
        s.displayedID = nil;
    }
    return account.length > 0;
}
+ (BOOL)homeVisible {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    UIViewController *home = [self shared].home;
    if (!home.isViewLoaded || !home.view.window) return NO;
    UIViewController *top = topView();
    for (UIViewController *parent = home; parent; parent = parent.parentViewController) if (parent == top) return YES;
    return NO;
}
+ (void)applicationOpened {
    DYYYFriendShareService *s = [self shared];
    s.generation++;
    s.attempts = 0;
    s.scanScheduled = NO;
    s.openingPending = YES;
    s.displayedID = nil;
    [self tryOpeningScan];
}
+ (void)applicationEnteredBackground {
    [self shared].backgrounded = YES;
    [self shared].generation++;
    [self shared].displayedID = nil;
}
+ (void)applicationBecameActive {
    if (![self shared].backgrounded) return;
    [self shared].backgrounded = NO;
    [self applicationOpened];
}
+ (void)bindHomeFeed:(UIViewController *)feed {
    AWEFeedTableViewController *home = (id)feed;
    if (![home respondsToSelector:@selector(dataController)] || ![home.dataController isKindOfClass:NSClassFromString(@"AWEHotListDataController")]) return;
    [self shared].home = home;
    if ([self shared].openingPending && [self automatic]) [self cleanOpeningCache];
    [self tryOpeningScan];
    [self insertQueued];
    [self homeDidScroll:feed];
}
+ (void)tryOpeningScan {
    DYYYFriendShareService *s = [self shared];
    if (![self enabled] || ![self automatic] || !s.openingPending || ![self homeVisible] || s.attempts >= 8 || s.scanScheduled) return;
    if (NSClassFromString(@"FriendShareFeedService")) return;
    s.attempts++;
    s.scanScheduled = YES;
    NSUInteger generation = s.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
        if (generation != s.generation) return;
        s.scanScheduled = NO;
        if (generation != s.generation || !s.openingPending || ![self enabled] || ![self automatic] || ![self homeVisible]) return;
        NSArray *users = [NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[];
        if (!users.count) { s.openingPending = NO; return; }
        NSString *failure = nil;
        NSArray *rows = [DYYYIMService unreadSharesForUsers:users error:&failure];
        if (failure) {
            // 初始化未完成才重试；格式或参与者错误不能在启动阶段连续重读数据库。
            if ([failure hasPrefix:@"本地消息服务尚未就绪"]) [self tryOpeningScan];
            else s.openingPending = NO;
            return;
        }
        s.openingPending = NO;
        [self queueRows:rows toast:NO];
    });
}
+ (void)scanWithToast:(BOOL)showToast {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self scanWithToast:showToast]; }); return; }
    if (![self enabled]) { if (showToast) [DYYYUtils showToast:@"请先开启好友分享进推荐"]; return; }
    if (NSClassFromString(@"FriendShareFeedService")) { if (showToast) [DYYYUtils showToast:@"请先移除原版自动消息插件，避免两套分享服务同时运行"]; return; }
    NSString *failure = nil;
    NSArray *users = [NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[];
    if (!users.count) { if (showToast) [DYYYUtils showToast:@"请先选择分享来源好友"]; return; }
    NSArray *rows = [DYYYIMService unreadSharesForUsers:users error:&failure];
    if (failure) { if (showToast) [DYYYUtils showToast:failure]; return; }
    [self queueRows:rows toast:showToast];
}
+ (void)queueRows:(NSArray *)rows toast:(BOOL)toast {
    if (![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
    NSSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    if (!s.inFlight.count) [s.queued removeAllObjects];
    for (NSDictionary *row in rows) if (![watched containsObject:row[@"itemID"]]) [s.queued addObject:row[@"itemID"]];
    NSUInteger count = s.queued.count;
    [self insertQueued];
    if (toast) [DYYYUtils showToast:count ? [NSString stringWithFormat:[self homeVisible] ? @"已过滤刷过作品，提交加载 %lu 个分享视频" : @"已过滤刷过作品，返回首页后显示 %lu 个分享视频", (unsigned long)count] : @"没有新的未刷分享视频"];
}
+ (void)insertQueued {
    DYYYFriendShareService *s = [self shared];
    if (![self enabled] || ![self syncAccount] || ![self homeVisible] || !s.queued.count) return;
    AWEFeedTableViewController *home = s.home;
    if (![home respondsToSelector:@selector(insertVideosToFeedWithAwemeIDs:extraInfo:)]) return;
    id data = [(AWEListDataController *)home.dataController dataSource];
    if (![data isKindOfClass:NSArray.class] || ![data count]) return;
    if (!s.inFlight.count) {
        s.originalFeed = [data copy];
        s.batchOrder = [NSMutableOrderedSet orderedSet];
        s.batchModels = [NSMutableDictionary dictionary];
    }
    NSMutableArray *ids = [NSMutableArray array];
    for (NSString *itemID in s.queued) if (![s.inFlight containsObject:itemID]) [ids addObject:itemID];
    if (!ids.count) return;
    [s.batchOrder addObjectsFromArray:ids];
    [s.inFlight addObjectsFromArray:ids];
    NSMutableSet *known = [self storedIDs:@"DYYYFriendShareInsertedItemIDs"];
    [known addObjectsFromArray:ids];
    [self saveIDs:known name:@"DYYYFriendShareInsertedItemIDs"];
    NSArray *ordered = [self arrangeData:data controller:home.dataController];
    if (ordered != data) {
        [(AWEHotListDataController *)home.dataController updateAwemeList:ordered];
        id table = nil;
        @try { table = [home valueForKey:@"tableView"]; } @catch (__unused NSException *exception) {}
        if ([table isKindOfClass:UITableView.class]) [table reloadData];
    }
    NSMutableArray *missing = [NSMutableArray array];
    for (NSString *itemID in ids) if ([s.inFlight containsObject:itemID]) [missing addObject:itemID];
    if (!missing.count) return;
    @try { [home insertVideosToFeedWithAwemeIDs:missing extraInfo:@{}]; }
    @catch (__unused NSException *exception) {
        [s.inFlight minusSet:[NSSet setWithArray:ids]];
        [DYYYUtils showToast:@"抖音加载分享作品失败，已保留待加载列表"];
    }
}
+ (NSArray *)arrangeData:(NSArray *)data controller:(id)controller {
    DYYYFriendShareService *s = [self shared];
    if (![NSThread isMainThread] || s.arranging || ![self enabled] || ![data isKindOfClass:NSArray.class] || controller != s.home.dataController || ![self syncAccount]) return data;
    NSSet *alreadyWatched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    for (NSString *itemID in [s.inFlight copy]) if ([alreadyWatched containsObject:itemID]) {
        [s.inFlight removeObject:itemID];
        [s.queued removeObject:itemID];
    }
    if (s.openingPending || s.inFlight.count) data = [self removeWatchedShares:data];
    if (!s.inFlight.count) {
        if (s.queued.count && data.count) dispatch_async(dispatch_get_main_queue(), ^{ [self insertQueued]; });
        return data;
    }
    NSMutableDictionary *loaded = [NSMutableDictionary dictionary];
    for (id model in data) { NSString *itemID = [self itemID:model]; if (itemID && [s.inFlight containsObject:itemID]) loaded[itemID] = model; }
    if (!loaded.count) return data;
    s.arranging = YES;
    [s.batchModels addEntriesFromDictionary:loaded];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *used = [NSMutableSet set];
    NSHashTable *seenObjects = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
    NSSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    NSSet *known = [self storedIDs:@"DYYYFriendShareInsertedItemIDs"];
    for (NSString *itemID in s.batchOrder) if (s.batchModels[itemID] && ![watched containsObject:itemID]) { [result addObject:s.batchModels[itemID]]; [used addObject:itemID]; }
    for (NSArray *source in @[s.originalFeed ?: @[], data]) for (id model in source) {
        NSString *itemID = [self itemID:model];
        if (!itemID && [seenObjects containsObject:model]) continue;
        if (itemID && ([used containsObject:itemID] || ([known containsObject:itemID] && [watched containsObject:itemID]))) continue;
        [result addObject:model];
        [seenObjects addObject:model];
        if (itemID) [used addObject:itemID];
    }
    for (NSString *itemID in loaded) { [s.inFlight removeObject:itemID]; [s.queued removeObject:itemID]; }
    if (!s.inFlight.count) {
        s.originalFeed = nil;
        NSString *firstShare = [self itemID:result.firstObject];
        NSUInteger generation = s.generation;
        if (firstShare.length && s.batchModels[firstShare]) dispatch_async(dispatch_get_main_queue(), ^{
            [self showFirstShare:firstShare generation:generation attempt:0];
        });
    }
    s.arranging = NO;
    return result;
}
+ (NSArray *)removeWatchedShares:(NSArray *)data {
    NSSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    NSSet *known = [self storedIDs:@"DYYYFriendShareInsertedItemIDs"];
    NSMutableArray *kept = [NSMutableArray array];
    for (id model in data) {
        NSString *itemID = [self itemID:model];
        if (itemID && [known containsObject:itemID] && [watched containsObject:itemID]) continue;
        [kept addObject:model];
    }
    return kept.count == data.count ? data : kept;
}
+ (void)cleanOpeningCache {
    if (![self enabled] || ![self syncAccount]) return;
    AWEFeedTableViewController *home = [self shared].home;
    id controller = home.dataController;
    if (![controller isKindOfClass:NSClassFromString(@"AWEHotListDataController")]) return;
    NSArray *data = [(AWEListDataController *)controller dataSource];
    if (![data isKindOfClass:NSArray.class]) return;
    NSArray *kept = [self removeWatchedShares:data];
    if (kept == data) return;
    [(AWEHotListDataController *)controller updateAwemeList:kept];
    if (home.isViewLoaded) {
        id table = nil;
        @try { table = [home valueForKey:@"tableView"]; } @catch (__unused NSException *exception) {}
        if ([table isKindOfClass:UITableView.class]) [table reloadData];
    }
    if (!kept.count && [self homeVisible] && [home respondsToSelector:@selector(awe_refreshForceRequestWithoutAnimation)]) {
        [home awe_refreshForceRequestWithoutAnimation];
    }
}
+ (void)showFirstShare:(NSString *)itemID generation:(NSUInteger)generation attempt:(NSUInteger)attempt {
    DYYYFriendShareService *s = [self shared];
    if (generation != s.generation || ![self enabled] || ![self homeVisible] || s.userDragging) return;
    AWEListDataController *controller = s.home.dataController;
    NSArray *visible = controller.filteredDataSource ?: controller.dataSource;
    if (![visible isKindOfClass:NSArray.class] || ![[self itemID:visible.firstObject] isEqual:itemID]) return;
    id table = nil;
    @try { table = [s.home valueForKey:@"tableView"]; } @catch (__unused NSException *exception) {}
    if ([table isKindOfClass:UITableView.class] && [table numberOfSections] > 0 && [table numberOfRowsInSection:0] > 0) {
        [s.home scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        [self homeDidScroll:s.home];
    } else if (attempt < 5) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 5), dispatch_get_main_queue(), ^{
            [self showFirstShare:itemID generation:generation attempt:attempt + 1];
        });
    }
}
+ (void)markWatched:(NSString *)itemID {
    if (!itemID.length || ![self enabled] || ![self syncAccount]) return;
    NSMutableSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    if ([watched containsObject:itemID]) return;
    [watched addObject:itemID];
    [self saveIDs:watched name:@"DYYYFriendShareWatchedItemIDs"];
    [[self shared].queued removeObject:itemID];
}
+ (void)homeDidScroll:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || ![self enabled] || ![self homeVisible] || ![self syncAccount]) return;
    NSString *current = [self itemID:s.home.currentAweme];
    if (!current.length) return;
    if ([current isEqual:s.displayedID]) { s.userDragging = NO; return; }
    if (s.userDragging && s.displayedID.length) [self markWatched:s.displayedID];
    s.userDragging = NO;
    s.displayedID = current;
    s.displayedSince = NSDate.date.timeIntervalSince1970;
}
+ (void)homeWillDrag:(UIViewController *)feed {
    if ([self shared].home != feed || ![self homeVisible]) return;
    [self homeDidScroll:feed];
    [self shared].userDragging = YES;
}
+ (void)homeWillLoop:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home == feed && [self homeVisible]) [self markWatched:[self itemID:s.home.currentAweme]];
}
+ (void)clearWatched {
    NSString *key = [self key:@"DYYYFriendShareWatchedItemIDs"];
    if (key) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}
@end
