#import "DYYYFriendShareService.h"
#import "DYYYIMService.h"
#import "DYYYFriendShareHistory.h"
#import "DYYYFriendShareDelivery.h"
#import "DYYYFriendShareBadgeView.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#include <string.h>

@interface DYYYFriendShareService ()
@property (nonatomic, weak) AWEFeedTableViewController *home;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, strong) DYYYFriendShareHistory *history;
@property (nonatomic) NSUInteger restoredGeneration;
@property (nonatomic, strong) NSMutableOrderedSet *queued;
@property (nonatomic, strong) NSMutableOrderedSet *active;
@property (nonatomic, strong) NSMutableDictionary *models;
@property (nonatomic, strong) NSMutableDictionary *sources;
@property (nonatomic, strong) NSMutableSet *inFlight;
@property (nonatomic, strong) NSMutableSet *failed;
@property (nonatomic, strong) NSMutableDictionary *state;
@property (nonatomic, strong) id pool;
@property (nonatomic) BOOL arranging;
@property (nonatomic) BOOL openingPending;
@property (nonatomic) BOOL scanScheduled;
@property (nonatomic) BOOL scanInProgress;
@property (nonatomic) BOOL backgrounded;
@property (nonatomic) BOOL userDragging;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) NSUInteger attempts;
@property (nonatomic, copy) NSString *displayedID;
@property (nonatomic, copy) NSString *pendingPlaybackID;
@property (nonatomic) NSUInteger playbackTicket;
@property (nonatomic) NSUInteger dragTicket;
@property (nonatomic) NSUInteger playbackSyncTicket;
@property (nonatomic) BOOL selectedOpeningShare;
@property (nonatomic) BOOL waitingToInsert;
@property (nonatomic) BOOL feedNeedsReload;
@property (nonatomic, copy) NSString *selectionAfterReload;
@property (nonatomic) BOOL startAfterReload;
@property (nonatomic) BOOL resumeAfterPageReturn;
@property (nonatomic) NSUInteger cellRepairTicket;
@property (nonatomic, strong) NSMutableSet *retriedModels;
@property (nonatomic, strong) NSMutableSet<NSString *> *rejectedLegacyIDs;
@property (nonatomic) BOOL legacyCleanupPending;
@end

