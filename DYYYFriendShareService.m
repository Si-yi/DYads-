#import "DYYYFriendShareService.h"
#import "DYYYIMService.h"
#import "DYYYFriendShareHistory.h"
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
@property (nonatomic) NSUInteger playbackSyncTicket;
@property (nonatomic) BOOL selectedOpeningShare;
@property (nonatomic) BOOL waitingToInsert;
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
    state[@"currentItemID"] = [self itemID:s.home.currentAweme] ?: @"";
    if ([s.home respondsToSelector:@selector(isPlaying)]) state[@"nativePlaying"] = @([s.home isPlaying]);
    if ([s.home respondsToSelector:@selector(currentIndex)]) state[@"currentIndex"] = @(s.home.currentIndex);
    if ([s.home respondsToSelector:@selector(currentPlayIndex)]) state[@"currentPlayIndex"] = @(s.home.currentPlayIndex);
    return state;
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
        [s.queued removeAllObjects]; [s.active removeAllObjects]; [s.models removeAllObjects];
        [s.inFlight removeAllObjects]; [s.failed removeAllObjects];
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
    [s.history resetPlayback]; s.userDragging = NO;
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
    [s.failed removeAllObjects];
    [s.history resetPlayback];
    if ([self automatic]) [self restoreSavedShares];
    [self tryOpeningScan];
}
+ (void)bindHomeFeed:(UIViewController *)feed {
    AWEFeedTableViewController *home = (id)feed;
    if (![home respondsToSelector:@selector(dataController)] || ![home.dataController isKindOfClass:NSClassFromString(@"AWEHotListDataController")]) return;
    [self shared].home = home;
    if ([self automatic]) [self restoreSavedShares];
    if ([self shared].openingPending && [self automatic]) [self cleanOpeningCache];
    [self tryOpeningScan]; [self insertQueued]; [self homeDidScroll:feed];
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
    if (![self enabled] || ![self automatic] || !s.openingPending || s.scanScheduled || s.scanInProgress || s.attempts >= 8 || ![self homeVisible]) return;
    if (NSClassFromString(@"FriendShareFeedService")) return;
    // 先同步账户和持久待刷队列；即使本次消息读取失败也能恢复上次未刷分享。
    [self syncAccount];
    [self restoreSavedShares];
    s.attempts++; s.scanScheduled = YES;
    NSUInteger generation = s.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
        if (generation != s.generation) return;
        s.scanScheduled = NO;
        if (![self enabled] || ![self homeVisible] || !s.openingPending || s.scanInProgress) return;
        NSArray *users = [NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[];
        if (!users.count) { s.openingPending = NO; return; }
        s.scanInProgress = YES;
        [DYYYIMService unreadSharesForUsers:users completion:^(NSArray *rows, NSString *warning) {
            if (generation != s.generation) return;
            s.scanInProgress = NO;
            if (![users isEqualToArray:[NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[]]) return;
            if (![self enabled] || ![self automatic]) return;
            s.state[@"lastScanWarning"] = warning ?: @"";
            if (rows.count) [self queueRows:rows toast:NO];
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
    [s.failed removeAllObjects];
    s.selectedOpeningShare = NO;
    s.restoredGeneration = NSNotFound;
    [self restoreSavedShares];
    s.scanInProgress = YES;
    NSUInteger generation = s.generation;
    if (showToast) [DYYYUtils showToast:@"正在读取好友近期分享"];
    [DYYYIMService unreadSharesForUsers:users completion:^(NSArray *rows, NSString *warning) {
        if (generation != s.generation) return;
        s.scanInProgress = NO;
        s.openingPending = NO;
        if (![users isEqualToArray:[NSUserDefaults.standardUserDefaults arrayForKey:@"DYYYFriendShareFeedFriends"] ?: @[]]) return;
        if (![self enabled]) return;
        s.state[@"lastScanWarning"] = warning ?: @"";
        if (rows.count || !warning) [self queueRows:rows toast:showToast && !warning];
        if (showToast && warning) [DYYYUtils showToast:warning];
    }];
}
+ (void)queueRows:(NSArray *)rows toast:(BOOL)toast {
    if (![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
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
        if (![itemID isKindOfClass:NSString.class] || !itemID.length || [watched containsObject:itemID]) continue;
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
    s.state[@"scanVideoCount"] = @(rows.count);
    [self insertQueued];
    if (toast) [DYYYUtils showToast:s.queued.count ? @"已找到未刷分享，正在加载真实视频；返回首页后插入" : @"没有新的未刷分享视频"];
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
    for (NSString *itemID in ids) {
        id model = s.models[itemID] ?: [self cachedModel:itemID];
        if (model) { s.models[itemID] = model; [s.inFlight removeObject:itemID]; }
        else [missing addObject:itemID];
    }
    if (!missing.count || attempt >= 30) {
        for (NSString *itemID in missing) { [s.inFlight removeObject:itemID]; [s.failed addObject:itemID]; }
        s.state[@"stage"] = missing.count ? @"model_load_timeout" : @"models_ready";
        if (missing.count) [DYYYUtils showToast:@"部分分享视频暂未加载成功，保留待加载记录，可手动重试"];
        [self insertQueued]; return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), ^{
        [self pollModels:missing account:account generation:generation attempt:attempt + 1];
    });
}
+ (void)insertQueued {
    DYYYFriendShareService *s = [self shared];
    if (![self enabled] || NSClassFromString(@"FriendShareFeedService") || ![self syncAccount] || ![self homeVisible] || s.arranging || !s.queued.count) return;
    AWEFeedTableViewController *home = s.home;
    id nativeTable = [self value:home key:@"tableView"];
    if ([nativeTable isKindOfClass:UIScrollView.class] && ([nativeTable isTracking] || [nativeTable isDragging] || [nativeTable isDecelerating])) return;
    if (s.inFlight.count) return;
    // 用户已接管并暂停时，先保留队列，等实际恢复播放/滑动结束再插入，
    // 避免原生重载入口重建 Cell 时破坏暂停意图。
    if (s.selectedOpeningShare && [home respondsToSelector:@selector(isPlaying)] && ![home isPlaying] && [self itemID:home.currentAweme].length) {
        s.waitingToInsert = YES;
        return;
    }
    s.waitingToInsert = NO;
    SEL insert = @selector(insertAwemeModel:atIndex:shouldForceReload:byBiz:);
    if (![home respondsToSelector:insert]) { s.state[@"stage"] = @"model_insert_unavailable"; return; }
    NSArray *data = [(AWEListDataController *)home.dataController dataSource];
    if (![data isKindOfClass:NSArray.class] || !data.count) return;
    NSMutableArray *ready = [NSMutableArray array], *missing = [NSMutableArray array];
    NSSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    for (NSString *itemID in [s.queued copy]) {
        if ([watched containsObject:itemID]) { [s.queued removeObject:itemID]; continue; }
        if ([s.failed containsObject:itemID]) continue;
        id model = s.models[itemID] ?: [self cachedModel:itemID];
        if (model) { s.models[itemID] = model; [ready addObject:itemID]; }
        else if (![s.inFlight containsObject:itemID] && ![s.failed containsObject:itemID] && missing.count < 20) [missing addObject:itemID];
    }
    BOOL inserted = NO;
    NSString *previousItemID = [self itemID:home.currentAweme];
    BOOL wasPlaying = [home respondsToSelector:@selector(isPlaying)] && [home isPlaying];
    NSUInteger selectionTicket = s.playbackTicket;
    NSMutableSet *known = [self storedIDs:@"DYYYFriendShareInsertedItemIDs"];
    // 整批插入期间暂停自定义排序，避免原生插入中途再次改写模型/索引。
    s.arranging = YES;
    @try {
        for (NSString *itemID in ready.reverseObjectEnumerator) {
            BOOL exists = NO;
            for (id model in [(AWEListDataController *)home.dataController dataSource]) if ([[self itemID:model] isEqual:itemID]) { exists = YES; break; }
            if (!exists) {
                @try {
                    [home insertAwemeModel:s.models[itemID] atIndex:0 shouldForceReload:NO byBiz:0];
                } @catch (__unused NSException *e) { s.state[@"stage"] = @"insert_exception"; }
                for (id model in [(AWEListDataController *)home.dataController dataSource]) if ([[self itemID:model] isEqual:itemID]) { exists = YES; break; }
            }
            if (exists) { [s.active insertObject:itemID atIndex:0]; [s.queued removeObject:itemID]; [known addObject:itemID]; inserted = YES; }
            else { [s.failed addObject:itemID]; s.state[@"stage"] = @"insert_not_confirmed"; }
        }
    } @finally { s.arranging = NO; }
    [self orderActiveShares];
    if (inserted) {
        [self saveIDs:known name:@"DYYYFriendShareInsertedItemIDs"];
        s.state[@"stage"] = @"inserted";
        NSUInteger generation = s.generation;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != s.generation || selectionTicket != s.playbackTicket || ![self homeVisible] || s.userDragging) return;
            NSArray *data = [(AWEListDataController *)home.dataController dataSource];
            NSArray *ordered = [self arrangeData:data controller:home.dataController];
            if (ordered != data) [(AWEHotListDataController *)home.dataController updateAwemeList:ordered];
            // 首批主动展示分享；后续批次保留当前视频和用户暂停状态。
            BOOL firstSelection = !s.selectedOpeningShare;
            NSString *target = firstSelection ? s.active.firstObject : previousItemID;
            s.selectedOpeningShare = YES;
            [self selectShare:target startPlayback:firstSelection || wasPlaying generation:generation];
        });
    }
    if (missing.count && !s.inFlight.count) {
        if ([self requestModels:missing]) {
            [s.inFlight addObjectsFromArray:missing];
            [self pollModels:missing account:s.account generation:s.generation attempt:0];
        } else {
            [s.failed addObjectsFromArray:missing]; s.state[@"stage"] = @"model_request_unavailable";
            [DYYYUtils showToast:@"当前版本的视频模型加载入口不可用，未改动首页，请导出调试记录"];
        }
    }
}

#pragma mark - 首页列表保持与已刷记录

+ (NSArray *)arrangeData:(NSArray *)data controller:(id)controller {
    DYYYFriendShareService *s = [self shared];
    if (!NSThread.isMainThread || s.arranging || ![self enabled] || ![data isKindOfClass:NSArray.class] || controller != s.home.dataController || ![self syncAccount]) return data;
    NSMutableSet *watched = [self storedIDs:@"DYYYFriendShareWatchedItemIDs"];
    NSSet *known = [self storedIDs:@"DYYYFriendShareInsertedItemIDs"];
    NSMutableArray *result = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    // 正在播放的分享即使已播完一轮也保留，离开它之后才参与过滤。
    for (NSString *itemID in [s.active copy]) {
        if ([watched containsObject:itemID] && ![itemID isEqual:s.displayedID]) { [s.active removeObject:itemID]; [s.models removeObjectForKey:itemID]; continue; }
        if (s.models[itemID]) { [result addObject:s.models[itemID]]; [seen addObject:itemID]; }
    }
    for (id model in data) {
        NSString *itemID = [self itemID:model];
        if (itemID && [seen containsObject:itemID]) continue;
        if ([known containsObject:itemID ?: @""] && [watched containsObject:itemID ?: @""] && ![itemID isEqual:s.displayedID]) continue;
        [result addObject:model]; if (itemID) [seen addObject:itemID];
    }
    NSMutableSet *pending = [NSMutableSet setWithArray:s.queued.array];
    [pending minusSet:s.failed];
    if (pending.count && !s.inFlight.count) dispatch_async(dispatch_get_main_queue(), ^{ [self insertQueued]; });
    BOOL same = result.count == data.count;
    if (same) for (NSUInteger i = 0; i < result.count; i++) if (result[i] != data[i]) { same = NO; break; }
    return same ? data : result;
}
+ (void)cleanOpeningCache {
    if (![self enabled] || ![self syncAccount]) return;
    DYYYFriendShareService *s = [self shared];
    NSArray *data = [(AWEListDataController *)s.home.dataController dataSource];
    if (![data isKindOfClass:NSArray.class]) return;
    NSArray *kept = [self arrangeData:data controller:s.home.dataController];
    if (kept != data) {
        [(AWEHotListDataController *)s.home.dataController updateAwemeList:kept];
        id table = [self value:s.home key:@"tableView"];
        if ([table isKindOfClass:UITableView.class]) [table reloadData];
        if (!kept.count && [self homeVisible] && [s.home respondsToSelector:@selector(awe_refreshForceRequestWithoutAnimation)]) [s.home awe_refreshForceRequestWithoutAnimation];
    }
}
// 使用原生索引重载入口同步 Cell、currentAweme 和播放器。仅滚动到已在屏幕上的
// 第 0 行不会触发滚动结束流程，直接 UITableView.reloadData 也不会更新播放状态。
+ (void)selectShare:(NSString *)itemID startPlayback:(BOOL)start generation:(NSUInteger)generation {
    DYYYFriendShareService *s = [self shared];
    if (!itemID.length || generation != s.generation || ![self enabled] || ![self homeVisible] || s.userDragging) return;
    AWEFeedTableViewController *home = s.home;
    NSArray *data = [(AWEListDataController *)home.dataController dataSource];
    if (![data isKindOfClass:NSArray.class]) return;
    NSUInteger index = [data indexOfObjectPassingTest:^BOOL(id model, NSUInteger idx, BOOL *stop) {
        return [[self itemID:model] isEqual:itemID];
    }];
    if (index == NSNotFound) return;
    if (![home respondsToSelector:@selector(reloadWithCurrentIndex:)]) {
        s.state[@"playbackStage"] = @"native_selection_unavailable";
        return;
    }
    NSUInteger ticket = ++s.playbackTicket;
    s.pendingPlaybackID = start ? itemID : nil;
    s.state[@"playbackStage"] = @"selecting_native_cell";
    s.state[@"selectionIndex"] = @(index);
    @try {
        [home reloadWithCurrentIndex:(long long)index];
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
    }
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
                s.displayedID = itemID;
                if ([home respondsToSelector:@selector(playIfActive)]) {
                    s.state[@"playbackStage"] = @"native_play_requested";
                    [home playIfActive];
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

+ (void)homePlaybackTouched:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || ![self enabled]) return;
    s.playbackTicket++; s.pendingPlaybackID = nil; s.selectedOpeningShare = YES;
    s.state[@"playbackStage"] = @"user_controlled";
}
+ (void)homePlaybackAdvanced:(UIViewController *)feed time:(NSTimeInterval)time {
    if (!NSThread.isMainThread) {
        __weak UIViewController *weakFeed = feed;
        dispatch_async(dispatch_get_main_queue(), ^{ [self homePlaybackAdvanced:weakFeed time:time]; });
        return;
    }
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || time <= 0 || ![self enabled]) return;
    if (s.waitingToInsert && [self homeVisible] && [s.home respondsToSelector:@selector(isPlaying)] && [s.home isPlaying]) {
        s.waitingToInsert = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ [self insertQueued]; });
    }
    if ([self homeVisible]) [s.history recordPlaybackForItemID:[self itemID:s.home.currentAweme] time:time];
    if (!s.pendingPlaybackID.length || ![self homeVisible]) return;
    if (![s.state[@"playbackStage"] isEqual:@"native_play_requested"]) return;
    if (![[self itemID:s.home.currentAweme] isEqual:s.pendingPlaybackID]) return;
    s.pendingPlaybackID = nil;
    s.state[@"playbackStage"] = @"progress_confirmed";
    s.state[@"confirmedPlayTime"] = @(time);
}
// history 已完成真实观看判定并持久化；这里只清理本轮加载队列，保留当前 Cell。
+ (void)didConsumeItemID:(NSString *)itemID {
    if (itemID.length) [[self shared].queued removeObject:itemID];
}
+ (void)homeDidScroll:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || ![self enabled] || ![self homeVisible] || ![self syncAccount]) return;
    id table = [self value:s.home key:@"tableView"];
    if ([table isKindOfClass:UIScrollView.class] && ([table isTracking] || [table isDragging] || [table isDecelerating])) return;
    NSString *current = [self itemID:s.home.currentAweme];
    if (!current.length) return;
    if (s.userDragging) [self didConsumeItemID:[s.history finishDraggingToItemID:current]];
    s.userDragging = NO; s.displayedID = current;
    if (s.queued.count && !s.inFlight.count) [self insertQueued];
}
+ (void)homeDidScroll:(UIViewController *)feed scrollView:(UIScrollView *)scrollView {
    if (scrollView != [self value:feed key:@"tableView"]) return;
    [self homeDidScroll:feed];
}
+ (void)homeWillDrag:(UIViewController *)feed scrollView:(UIScrollView *)scrollView {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed || scrollView != [self value:feed key:@"tableView"] || ![self enabled] || ![self homeVisible] || ![self syncAccount]) return;
    [self homePlaybackTouched:feed];
    [s.history beginDraggingFromItemID:[self itemID:s.home.currentAweme]];
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
    NSString *itemID = [self itemID:s.home.currentAweme];
    if ([s.history completeLoopForItemID:itemID]) [self didConsumeItemID:itemID];
}
+ (void)homeDidLeave:(UIViewController *)feed {
    DYYYFriendShareService *s = [self shared];
    if (s.home != feed) return;
    [s.history resetPlayback]; s.userDragging = NO;
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