@implementation DYYYFriendShareService
+ (instancetype)shared {
    static DYYYFriendShareService *service;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        service = [self new];
        service.queued = [NSMutableOrderedSet orderedSet];
        service.active = [NSMutableOrderedSet orderedSet];
        service.models = [NSMutableDictionary dictionary];
        service.sources = [NSMutableDictionary dictionary];
        service.inFlight = [NSMutableSet set];
        service.failed = [NSMutableSet set];
        service.retriedModels = [NSMutableSet set];
        service.rejectedLegacyIDs = [NSMutableSet set];
        service.state = [NSMutableDictionary dictionary];
        service.openingPending = YES;
        service.backgrounded = YES;
    });
    return service;
}
+ (NSDictionary *)diagnostics {
    DYYYFriendShareService *s = [self shared];
    NSMutableDictionary *state = [s.state mutableCopy];
    state[@"queuedCount"] = @(s.queued.count);
    state[@"loadingCount"] = @(s.inFlight.count);
    state[@"readyCount"] = @(s.models.count);
    state[@"insertedCount"] = @(s.active.count);
    state[@"sourceCount"] = @(s.sources.count);
    state[@"persistedPendingCount"] = @(s.history.pendingRows.count);
    state[@"watchedCount"] = @(s.history.watchedItemIDs.count);
    state[@"watchHistory"] = [s.history diagnostics] ?: @{};
    state[@"pendingPlayback"] = @(s.pendingPlaybackID.length > 0);
    state[@"waitingToInsert"] = @(s.waitingToInsert);
    state[@"feedNeedsReload"] = @(s.feedNeedsReload);
    state[@"homeVisible"] = @([self homeVisible]);
    NSString *current = [self itemID:s.home.currentAweme];
    NSString *visible = [self visibleHomeItemID];
    state[@"currentItemID"] = current ?: @"";
    state[@"visibleItemID"] = visible ?: @"";
    state[@"visibleItemWatched"] = @([s.history.watchedItemIDs containsObject:visible ?: @""]);
    NSMutableArray *pendingIDs = [NSMutableArray array];
    for (NSDictionary *row in s.history.pendingRows) [pendingIDs addObject:row[@"itemID"]];
    state[@"pendingItemIDs"] = pendingIDs.count > 64 ? [pendingIDs subarrayWithRange:NSMakeRange(0, 64)] : pendingIDs;
    state[@"visibleItemPending"] = @([pendingIDs containsObject:visible ?: @""]);
    id table = s.home.isViewLoaded ? [self value:s.home key:@"tableView"] : nil;
    if ([table isKindOfClass:UITableView.class]) state[@"tableRowCount"] = @([table numberOfSections] > 0 ? [table numberOfRowsInSection:0] : 0);
    if ([s.home respondsToSelector:@selector(isPlaying)]) state[@"nativePlaying"] = @([s.home isPlaying]);
    if ([s.home respondsToSelector:@selector(currentIndex)]) state[@"currentIndex"] = @(s.home.currentIndex);
    if ([s.home respondsToSelector:@selector(currentPlayIndex)]) state[@"currentPlayIndex"] = @(s.home.currentPlayIndex);
    return state;
}
// 以表格中心实际显示的 Cell 为准；currentAweme/下标可能仍是重载前的缓存。
+ (AWEFeedCellViewController *)visibleHomeCell {
    DYYYFriendShareService *s = [self shared];
    if (!NSThread.isMainThread || !s.home.isViewLoaded) return nil;
    id table = [self value:s.home key:@"tableView"];
    if (![table isKindOfClass:UITableView.class]) return nil;
    UITableView *list = table;
    CGPoint center = CGPointMake(CGRectGetMidX(list.bounds), CGRectGetMidY(list.bounds));
    Class cellClass = NSClassFromString(@"AWEFeedViewCell");
    for (UITableViewCell *row in list.visibleCells) {
        if (!cellClass || ![row isKindOfClass:cellClass] || row.hidden || row.alpha <= 0.01 || row.window != list.window || !CGRectContainsPoint([row convertRect:row.bounds toView:list], center)) continue;
        AWEFeedCellViewController *cell = [(AWEFeedViewCell *)row viewController];
        for (UIViewController *parent = cell; parent; parent = parent.parentViewController)
            if (parent == s.home) return cell;
    }
    return nil;
}
+ (NSString *)visibleHomeItemID {
    return [self itemID:[self visibleHomeCell].model];
}
+ (BOOL)enabled { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYFriendShareFeedEnabled"]; }
+ (BOOL)automatic { return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYFriendShareAutoRefreshEnabled"]; }
+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *e) { return nil; }
}
+ (NSString *)itemID:(id)model {
    id value = [self value:model key:@"itemID"];
    return [value isKindOfClass:NSString.class] ? value : ([value isKindOfClass:NSNumber.class] ? [value stringValue] : nil);
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
    DYYYFriendShareService *s = [self shared];
    NSString *account = [DYYYIMService accountID];
    if (![s.account isEqual:account]) {
        s.account = account;
        s.generation++; s.scanInProgress = NO; s.pendingPlaybackID = nil; s.playbackTicket++; s.selectedOpeningShare = NO; s.waitingToInsert = NO;
        s.feedNeedsReload = NO; s.selectionAfterReload = nil; s.resumeAfterPageReturn = NO;
        [s.queued removeAllObjects]; [s.active removeAllObjects]; [s.models removeAllObjects];
        [s.inFlight removeAllObjects]; [s.failed removeAllObjects]; [s.retriedModels removeAllObjects];
        [s.rejectedLegacyIDs removeAllObjects]; s.legacyCleanupPending = NO;
        NSString *sourceKey = [self key:@"DYYYFriendShareSources"];
        NSDictionary *storedSources = sourceKey ? [NSUserDefaults.standardUserDefaults dictionaryForKey:sourceKey] : nil;
        s.sources = storedSources ? [storedSources mutableCopy] : [NSMutableDictionary dictionary];
        s.history = [[DYYYFriendShareHistory alloc] initWithDefaults:NSUserDefaults.standardUserDefaults account:account];
        [s.history importLegacySources:s.sources];
        s.restoredGeneration = NSNotFound;
        s.pool = nil; s.displayedID = nil;
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
+ (void)applicationEnteredBackground {
    DYYYFriendShareService *s = [self shared];
    [s.history resetPlayback]; s.userDragging = NO; s.dragTicket++;
    s.backgrounded = YES; s.generation++; s.pendingPlaybackID = nil; s.playbackTicket++; s.selectedOpeningShare = NO; s.waitingToInsert = NO; s.scanScheduled = NO; s.scanInProgress = NO; s.displayedID = nil;
    [s.inFlight removeAllObjects];
}
+ (void)applicationOpened {
    [self applicationBecameActive];
}
+ (void)applicationBecameActive {
    DYYYFriendShareService *s = [self shared];
    if (!s.backgrounded) return;
    s.backgrounded = NO; s.generation++; s.attempts = 0; s.selectedOpeningShare = NO;
    s.openingPending = YES; s.scanScheduled = NO; s.scanInProgress = NO; s.displayedID = nil;
    [s.failed removeAllObjects]; [s.retriedModels removeAllObjects];
    [s.history resetPlayback];
    if ([self automatic]) [self restoreSavedShares];
    [self tryOpeningScan];
}
+ (void)bindHomeFeed:(UIViewController *)feed {
    AWEFeedTableViewController *home = (id)feed;
    if (![home respondsToSelector:@selector(dataController)] || ![home.dataController isKindOfClass:NSClassFromString(@"AWEHotListDataController")]) return;
    BOOL underHomeRoot = NO;
    Class rootClass = NSClassFromString(@"AWEFeedRootViewController");
    for (UIViewController *parent = home.parentViewController; parent; parent = parent.parentViewController)
        if (rootClass && [parent isKindOfClass:rootClass]) { underHomeRoot = YES; break; }
    if (!underHomeRoot) return;
    [self shared].home = home;
    if ([self automatic]) [self restoreSavedShares];
    if ([self shared].openingPending && [self automatic]) [self cleanOpeningCache];
    [self tryOpeningScan]; [self insertQueued]; [self applyPreparedFeed]; [self homeDidScroll:feed];
}
+ (void)restoreSavedShares {
    if (![self enabled] || NSClassFromString(@"FriendShareFeedService") || ![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
    if (s.restoredGeneration == s.generation) return;
    s.restoredGeneration = s.generation;
    [self enqueueSavedRowsIncludingActive:YES];
    s.state[@"restoredPendingCount"] = @(s.queued.count);
    [self insertQueued];
}
+ (void)enqueueSavedRowsIncludingActive:(BOOL)includeActive {
    DYYYFriendShareService *s = [self shared];
    NSSet *selected = [NSSet setWithArray:[NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[]];
    for (NSDictionary *row in s.history.pendingRows) {
        NSString *itemID = row[@"itemID"];
        if (![selected containsObject:row[@"friendID"] ?: @""]) continue;
        NSMutableDictionary *source = [row mutableCopy];
        [source removeObjectForKey:@"itemID"];
        s.sources[itemID] = source;
        if (includeActive || ![s.active containsObject:itemID]) [s.queued addObject:itemID];
    }
}
+ (void)orderActiveShares {
    DYYYFriendShareService *s = [self shared];
    NSMutableOrderedSet *ordered = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *row in s.history.pendingRows)
        if ([s.active containsObject:row[@"itemID"]]) [ordered addObject:row[@"itemID"]];
    // 已播完但仍在屏幕上的当前视频不能立即从列表移走。
    [ordered addObjectsFromArray:s.active.array];
    s.active = ordered;
}
+ (void)tryOpeningScan {
    DYYYFriendShareService *s = [self shared];
    if (![self enabled] || ![self automatic] || !s.openingPending || s.scanScheduled || s.scanInProgress || s.attempts >= 8 || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    if (NSClassFromString(@"FriendShareFeedService")) return;
    // 先同步账户和持久待刷队列；即使本次消息读取失败也能恢复上次未刷分享。
    [self syncAccount];
    [self restoreSavedShares];
    s.attempts++; s.scanScheduled = YES;
    NSUInteger generation = s.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
        if (generation != s.generation) return;
        s.scanScheduled = NO;
        if (![self enabled] || UIApplication.sharedApplication.applicationState != UIApplicationStateActive || !s.openingPending || s.scanInProgress) return;
        NSArray *users = [NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[];
        if (!users.count) { s.openingPending = NO; return; }
        s.scanInProgress = YES;
        [DYYYIMService unreadSharesForUsers:users revalidatingRows:[self legacyRowsForRevalidation]
                                      completion:^(NSArray *rows, NSArray *rejectedRows, NSString *warning) {
            if (generation != s.generation) return;
            s.scanInProgress = NO;
            if (![users isEqualToArray:[NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[]]) return;
            if (![self enabled] || ![self automatic]) return;
            s.state[@"lastScanWarning"] = warning ?: @"";
            if (rows.count || rejectedRows.count) [self queueRows:rows rejectingRows:rejectedRows toast:NO];
            if ([warning hasPrefix:@"本地消息服务尚未就绪"]) [self tryOpeningScan];
            else s.openingPending = NO;
        }];
    });
}
+ (void)scanWithToast:(BOOL)showToast {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self scanWithToast:showToast]; }); return; }
    if (![self enabled]) { if (showToast) [DYYYUtils showToast:@"请先开启好友分享进推荐"]; return; }
    if (NSClassFromString(@"FriendShareFeedService")) { if (showToast) [DYYYUtils showToast:@"请先移除原版自动消息插件，避免两套分享服务同时运行"]; return; }
    if (![self syncAccount]) { if (showToast) [DYYYUtils showToast:@"当前登录账户尚未就绪"]; return; }
    DYYYFriendShareService *s = [self shared];
    if (s.scanInProgress) { if (showToast) [DYYYUtils showToast:@"正在扫描好友分享，请稍候"]; return; }
    NSArray *users = [NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[];
    if (!users.count) { if (showToast) [DYYYUtils showToast:@"请先选择分享来源好友"]; return; }
    [s.failed removeAllObjects]; [s.retriedModels removeAllObjects];
    s.selectedOpeningShare = NO;
    s.restoredGeneration = NSNotFound;
    [self restoreSavedShares];
    s.scanInProgress = YES;
    NSUInteger generation = s.generation;
    if (showToast) [DYYYUtils showToast:@"正在读取好友近期分享"];
    [DYYYIMService unreadSharesForUsers:users revalidatingRows:[self legacyRowsForRevalidation]
                                      completion:^(NSArray *rows, NSArray *rejectedRows, NSString *warning) {
        if (generation != s.generation) return;
        s.scanInProgress = NO;
        s.openingPending = NO;
        if (![users isEqualToArray:[NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[]]) return;
        if (![self enabled]) return;
        s.state[@"lastScanWarning"] = warning ?: @"";
        if (rows.count || rejectedRows.count || !warning) [self queueRows:rows rejectingRows:rejectedRows toast:showToast && !warning];
        if (showToast && warning) [DYYYUtils showToast:warning];
    }];
}
+ (NSArray *)legacyRowsForRevalidation {
    DYYYFriendShareService *s = [self shared];
    NSMutableDictionary *byID = [NSMutableDictionary dictionary];
    for (NSString *itemID in s.sources) {
        NSDictionary *source = s.sources[itemID];
        if (![source isKindOfClass:NSDictionary.class] || [source[@"shareValidationVersion"] unsignedIntegerValue] >= 1) continue;
        NSMutableDictionary *row = [source mutableCopy]; row[@"itemID"] = itemID;
        byID[itemID] = row;
    }
    for (NSDictionary *row in s.history.pendingRows)
        if ([row[@"shareValidationVersion"] unsignedIntegerValue] < 1) byID[row[@"itemID"]] = row;
    return byID.allValues;
}
+ (void)queueRows:(NSArray *)rows rejectingRows:(NSArray *)rejectedRows toast:(BOOL)toast {
    if (![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
    NSSet *removedPending = [s.history discardUnverifiedRows:rejectedRows];
    NSMutableSet *invalid = [removedPending mutableCopy];
    for (NSDictionary *row in rejectedRows) {
        NSString *itemID = row[@"itemID"];
        NSDictionary *source = s.sources[itemID];
        if ([source[@"friendID"] isEqual:row[@"friendID"]] && [source[@"shareValidationVersion"] unsignedIntegerValue] < 1) {
            [s.sources removeObjectForKey:itemID]; [invalid addObject:itemID];
        }
    }
    // 同作品若仍由其他好友的有效来源/待刷记录持有，不能随旧错误来源一起撤下。
    for (NSDictionary *pending in s.history.pendingRows) [invalid removeObject:pending[@"itemID"]];
    [invalid minusSet:[NSSet setWithArray:s.sources.allKeys]];
    if (invalid.count) {
        [s.rejectedLegacyIDs unionSet:invalid]; s.legacyCleanupPending = YES;
        for (NSString *itemID in invalid) {
            [s.queued removeObject:itemID]; [s.active removeObject:itemID]; [s.models removeObjectForKey:itemID];
        }
        if ([invalid containsObject:s.pendingPlaybackID ?: @""]) { s.pendingPlaybackID = nil; s.playbackTicket++; }
        s.state[@"rejectedLegacyCount"] = @([s.state[@"rejectedLegacyCount"] unsignedIntegerValue] + invalid.count);
        // 当前作品不强制跳走；立即撤下错误来源标签，列表清理留到非拖动时执行。
        NSMutableArray *controllers = [NSMutableArray array];
        if ([self visibleHomeCell]) [controllers addObject:[self visibleHomeCell]];
        NSUInteger visited = 0;
        while (controllers.count && visited++ < 40) {
            UIViewController *controller = controllers.lastObject; [controllers removeLastObject];
            if ([controller isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")])
                [DYYYFriendShareBadgeView updateForController:controller];
            [controllers addObjectsFromArray:controller.childViewControllers];
        }
    }
    NSSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    NSString *friendsKey = [@"DYYYMutualFriendsCache." stringByAppendingString:s.account];
    NSArray *friends = [NSUserDefaults.standardUserDefaults arrayForKey:friendsKey] ?: @[];
    NSMutableDictionary *friendsByID = [NSMutableDictionary dictionary];
    for (NSDictionary *friend in friends) {
        if ([friend isKindOfClass:NSDictionary.class] && [friend[@"userID"] isKindOfClass:NSString.class]) friendsByID[friend[@"userID"]] = friend;
    }
    NSMutableArray *saved = [NSMutableArray array];
    for (NSDictionary *row in rows) {
        NSString *itemID = row[@"itemID"], *friendID = row[@"friendID"];
        if (![itemID isKindOfClass:NSString.class] || !itemID.length) continue;
        if ([row[@"shareValidationVersion"] unsignedIntegerValue] >= 1) {
            // 其他好友真正分享同一作品仍有效，不能被此前的旧误判屏蔽。
            [s.rejectedLegacyIDs removeObject:itemID];
            if ([s.sources[itemID][@"friendID"] isEqual:friendID]) {
                NSMutableDictionary *source = [s.sources[itemID] mutableCopy];
                source[@"shareValidationVersion"] = row[@"shareValidationVersion"];
                if (row[@"shareMessageID"]) source[@"shareMessageID"] = row[@"shareMessageID"];
                s.sources[itemID] = source;
            }
        }
        if ([watched containsObject:itemID]) continue;
        NSMutableDictionary *pending = [row mutableCopy];
        if ([friendID isKindOfClass:NSString.class] && friendID.length) {
            NSDictionary *friend = friendsByID[friendID];
            pending[@"name"] = [friend[@"name"] isKindOfClass:NSString.class] ? friend[@"name"] : @"好友";
            pending[@"avatar"] = [friend[@"avatar"] isKindOfClass:NSString.class] ? friend[@"avatar"] : @"";
            pending[@"collectedAt"] = @(NSDate.date.timeIntervalSince1970);
        }
        [saved addObject:pending];
    }
    // 先落盘再加载/插入。模型失败、尚未显示、聊天已读或进程退出都不会消费队列。
    [s.history mergeRows:saved];
    [self enqueueSavedRowsIncludingActive:NO];
    // 待刷来源全部保留；只裁剪已完成的旧来源，不能因超过 256 条丢未刷分享。
    NSMutableSet *pendingIDs = [NSMutableSet set];
    for (NSDictionary *row in s.history.pendingRows) [pendingIDs addObject:row[@"itemID"]];
    NSMutableDictionary *completed = [s.sources mutableCopy];
    [completed removeObjectsForKeys:pendingIDs.allObjects];
    if (completed.count > 256) {
        NSArray *oldest = [completed keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [@([a[@"collectedAt"] doubleValue]) compare:@([b[@"collectedAt"] doubleValue])];
        }];
        [s.sources removeObjectsForKeys:[oldest subarrayWithRange:NSMakeRange(0, completed.count - 256)]];
    }
    NSString *sourceKey = [self key:@"DYYYFriendShareSources"];
    if (sourceKey) [NSUserDefaults.standardUserDefaults setObject:s.sources forKey:sourceKey];
    s.state[@"scanVideoCount"] = @([NSSet setWithArray:[rows valueForKey:@"itemID"]].count);
    [self pruneRejectedLegacyFeed];
    [self insertQueued];
    if (toast) [DYYYUtils showToast:s.queued.count ? @"已找到未刷分享，正在准备首页列表，可继续使用其他页面" : @"没有新的未刷分享视频"];
}

// 标签仅属于这份首页数据，不能因相同视频 ID 出现在聊天或博主页就跟过去。
+ (NSDictionary *)shareSourceForItemID:(NSString *)itemID controller:(UIViewController *)controller {
    DYYYFriendShareService *s = [self shared];
    if (![self enabled] || !itemID.length || NSClassFromString(@"FriendShareFeedService") || ![s.account isEqual:[DYYYIMService accountID]]) return nil;
    BOOL inHome = NO;
    for (UIViewController *parent = controller; parent; parent = parent.parentViewController) {
        if (parent == s.home) { inHome = YES; break; }
    }
    if (!inHome) return nil;
    id source = s.sources[itemID];
    return [source isKindOfClass:NSDictionary.class] ? source : nil;
}

#pragma mark - 使用抖音自己的视频缓存池获取真实模型

+ (id)videoPool {
    DYYYFriendShareService *s = [self shared];
    if (s.pool) return s.pool;
    Class cls = NSClassFromString(@"AWEIMFeedVideoCachePool");
    if (!cls) { s.state[@"stage"] = @"video_pool_missing"; return nil; }
    @try {
        if ([cls respondsToSelector:@selector(sharedInstance)]) s.pool = [(id)cls sharedInstance];
        else {
            Class service = NSClassFromString(@"HTSService");
            Class center = NSClassFromString(@"HTSServiceCenter");
            if (service && [cls isSubclassOfClass:service] && [center respondsToSelector:@selector(defaultCenter)])
                s.pool = [[(id)center defaultCenter] getService:cls];
        }
    } @catch (__unused NSException *e) {}
    return s.pool;
}
// 参考原版调用现场：缓存池 sharedInstance，requestScene 为字符串 @"dm"。
// 先检查运行时签名，避免把对象参数当整数调用。
+ (id)cachedModel:(NSString *)itemID {
    id pool = [self videoPool];
    for (NSString *name in @[@"awemeModelForItemId:", @"awemeWithItemId:"]) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature = [pool methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 3 || signature.methodReturnType[0] != '@' || [signature getArgumentTypeAtIndex:2][0] != '@') continue;
        @try {
            NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
            call.target = pool; call.selector = selector;
            [call setArgument:&itemID atIndex:2]; [call invoke];
            __unsafe_unretained id result = nil; [call getReturnValue:&result];
            if ([result isKindOfClass:NSClassFromString(@"AWEAwemeModel")] && [[self itemID:result] isEqual:itemID]) return result;
        } @catch (__unused NSException *e) {}
    }
    return nil;
}
+ (void)collectModels:(id)result allowed:(NSSet *)allowed depth:(NSUInteger)depth {
    if (!result || depth > 4) return;
    if ([result isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
        NSString *itemID = [self itemID:result];
        if (itemID.length && [allowed containsObject:itemID]) [self shared].models[itemID] = result;
    } else if ([result isKindOfClass:NSArray.class]) {
        for (id child in result) [self collectModels:child allowed:allowed depth:depth + 1];
    } else if ([result isKindOfClass:NSDictionary.class]) {
        for (id child in [result allValues]) [self collectModels:child allowed:allowed depth:depth + 1];
    }
}
+ (BOOL)requestModels:(NSArray *)ids {
    id pool = [self videoPool];
    DYYYFriendShareService *s = [self shared];
    NSString *scene = @"dm";
    for (NSString *name in @[@"requestAwemeModelsForItemIds:requestScene:results:", @"tryRequestAwemeItemsWithIds:requestScene:"]) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature = [pool methodSignatureForSelector:selector];
        BOOL callback = [name hasSuffix:@"results:"];
        if (!signature || signature.numberOfArguments != (callback ? 5 : 4) || [signature getArgumentTypeAtIndex:2][0] != '@' || [signature getArgumentTypeAtIndex:3][0] != '@') continue;
        if (callback && strcmp([signature getArgumentTypeAtIndex:4], "@?") != 0) continue;
        @try {
            NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
            call.target = pool; call.selector = selector;
            [call setArgument:&ids atIndex:2]; [call setArgument:&scene atIndex:3];
            NSUInteger generation = s.generation;
            NSString *account = [s.account copy];
            NSSet *allowed = [NSSet setWithArray:ids];
            void (^resultHandler)(id) = ^(id result) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation != s.generation || ![account isEqual:[DYYYIMService accountID]] || ![self enabled]) return;
                    [self collectModels:result allowed:allowed depth:0];
                    s.state[@"resultClass"] = result ? NSStringFromClass([result class]) : @"nil";
                    // 超时后才到达的有效模型仍应入队，不能永久受 failed 标记阻挡。
                    for (NSString *itemID in allowed) if (s.models[itemID]) {
                        [s.failed removeObject:itemID]; [s.inFlight removeObject:itemID];
                    }
                    [self insertQueued];
                });
            };
            if (callback) [call setArgument:&resultHandler atIndex:4];
            [call retainArguments]; [call invoke];
            s.state[@"stage"] = @"loading_models";
            s.state[@"requestSelector"] = name;
            return YES;
        } @catch (__unused NSException *e) { s.state[@"stage"] = @"model_request_exception"; }
    }
    return NO;
}
+ (void)pollModels:(NSArray *)ids account:(NSString *)account generation:(NSUInteger)generation attempt:(NSUInteger)attempt {
    DYYYFriendShareService *s = [self shared];
    if (generation != s.generation || ![account isEqual:[DYYYIMService accountID]] || ![self enabled]) return;
    NSMutableArray *missing = [NSMutableArray array];
    BOOL ready = NO;
    for (NSString *itemID in ids) {
        id model = s.models[itemID] ?: [self cachedModel:itemID];
        if (model) {
            s.models[itemID] = model; [s.inFlight removeObject:itemID]; [s.failed removeObject:itemID];
            if ([s.queued containsObject:itemID]) ready = YES;
        } else [missing addObject:itemID];
    }
    if (ready) [self insertQueued];
    if (!missing.count) { s.state[@"modelStage"] = @"models_ready"; return; }
    if (attempt >= 30) {
        NSMutableArray *retry = [NSMutableArray array];
        for (NSString *itemID in missing) {
            [s.inFlight removeObject:itemID]; [s.failed addObject:itemID];
            if (![s.retriedModels containsObject:itemID]) { [s.retriedModels addObject:itemID]; [retry addObject:itemID]; }
        }
        s.state[@"modelStage"] = @"model_load_timeout";
        s.state[@"unloadedItemIDs"] = missing;
        // 加载失败仅保留诊断和待刷队列，后台静默补试，不打断观看。
        [self insertQueued];
        if (retry.count) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (generation != s.generation || ![account isEqual:[DYYYIMService accountID]] || ![self enabled]) return;
            [s.failed minusSet:[NSSet setWithArray:retry]];
            [self insertQueued];
        });
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), ^{
        [self pollModels:missing account:account generation:generation attempt:attempt + 1];
    });
}
+ (void)insertQueued {
    DYYYFriendShareService *s = [self shared];
    if (![self enabled] || NSClassFromString(@"FriendShareFeedService") || ![self syncAccount] ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive || s.arranging || !s.queued.count) return;
    NSMutableArray *ready = [NSMutableArray array], *missing = [NSMutableArray array];
    NSMutableSet *watched = [s.history.watchedItemIDs mutableCopy];
    [watched unionSet:s.rejectedLegacyIDs];
    for (NSString *itemID in [s.queued copy]) {
        if ([watched containsObject:itemID]) { [s.queued removeObject:itemID]; continue; }
        if ([s.failed containsObject:itemID]) continue;
        id model = s.models[itemID] ?: [self cachedModel:itemID];
        if (model) { s.models[itemID] = model; [ready addObject:itemID]; }
        else if (![s.inFlight containsObject:itemID] && missing.count < 20) [missing addObject:itemID];
    }
    // 模型获取独立于首页：尚未创建首页、在消息/搜索页、首页暂停都不影响请求。
    if (missing.count && !s.inFlight.count) {
        [s.inFlight addObjectsFromArray:missing];
        if ([self requestModels:missing]) {
            NSString *account = [s.account copy];
            NSUInteger generation = s.generation;
            dispatch_async(dispatch_get_main_queue(), ^{ [self pollModels:missing account:account generation:generation attempt:0]; });
        }
        else {
            [s.inFlight minusSet:[NSSet setWithArray:missing]];
            [s.failed addObjectsFromArray:missing]; s.state[@"stage"] = @"model_request_unavailable";
        }
    }
    if (!ready.count) return;
    AWEFeedTableViewController *home = s.home;
    id controller = home.dataController;
    if (!home || ![controller respondsToSelector:@selector(setDataSource:)] || ![controller respondsToSelector:@selector(calculateFilteredDataSource)]) { s.state[@"stage"] = @"prepared_waiting_feed"; return; }
    NSArray *data = [(AWEListDataController *)controller dataSource];
    if (![data isKindOfClass:NSArray.class]) { s.state[@"stage"] = @"prepared_waiting_feed_data"; return; }
    BOOL visible = [self homeVisible];
    id table = visible ? [self value:home key:@"tableView"] : nil;
    if (visible && [table isKindOfClass:UIScrollView.class] && ([table isTracking] || [table isDragging] || [table isDecelerating])) return;
    BOOL wasPlaying = home.isViewLoaded && [home respondsToSelector:@selector(isPlaying)] && [home isPlaying];
    if (visible && s.selectedOpeningShare && !wasPlaying && [self itemID:home.currentAweme].length) {
        s.waitingToInsert = YES; return;
    }
    s.waitingToInsert = NO;
    NSString *previous = [self visibleHomeItemID] ?: s.displayedID ?: (home.isViewLoaded ? [self itemID:home.currentAweme] : nil);
    // active 是本轮缓存，不是未刷清单。新一轮启动不保留上次已刷的当前 Cell。
    NSString *preservedCurrent = s.selectedOpeningShare ? previous : nil;
    for (NSString *itemID in [s.active copy])
        if ([watched containsObject:itemID] && ![itemID isEqual:preservedCurrent]) [s.active removeObject:itemID];
    NSMutableOrderedSet *desired = [s.active mutableCopy];
    [desired addObjectsFromArray:ready];
    NSMutableArray *orderedIDs = [NSMutableArray array];
    for (NSDictionary *row in s.history.pendingRows) if ([desired containsObject:row[@"itemID"]]) [orderedIDs addObject:row[@"itemID"]];
    for (NSString *itemID in desired) if (![orderedIDs containsObject:itemID]) [orderedIDs addObject:itemID];
    NSArray *merged = [DYYYFriendShareDelivery feedWithOriginal:data sharedModels:s.models orderedIDs:orderedIDs
        watchedIDs:watched currentItemID:preservedCurrent anchorItemID:previous insertAfterAnchor:s.selectedOpeningShare];
    s.state[@"insertionAnchorItemID"] = previous ?: @"";
    s.state[@"insertionAfterAnchor"] = @(s.selectedOpeningShare);
    NSUInteger anchorIndex = [data indexOfObjectPassingTest:^BOOL(id model, NSUInteger index, BOOL *stop) {
        return [[self itemID:model] isEqual:previous];
    }];
    s.state[@"insertionAnchorIndex"] = anchorIndex == NSNotFound ? @(-1) : @(anchorIndex);
    s.arranging = YES;
    BOOL submitted = NO;
    @try {
        // 不触发逐条插入或隐藏页 Cell 布局，原生过滤仍按当前开关执行。
        submitted = [DYYYFriendShareDelivery replaceFeed:merged controller:controller];
    } @finally { s.arranging = NO; }
    if (!submitted) { s.state[@"stage"] = @"batch_replace_unavailable"; return; }
    NSArray *actual = [(AWEListDataController *)controller dataSource];
    NSArray *playable = [(AWEListDataController *)controller filteredDataSource];
    NSMutableSet *confirmed = [NSMutableSet set], *playableIDs = [NSMutableSet set];
    for (id model in actual) { NSString *itemID = [self itemID:model]; if (itemID.length) [confirmed addObject:itemID]; }
    for (id model in playable) { NSString *itemID = [self itemID:model]; if (itemID.length) [playableIDs addObject:itemID]; }
    [confirmed intersectSet:playableIDs];
    s.state[@"submittedCount"] = @(merged.count);
    s.state[@"dataSourceCount"] = @(actual.count);
    s.state[@"playableCount"] = @(playable.count);
    NSMutableSet *confirmedShares = [NSMutableSet setWithArray:ready];
    [confirmedShares intersectSet:confirmed];
    s.state[@"confirmedShareCount"] = @(confirmedShares.count);
    NSMutableSet *known = [self storedIDs:@"DYYYFriendShareInsertedItemIDs"];
    BOOL inserted = NO;
    for (NSString *itemID in ready) if ([confirmed containsObject:itemID]) {
        [s.active addObject:itemID]; [s.queued removeObject:itemID]; [known addObject:itemID]; inserted = YES;
    }
    if (!inserted) { s.state[@"stage"] = @"batch_update_not_confirmed"; return; }
    [self orderActiveShares];
    [self saveIDs:known name:@"DYYYFriendShareInsertedItemIDs"];
    s.state[@"stage"] = visible ? @"batch_inserted" : @"batch_inserted_offscreen";
    s.feedNeedsReload = YES;
    s.selectionAfterReload = s.selectedOpeningShare ? previous : s.active.firstObject;
    s.startAfterReload = !s.selectedOpeningShare || (visible ? wasPlaying : s.resumeAfterPageReturn);
    [self applyPreparedFeed];
}

+ (void)applyPreparedFeed {
    DYYYFriendShareService *s = [self shared];
    if (!s.feedNeedsReload || ![self homeVisible] || s.userDragging || ![self enabled]) return;
    NSString *target = s.selectionAfterReload;
    if (!target.length) return;
    s.selectedOpeningShare = YES;
    [self selectShare:target startPlayback:s.startAfterReload generation:s.generation];
}

#pragma mark - 首页列表保持与已刷记录

+ (NSArray *)arrangeData:(NSArray *)data controller:(id)controller {
    DYYYFriendShareService *s = [self shared];
    if (!NSThread.isMainThread || s.arranging || ![self enabled] || ![data isKindOfClass:NSArray.class] || controller != s.home.dataController || ![self syncAccount]) return data;
    NSMutableSet *watched = [s.history.watchedItemIDs mutableCopy];
    [watched unionSet:s.rejectedLegacyIDs];
    NSString *current = [self visibleHomeItemID] ?: s.displayedID;
    NSString *preservedCurrent = (s.selectedOpeningShare || [s.rejectedLegacyIDs containsObject:current ?: @""]) ? current : nil;
    // 原生 load more/刷新也必须保持浏览位置；不能在每次写入时把 active 全部搬回首行。
    for (NSString *itemID in [s.active copy]) {
        if ([watched containsObject:itemID] && ![itemID isEqual:preservedCurrent]) {
            [s.active removeObject:itemID]; [s.models removeObjectForKey:itemID];
        }
    }
    NSArray *result = [DYYYFriendShareDelivery feedWithOriginal:data sharedModels:s.models orderedIDs:s.active.array
        watchedIDs:watched currentItemID:preservedCurrent anchorItemID:current insertAfterAnchor:YES];
    NSMutableSet *pending = [NSMutableSet setWithArray:s.queued.array];
    [pending minusSet:s.failed];
    if (pending.count && !s.inFlight.count) dispatch_async(dispatch_get_main_queue(), ^{ [self insertQueued]; });
    BOOL same = result.count == data.count;
    if (same) for (NSUInteger i = 0; i < result.count; i++) if (result[i] != data[i]) { same = NO; break; }
    return same ? data : result;
}
// 仅撤下已证实误入队的未来条目，不消费当前作品，不改变用户暂停意图。
+ (void)pruneRejectedLegacyFeed {
    DYYYFriendShareService *s = [self shared];
    if (!s.legacyCleanupPending || s.arranging || s.userDragging || ![self enabled]) return;
    id table = s.home.isViewLoaded ? [self value:s.home key:@"tableView"] : nil;
    if ([table isKindOfClass:UIScrollView.class] && ([table isTracking] || [table isDragging] || [table isDecelerating])) return;
    id controller = s.home.dataController;
    NSArray *data = [controller respondsToSelector:@selector(dataSource)] ? [controller dataSource] : nil;
    if (![data isKindOfClass:NSArray.class]) return;
    NSString *current = [self visibleHomeItemID] ?: s.displayedID ?: [self itemID:s.home.currentAweme];
    NSArray *kept = [DYYYFriendShareDelivery feedWithOriginal:data sharedModels:@{} orderedIDs:@[]
        watchedIDs:s.rejectedLegacyIDs currentItemID:current];
    s.legacyCleanupPending = [s.rejectedLegacyIDs containsObject:current ?: @""];
    if (kept.count == data.count) return;
    BOOL wasPlaying = [self homeVisible] ? ([s.home respondsToSelector:@selector(isPlaying)] && [s.home isPlaying]) : s.resumeAfterPageReturn;
    BOOL submitted = NO;
    s.arranging = YES;
    @try { submitted = [DYYYFriendShareDelivery replaceFeed:kept controller:controller]; }
    @finally { s.arranging = NO; }
    if (!submitted) { s.legacyCleanupPending = YES; return; }
    s.feedNeedsReload = YES;
    BOOL containsCurrent = current.length && [kept indexOfObjectPassingTest:^BOOL(id model, NSUInteger index, BOOL *stop) {
        return [[self itemID:model] isEqual:current];
    }] != NSNotFound;
    s.selectionAfterReload = containsCurrent ? current : [self itemID:kept.firstObject];
    s.startAfterReload = wasPlaying;
    [self applyPreparedFeed];
}
+ (void)cleanOpeningCache {
    if (![self enabled] || ![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
    NSArray *data = [(AWEListDataController *)s.home.dataController dataSource];
    if (![data isKindOfClass:NSArray.class]) return;
    NSArray *kept = [self arrangeData:data controller:s.home.dataController];
    if (kept != data) {
        BOOL submitted = NO;
        s.arranging = YES;
        @try { submitted = [DYYYFriendShareDelivery replaceFeed:kept controller:s.home.dataController]; }
        @finally { s.arranging = NO; }
        if (!submitted) return;
        s.feedNeedsReload = YES;
        NSString *current = [self visibleHomeItemID] ?: s.displayedID;
        BOOL containsCurrent = current.length && [kept indexOfObjectPassingTest:^BOOL(id model, NSUInteger index, BOOL *stop) {
            return [[self itemID:model] isEqual:current];
        }] != NSNotFound;
        s.selectionAfterReload = containsCurrent ? current : [self itemID:kept.firstObject];
        s.startAfterReload = !s.selectedOpeningShare || s.resumeAfterPageReturn;
        [self applyPreparedFeed];
        if (!kept.count && [self homeVisible] && [s.home respondsToSelector:@selector(awe_refreshForceRequestWithoutAnimation)]) [s.home awe_refreshForceRequestWithoutAnimation];
    }
}
// 使用原生索引重载入口同步 Cell、currentAweme 和播放器。仅滚动到已在屏幕上的
// 第 0 行不会触发滚动结束流程，直接 UITableView.reloadData 也不会更新播放状态。
+ (void)selectShare:(NSString *)itemID startPlayback:(BOOL)start generation:(NSUInteger)generation {
    DYYYFriendShareService *s = [self shared];
    if (!itemID.length || generation != s.generation || ![self enabled] || ![self homeVisible] || s.userDragging) return;
    AWEFeedTableViewController *home = s.home;
    // 原生首页按 filteredDataSource 展示，不能用未过滤列表的下标选错 Cell。
    NSArray *data = [(AWEListDataController *)home.dataController filteredDataSource];
    if (![data isKindOfClass:NSArray.class]) return;
    NSUInteger index = [data indexOfObjectPassingTest:^BOOL(id model, NSUInteger idx, BOOL *stop) {
        return [[self itemID:model] isEqual:itemID];
    }];
    if (index == NSNotFound) return;
    if (![home respondsToSelector:@selector(reloadWithCurrentIndex:)] || ![home respondsToSelector:@selector(reloadTableViewData)]) {
        s.state[@"playbackStage"] = @"native_selection_unavailable";
        return;
    }
    NSUInteger ticket = ++s.playbackTicket;
    s.feedNeedsReload = NO;
    s.pendingPlaybackID = start ? itemID : nil;
    s.state[@"playbackStage"] = @"selecting_native_cell";
    s.state[@"selectionIndex"] = @(index);
    BOOL wasArranging = s.arranging;
    s.arranging = YES; // 重载期间旧可见 Cell 还未切换，不能让原生回调按旧锚点再次重排。
    @try {
        s.state[@"selectionItemID"] = itemID;
        if (![DYYYFriendShareDelivery reloadFeed:home atIndex:index]) {
            s.feedNeedsReload = YES;
            s.pendingPlaybackID = nil;
            s.state[@"playbackStage"] = @"native_table_reload_unavailable";
            return;
        }
        id table = [self value:home key:@"tableView"];
        if ([table isKindOfClass:UITableView.class]) {
            [table layoutIfNeeded];
            if ([table numberOfSections] > 0 && index < (NSUInteger)[table numberOfRowsInSection:0])
                [home scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
    } @catch (__unused NSException *exception) {
        s.pendingPlaybackID = nil;
        s.state[@"playbackStage"] = @"native_selection_exception";
        return;
    } @finally { s.arranging = wasArranging; }
    if (!start) { s.state[@"playbackStage"] = @"kept_user_pause"; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self activateSelectedShare:itemID generation:generation ticket:ticket attempt:0];
    });
}

+ (void)activateSelectedShare:(NSString *)itemID generation:(NSUInteger)generation ticket:(NSUInteger)ticket attempt:(NSUInteger)attempt {
    DYYYFriendShareService *s = [self shared];
    if (generation != s.generation || ticket != s.playbackTicket || ![itemID isEqual:s.pendingPlaybackID] ||
        ![self enabled] || ![self homeVisible] || s.userDragging) return;
    AWEFeedTableViewController *home = s.home;
    id table = [self value:home key:@"tableView"];
    if (![table isKindOfClass:UITableView.class] || [table isTracking] || [table isDragging] || [table isDecelerating]) return;
    BOOL active = ![home respondsToSelector:@selector(currentVCIsActive)] || [home currentVCIsActive];
    if (!active) s.state[@"playbackStage"] = @"waiting_active_feed";
    else {
        @try {
            if (s.playbackSyncTicket != ticket && [home respondsToSelector:@selector(playVideoOnScrollDidEnd)]) {
                // 即使 currentAweme 已是新模型，currentCell/播放器也可能仍属于旧模型。
                // 无动画且零位移的滚动不会触发 UIKit 结束回调，因此每次选中只补一次原生入口。
                s.playbackSyncTicket = ticket;
                [home playVideoOnScrollDidEnd];
            }
            if (generation != s.generation || ticket != s.playbackTicket) return;
            if ([[self itemID:home.currentAweme] isEqual:itemID]) {
                if (![[self visibleHomeItemID] isEqual:itemID]) {
                    s.state[@"playbackStage"] = @"waiting_visible_target";
                    if (attempt < 5) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 5), dispatch_get_main_queue(), ^{
                        [self activateSelectedShare:itemID generation:generation ticket:ticket attempt:attempt + 1];
                    });
                    return;
                }
                s.displayedID = itemID;
                if ([home respondsToSelector:@selector(playIfActive)]) {
                    s.state[@"playbackStage"] = @"native_play_requested";
                    [home playIfActive];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
                        [self verifySelectedShare:itemID generation:generation ticket:ticket];
                    });
                    return; // 后续由真实播放进度确认，不用定时器反复强制播放。
                }
                s.state[@"playbackStage"] = @"native_play_unavailable";
                return;
            }
            s.state[@"playbackStage"] = @"waiting_selected_model";
        } @catch (__unused NSException *exception) {
            s.pendingPlaybackID = nil;
            s.state[@"playbackStage"] = @"native_play_exception";
            return;
        }
    }
    if (attempt < 5) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 5), dispatch_get_main_queue(), ^{
        [self activateSelectedShare:itemID generation:generation ticket:ticket attempt:attempt + 1];
    });
}

+ (void)verifySelectedShare:(NSString *)itemID generation:(NSUInteger)generation ticket:(NSUInteger)ticket {
    DYYYFriendShareService *s = [self shared];
    if (generation != s.generation || ticket != s.playbackTicket || ![itemID isEqual:s.pendingPlaybackID] ||
        ![self enabled] || ![self homeVisible] || s.userDragging || s.cellRepairTicket == ticket) return;
    AWEFeedTableViewController *home = s.home;
    if (![[self visibleHomeItemID] isEqual:itemID]) return;
    if ([home respondsToSelector:@selector(isPlaying)] && [home isPlaying]) { s.state[@"playbackStage"] = @"waiting_first_progress"; return; }
    id cell = [self visibleHomeCell];
    s.state[@"currentCellClass"] = cell ? NSStringFromClass([cell class]) : @"nil";
    s.state[@"currentCellItemID"] = [self itemID:[self value:cell key:@"model"]] ?: @"";
    if (![cell isKindOfClass:NSClassFromString(@"AWEFeedCellViewController")]) { s.state[@"playbackStage"] = @"waiting_feed_cell"; return; }
    id player = [self value:home key:@"currentVideoController"];
    NSMutableDictionary *playerState = [NSMutableDictionary dictionary];
    if (player) playerState[@"class"] = NSStringFromClass([player class]);
    for (NSString *key in @[ @"holdStopping", @"isPrepared", @"hasPreparedToPlay", @"isPausedByUserClick", @"pausedByDisappear", @"isPlayStarted" ]) {
        if (![player respondsToSelector:NSSelectorFromString(key)]) continue;
        id value = [self value:player key:key];
        if ([value isKindOfClass:NSNumber.class]) playerState[key] = value;
    }
    s.state[@"playerBeforeCellPrepare"] = playerState;
    s.cellRepairTicket = ticket;
    BOOL active = ![home respondsToSelector:@selector(currentVCIsActive)] || [home currentVCIsActive];
    if ([DYYYFriendShareDelivery prepareAndPlayCell:cell itemID:itemID allowed:active]) {
        if ([itemID isEqual:s.pendingPlaybackID]) s.state[@"playbackStage"] = @"cell_play_requested";
    } else s.state[@"playbackStage"] = @"cell_prepare_rejected";
}

+ (void)homePlaybackTouched:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || ![self enabled]) return;
    s.playbackTicket++; s.pendingPlaybackID = nil; s.selectedOpeningShare = YES;
    s.state[@"playbackStage"] = @"user_controlled";
}
+ (void)homePlaybackAdvanced:(UIViewController *)feed time:(NSTimeInterval)time {
    if (![self enabled] || [self shared].home != feed) return;
    NSString *itemID = [self itemID:[self value:feed key:@"currentAweme"]];
    NSUInteger generation = [self shared].generation;
    if (!NSThread.isMainThread) {
        __weak UIViewController *weakFeed = feed;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == [self shared].generation) [self recordHomePlayback:weakFeed itemID:itemID time:time];
        });
        return;
    }
    [self recordHomePlayback:feed itemID:itemID time:time];
}
// 39.5 直接观察实际播放器进度，不能只依赖 Feed 代理是否继续转发。
+ (BOOL)isCurrentHomePlayer:(UIViewController *)controller itemID:(NSString *)itemID {
    DYYYFriendShareService *s = [self shared];
    if (!controller || !itemID.length || ![self enabled] || ![self homeVisible] ||
        ![[self visibleHomeItemID] isEqual:itemID] ||
        ![[self itemID:[self value:controller key:@"model"]] isEqual:itemID]) return NO;
    UIViewController *cell = nil;
    BOOL underHome = NO;
    for (UIViewController *parent = controller; parent; parent = parent.parentViewController) {
        if ([parent isKindOfClass:NSClassFromString(@"AWEFeedCellViewController")]) cell = parent;
        if (parent == s.home) { underHome = YES; break; }
    }
    return underHome && cell && [self visibleHomeCell] == cell;
}
+ (void)playerPlaybackAdvanced:(UIViewController *)controller time:(NSTimeInterval)time {
    if (![self enabled]) return;
    NSString *itemID = [self itemID:[self value:controller key:@"model"]];
    NSUInteger generation = [self shared].generation;
    __weak UIViewController *weakPlayer = controller;
    void (^record)(void) = ^{
        if (generation != [self shared].generation || ![self isCurrentHomePlayer:weakPlayer itemID:itemID]) return;
        [self shared].state[@"progressSource"] = @"native_player";
        [self recordHomePlayback:[self shared].home itemID:itemID time:time];
    };
    if (NSThread.isMainThread) record(); else dispatch_async(dispatch_get_main_queue(), record);
}
+ (void)playerWillLoop:(UIViewController *)controller {
    if (![self enabled]) return;
    NSString *itemID = [self itemID:[self value:controller key:@"model"]];
    NSUInteger generation = [self shared].generation;
    __weak UIViewController *weakPlayer = controller;
    void (^record)(void) = ^{
        if (generation == [self shared].generation && [self isCurrentHomePlayer:weakPlayer itemID:itemID])
            [self homeWillLoop:[self shared].home];
    };
    if (NSThread.isMainThread) record(); else dispatch_async(dispatch_get_main_queue(), record);
}
+ (void)recordHomePlayback:(UIViewController *)feed itemID:(NSString *)itemID time:(NSTimeInterval)time {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || time <= 0 || ![self enabled] || ![self homeVisible] ||
        ![itemID isEqual:[self visibleHomeItemID]]) return;
    if (s.waitingToInsert && [s.home respondsToSelector:@selector(isPlaying)] && [s.home isPlaying]) {
        s.waitingToInsert = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ [self insertQueued]; });
    }
    [s.history recordPlaybackForItemID:itemID time:time];
    if (!s.pendingPlaybackID.length) return;
    if (![@[ @"native_play_requested", @"waiting_first_progress", @"cell_play_requested" ] containsObject:s.state[@"playbackStage"] ?: @""]) return;
    if (![itemID isEqual:s.pendingPlaybackID]) return;
    s.pendingPlaybackID = nil;
    s.state[@"playbackStage"] = @"progress_confirmed";
    s.state[@"confirmedPlayTime"] = @(time);
}
// history 已完成真实观看判定并持久化；这里只清理本轮加载队列，保留当前 Cell。
+ (void)didConsumeItemID:(NSString *)itemID {
    if (!itemID.length) return;
    DYYYFriendShareService *s = [self shared];
    [s.queued removeObject:itemID];
    s.state[@"lastConsumedItemID"] = itemID;
    s.state[@"consumedCount"] = @([s.state[@"consumedCount"] unsignedIntegerValue] + 1);
}
+ (void)homeDidScroll:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || ![self enabled] || ![self homeVisible] || ![self syncAccount]) return;
    id table = [self value:s.home key:@"tableView"];
    if ([table isKindOfClass:UIScrollView.class] && ([table isTracking] || [table isDragging] || [table isDecelerating])) return;
    NSString *current = [self visibleHomeItemID];
    if (!current.length) { s.state[@"dragStage"] = @"waiting_visible_cell"; return; }
    if (s.userDragging) {
        s.state[@"lastDragTo"] = current;
        s.state[@"dragStage"] = @"settled_visible_cell";
    }
    if (s.userDragging) [self didConsumeItemID:[s.history finishDraggingToItemID:current]];
    s.userDragging = NO; s.displayedID = current;
    [self pruneRejectedLegacyFeed];
    if (s.queued.count && !s.inFlight.count) [self insertQueued];
    [self applyPreparedFeed];
}
+ (void)homeDidScroll:(UIViewController *)feed scrollView:(UIScrollView *)scrollView {
    if (scrollView != [self value:feed key:@"tableView"]) return;
    [self homeDidScroll:feed];
}
// 实际 Cell 显示事件补齐原生结束代理没有同步完成的时序，不因预加载而消费。
+ (void)homeCellDidDisplay:(UIViewController *)cell {
    DYYYFriendShareService *s = [self shared];
    if (!NSThread.isMainThread || ![self enabled] || !s.userDragging || ![self homeVisible] || [self visibleHomeCell] != cell) return;
    [self homeDidEndScrolling:s.home scrollView:[self value:s.home key:@"tableView"]];
}
// UIKit 在结束代理内部可能仍报告 decelerating/tracking=YES；出栈后再结算。
+ (void)homeDidEndScrolling:(UIViewController *)feed scrollView:(UIScrollView *)scrollView {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || scrollView != [self value:feed key:@"tableView"] || !s.userDragging) return;
    NSUInteger generation = s.generation, ticket = s.dragTicket;
    __weak UIViewController *weakFeed = feed;
    __weak UIScrollView *weakScroll = scrollView;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self settleHomeScroll:weakFeed scrollView:weakScroll generation:generation ticket:ticket attempt:0];
    });
}
+ (void)settleHomeScroll:(UIViewController *)feed scrollView:(UIScrollView *)scrollView
            generation:(NSUInteger)generation ticket:(NSUInteger)ticket attempt:(NSUInteger)attempt {
    DYYYFriendShareService *s = [self shared];
    if (generation != s.generation || ticket != s.dragTicket || !s.userDragging || s.home != feed ||
        !scrollView || scrollView != [self value:feed key:@"tableView"] || ![self enabled] || ![self homeVisible]) return;
    [self homeDidScroll:feed];
    // 仅这次结束事件的短补同步，不持续轮询；新手势/离页/后台会使任务失效。
    if (s.userDragging && attempt < 4) {
        __weak UIViewController *weakFeed = feed;
        __weak UIScrollView *weakScroll = scrollView;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 20), dispatch_get_main_queue(), ^{
            [self settleHomeScroll:weakFeed scrollView:weakScroll generation:generation ticket:ticket attempt:attempt + 1];
        });
    }
}
+ (void)homeWillDrag:(UIViewController *)feed scrollView:(UIScrollView *)scrollView {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || scrollView != [self value:feed key:@"tableView"] || ![self enabled] || ![self homeVisible] || ![self syncAccount]) return;
    NSString *current = [self visibleHomeItemID];
    if (!current.length) { s.state[@"dragStage"] = @"no_visible_start"; return; }
    if (s.userDragging) {
        // 同一次手势的代理转发不重置；快速开始下一次手势时先结算上一次。
        if ([current isEqual:[s.history diagnostics][@"draggedID"]]) return;
        [self didConsumeItemID:[s.history finishDraggingToItemID:current]];
    }
    s.dragTicket++;
    [self homePlaybackTouched:feed];
    [s.history beginDraggingFromItemID:current];
    s.state[@"lastDragFrom"] = current;
    s.state[@"dragStage"] = @"started_visible_cell";
    s.userDragging = YES;
}
+ (void)homeWillLoop:(UIViewController *)feed {
    if (!NSThread.isMainThread) {
        __weak UIViewController *weakFeed = feed;
        dispatch_async(dispatch_get_main_queue(), ^{ [self homeWillLoop:weakFeed]; });
        return;
    }
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || ![self enabled] || ![self homeVisible] || ![self syncAccount]) return;
    NSString *itemID = [self visibleHomeItemID];
    if ([s.history completeLoopForItemID:itemID]) [self didConsumeItemID:itemID];
}
+ (void)homeDidLeave:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed) return;
    s.resumeAfterPageReturn = [s.home respondsToSelector:@selector(isPlaying)] && [s.home isPlaying];
    [s.history resetPlayback]; s.userDragging = NO; s.dragTicket++;
    s.playbackTicket++; s.pendingPlaybackID = nil;
}
+ (void)clearWatched {
    if (![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
    [s.history clearWatched];
    [s.history importLegacySources:s.sources];
    s.restoredGeneration = NSNotFound;
}
@end
