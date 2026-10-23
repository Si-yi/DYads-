#import "DYYYAutoMessage.h"
#import "DYYYAutoMessagePanel.h"
#import "DYYYIMService.h"

#import "AwemeHeaders.h"
#import "DYYYSettingsHelper.h"
#import "DYYYUtils.h"

static NSString *const kDYYYAutoMessageEnabled = @"DYYYAutoMessageEnabled";
static NSString *const kDYYYAutoMessageConfigs = @"DYYYAutoMessageConfigs";
static NSString *const kDYYYAutoMessageQueryKeyword = @"DYYYAutoMessageIDQueryKeyword";
static NSString *const kDYYYAutoMessageNoSendTime = @"DYYYAutoMessageNoSendTime";
static NSString *const kDYYYAutoMessageToast = @"DYYYAutoMessageToastEnabled";
static NSString *const kDYYYAutoMessageAllSentToast = @"DYYYAutoMessageAllSentToastEnabled";

static NSString *const kDYYYFriendShareEnabled = @"DYYYFriendShareFeedEnabled";
static NSString *const kDYYYFriendShareAutoRefresh = @"DYYYFriendShareAutoRefreshEnabled";
static NSString *const kDYYYFriendShareFriends = @"DYYYFriendShareFeedFriends";
static NSString *const kDYYYFriendShareWatchedIDs = @"DYYYFriendShareWatchedItemIDs";

@implementation DYYYAutoMessage

#pragma mark - 配置存储

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (NSMutableArray<NSMutableDictionary *> *)messageConfigs {
    id value = [[self defaults] objectForKey:kDYYYAutoMessageConfigs];
    NSMutableArray<NSMutableDictionary *> *configs = [NSMutableArray array];
    if ([value isKindOfClass:NSArray.class]) {
        for (id row in (NSArray *)value) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSString *userID = [row[@"userID"] isKindOfClass:NSString.class] ? row[@"userID"] : @"";
            if (userID.length == 0) continue;
            [configs addObject:[@{
                @"userID" : userID,
                @"name" : [row[@"name"] isKindOfClass:NSString.class] ? row[@"name"] : userID,
                @"ownerID" : [row[@"ownerID"] isKindOfClass:NSString.class] ? row[@"ownerID"] : @"",
                @"message" : [row[@"message"] isKindOfClass:NSString.class] ? row[@"message"] : @"",
                @"enabled" : @([row[@"enabled"] respondsToSelector:@selector(boolValue)] ? [row[@"enabled"] boolValue] : YES)
            } mutableCopy]];
        }
    }
    return configs;
}

+ (void)saveMessageConfigs:(NSArray *)configs {
    NSMutableArray *saved = [NSMutableArray array];
    for (NSDictionary *row in configs) {
        NSMutableDictionary *config = [row mutableCopy];
        [saved addObject:config];
    }
    [[self defaults] setObject:saved forKey:kDYYYAutoMessageConfigs];
}

+ (NSString *)todayKey {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:[NSDate date]];
}

+ (BOOL)isNoSendTime {
    NSString *range = [[[self defaults] stringForKey:kDYYYAutoMessageNoSendTime] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (range.length == 0) return NO;
    NSArray<NSString *> *parts = [range componentsSeparatedByString:@"-"];
    if (parts.count != 2) return NO;
    NSInteger start = [[parts[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] integerValue];
    NSInteger end = [[parts[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] integerValue];
    if (start < 0 || start > 23 || end < 0 || end > 23 || start == end) return NO;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger hour = [calendar component:NSCalendarUnitHour fromDate:[NSDate date]];
    return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end);
}

#pragma mark - 发送与扫描

+ (BOOL)openNativeChatForUserID:(NSString *)userID message:(NSString *)message {
    if (userID.length == 0 || message.length == 0) return NO;
    NSString *encodedMessage = [message stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *encodedUserID = [userID stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"snssdk1128://chat/user/%@?message=%@", encodedUserID ?: @"", encodedMessage ?: @""]];
    if (!url) return NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    });
    return YES;
}

+ (void)processDailyConfigs:(NSMutableArray *)configs completion:(void (^)(void))completion {
    if (![[self defaults] boolForKey:kDYYYAutoMessageEnabled] || [self isNoSendTime]) { if (completion) completion(); return; }
    if (!configs.count) { if (completion) completion(); return; }
    NSDictionary *config = configs.firstObject;
    [configs removeObjectAtIndex:0];
    if (![config[@"enabled"] boolValue] || ![config[@"ownerID"] isEqualToString:[DYYYIMService accountID]] || [DYYYIMService dailyStateForUserID:config[@"userID"]].length) {
        [self processDailyConfigs:configs completion:completion];
        return;
    }
    [DYYYIMService sendText:config[@"message"] toUserID:config[@"userID"] completion:^(BOOL success, NSString *reason) {
        if ([[self defaults] boolForKey:kDYYYAutoMessageToast]) [DYYYUtils showToast:reason];
        [self processDailyConfigs:configs completion:completion];
    }];
}

+ (void)runDailyMessageCheckIfNeeded {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self runDailyMessageCheckIfNeeded]; });
        return;
    }
    if (![[self defaults] boolForKey:kDYYYAutoMessageEnabled] || [self isNoSendTime]) return;
    // 同时注入原版时停止 DYYY 的自动调度，卸掉原版后无需它即可运行。
    if (NSClassFromString(@"AutoMessageManager")) return;
    static BOOL processing;
    if (processing || ![DYYYIMService accountID].length) return;
    processing = YES;
    NSString *account = [DYYYIMService accountID];
    NSMutableArray *configs = [NSMutableArray array];
    for (NSDictionary *config in [self messageConfigs]) if ([config[@"ownerID"] isEqual:account]) [configs addObject:config];
    [self processDailyConfigs:configs completion:^{ processing = NO; }];
}

+ (void)scanFriendSharesWithToast:(BOOL)showToast {
    // 分享作品的详情获取和推荐流插入需要单独适配，不回退到已卸载插件的服务。
    if (showToast) [DYYYUtils showToast:@"好友来源选择已独立接入，分享扫描与推荐流插入仍在适配"];
}

#pragma mark - 互关好友数据

+ (id)friendValue:(id)object keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        @try {
            id value = [object isKindOfClass:NSDictionary.class] ? object[key] : [object valueForKey:key];
            if ([value isKindOfClass:NSString.class] && ![value length]) continue;
            if (value && value != NSNull.null) return value;
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}

+ (NSArray<NSDictionary *> *)normalizedFriends:(id)rows requireMutual:(BOOL)requireMutual {
    if ([rows isKindOfClass:NSDictionary.class]) rows = [self friendValue:rows keys:@[@"friends", @"users", @"userList", @"data"]];
    if (![rows isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *friends = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id row in rows) {
        id nested = [self friendValue:row keys:@[@"user", @"userModel", @"imUser", @"userInfo"]];
        id model = nested ?: row;
        id mutual = [self friendValue:model keys:@[@"isMutualFollow", @"isFriend"]];
        id follow = [self friendValue:model keys:@[@"followStatus", @"follow_status"]];
        id follower = [self friendValue:model keys:@[@"followerStatus", @"follower_status"]];
        BOOL bothFollow = [follow integerValue] == 1 && [follower integerValue] == 1;
        if (requireMutual && ![mutual boolValue] && [follow integerValue] != 2 && !bothFollow) continue;
        id uidValue = [self friendValue:model keys:@[@"userID", @"uid", @"userId", @"user_id"]];
        NSString *uid = [uidValue isKindOfClass:NSString.class] ? uidValue : ([uidValue isKindOfClass:NSNumber.class] ? [uidValue stringValue] : nil);
        if (!uid.length || [seen containsObject:uid]) continue;
        [seen addObject:uid];
        id nameValue = [self friendValue:model keys:@[@"name", @"nickname", @"nickName", @"displayName", @"display_name", @"contactName"]];
        NSString *name = [nameValue isKindOfClass:NSString.class] ? nameValue : uid;
        id displayValue = [self friendValue:model keys:@[@"displayID", @"uniqueID", @"uniqueId", @"shortID", @"shortId", @"short_id", @"username"]];
        NSString *display = [displayValue isKindOfClass:NSString.class] ? displayValue : uid;
        id flameInfo = [self friendValue:row keys:@[@"streakInfo", @"flameInfo"]];
        id daysValue = [self friendValue:row keys:@[@"flameDays", @"streakDays", @"streakCount"]] ?:
            [self friendValue:flameInfo keys:@[@"days", @"streakDays", @"streakCount"]];
        NSInteger days = [daysValue respondsToSelector:@selector(integerValue)] ? [daysValue integerValue] : 0;
        id hasFlame = [self friendValue:row keys:@[@"hasFlame", @"isFlameFriend"]];
        id avatar = [self friendValue:model keys:@[@"avatar", @"avatarThumb", @"avatarURL", @"avatarUrl", @"avatar_thumb", @"avatarSmallStrUrl", @"avatarStrUrls", @"avatarURLList"]];
        if ([avatar isKindOfClass:NSArray.class]) avatar = [avatar firstObject];
        if (avatar && ![avatar isKindOfClass:NSString.class]) avatar = [self friendValue:avatar keys:@[@"urlList", @"url_list", @"url"]];
        if ([avatar isKindOfClass:NSArray.class]) avatar = [avatar firstObject];
        [friends addObject:@{ @"userID":uid, @"name":name, @"displayID":display,
            @"avatar":[avatar isKindOfClass:NSString.class] ? avatar : @"",
            @"hasFlame":@([hasFlame respondsToSelector:@selector(boolValue)] ? [hasFlame boolValue] : days > 0), @"flameDays":@(MAX(0, days)) }];
    }
    [friends sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        if ([a[@"hasFlame"] boolValue] != [b[@"hasFlame"] boolValue]) return [a[@"hasFlame"] boolValue] ? NSOrderedAscending : NSOrderedDescending;
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    return friends;
}

+ (void)loadMutualFriends:(void (^)(NSArray<NSDictionary *> *friends))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self loadMutualFriends:completion]; });
        return;
    }
    id database = [DYYYIMService contactDatabase];
    NSArray *friends = @[];
    @try {
        if ([database respondsToSelector:@selector(fetchFriendUsersWithLimits:readScene:)]) {
            id rows = [(AWEIMUserDBManager *)database fetchFriendUsersWithLimits:10000 readScene:0];
            friends = [self normalizedFriends:rows requireMutual:NO];
        }
        if (!friends.count && [database respondsToSelector:@selector(localContactListWithReadScene:)]) {
            id rows = [(AWEIMUserDBManager *)database localContactListWithReadScene:0];
            friends = [self normalizedFriends:rows requireMutual:YES];
        }
    } @catch (__unused NSException *exception) {
        [DYYYUtils showToast:@"抖音联系人暂时不可读，请进入消息页后再试"];
    }
    NSString *account = [DYYYIMService accountID];
    NSString *cacheKey = account.length ? [@"DYYYMutualFriendsCache." stringByAppendingString:account] : nil;
    if (friends.count && cacheKey) [[self defaults] setObject:friends forKey:cacheKey];
    if (!friends.count && cacheKey) friends = [[self defaults] arrayForKey:cacheKey] ?: @[];
    if (!database) [DYYYUtils showToast:@"联系人服务尚未就绪，请先进入抖音消息页"];
    if (completion) completion(friends);
}


#pragma mark - 设置页面

+ (AWESettingItemModel *)setting:(NSDictionary *)dictionary {
    return [DYYYSettingsHelper createSettingItem:dictionary];
}

+ (void)editConfigFrom:(UIViewController *)root existing:(NSMutableDictionary *)existing completion:(void (^)(void))completion {
    NSString *initialID = existing[@"userID"] ?: @"";
    [DYYYSettingsHelper showTextInputAlert:@"用户 ID" defaultText:initialID placeholder:@"输入抖音用户 ID" onConfirm:^(NSString *userID) {
        NSString *trimmedID = [userID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmedID.length == 0) return;
        [DYYYSettingsHelper showTextInputAlert:@"每日发送内容" defaultText:existing[@"message"] ?: @"" placeholder:@"输入消息内容" onConfirm:^(NSString *message) {
            NSMutableArray *configs = [self messageConfigs];
            NSUInteger index = [configs indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
                return [row[@"userID"] isEqualToString:existing[@"userID"] ?: trimmedID];
            }];
            NSMutableDictionary *config = [@{ @"userID" : trimmedID, @"name" : existing[@"name"] ?: trimmedID, @"ownerID" : [DYYYIMService accountID],
                                               @"message" : message ?: @"", @"enabled" : existing[@"enabled"] ?: @YES } mutableCopy];
            if (index != NSNotFound) configs[index] = config; else [configs addObject:config];
            [self saveMessageConfigs:configs];
            if (completion) completion();
        } onCancel:nil];
    } onCancel:nil];
}

+ (NSArray<AWESettingSectionModel *> *)messageConfigSectionsWithRoot:(UIViewController *)root {
    NSMutableArray *items = [NSMutableArray array];
    AWESettingItemModel *add = [self setting:@{ @"identifier" : @"DYYYAutoMessageAdd", @"title" : @"添加自动消息配置", @"detail" : @"", @"cellType" : @26, @"imageName" : @"ic_add_outlined_20" }];
    add.cellTappedBlock = ^{ [self editConfigFrom:root existing:nil completion:nil]; };
    [items addObject:add];
    for (NSMutableDictionary *config in [self messageConfigs]) {
        AWESettingItemModel *row = [self setting:@{ @"identifier" : [@"DYYYAutoMessageConfig." stringByAppendingString:config[@"userID"]],
            @"title" : config[@"name"] ?: config[@"userID"], @"detail" : [config[@"enabled"] boolValue] ? @"已启用" : @"已停用", @"cellType" : @26,
            @"imageName" : @"ic_comment_outlined_20" }];
        row.cellTappedBlock = ^{ [self editConfigFrom:root existing:config completion:nil]; };
        [items addObject:row];
    }
    return @[ [DYYYSettingsHelper createSectionWithTitle:@"消息配置" footerTitle:@"每位用户每天只处理一次。点击已有配置可修改用户 ID 和消息内容。" items:items] ];
}

+ (NSArray<AWESettingSectionModel *> *)settingsSectionsWithRootViewController:(UIViewController *)rootViewController {
    AWESettingItemModel *enabled = [self setting:@{ @"identifier" : kDYYYAutoMessageEnabled, @"title" : @"启用自动消息", @"subTitle" : @"使用抖音原生消息服务，每日去重", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_comment_outlined_20" }];
    AWESettingItemModel *configs = [self setting:@{ @"identifier" : @"DYYYAutoMessageConfigPage", @"title" : @"自动消息设置", @"detail" : @"", @"cellType" : @26, @"imageName" : @"ic_comment_outlined_20" }];
    configs.cellTappedBlock = ^{
        [DYYYAutoMessagePanel showConfigsFrom:rootViewController];
    };
    AWESettingItemModel *status = [self setting:@{ @"identifier" : @"DYYYAutoMessageStatus", @"title" : @"检测发送状态", @"detail" : @"", @"cellType" : @26, @"imageName" : @"ic_eye_outlined_20" }];
    status.cellTappedBlock = ^{
        NSUInteger sent = 0, pending = 0;
        for (NSDictionary *config in [self messageConfigs]) {
            NSString *state = [DYYYIMService dailyStateForUserID:config[@"userID"]];
            if ([state isEqual:@"sent"]) sent++;
            if ([state isEqual:@"pending"]) pending++;
        }
        [DYYYUtils showToast:[NSString stringWithFormat:@"今日已确认 %lu 位，待确认 %lu 位", (unsigned long)sent, (unsigned long)pending]];
    };
    AWESettingItemModel *keyword = [self setting:@{ @"identifier" : kDYYYAutoMessageQueryKeyword, @"title" : @"ID 查询关键词", @"detail" : @"查询id", @"cellType" : @26, @"imageName" : @"ic_pensketch_outlined_20" }];
    keyword.detail = [[self defaults] stringForKey:kDYYYAutoMessageQueryKeyword] ?: @"查询id";
    keyword.cellTappedBlock = ^{ [DYYYSettingsHelper showTextInputAlert:@"ID 查询关键词" defaultText:keyword.detail placeholder:@"例如：查询id" onConfirm:^(NSString *text) { [[self defaults] setObject:text ?: @"查询id" forKey:kDYYYAutoMessageQueryKeyword]; keyword.detail = text ?: @"查询id"; [keyword refreshCell]; } onCancel:nil]; };
    AWESettingItemModel *noSend = [self setting:@{ @"identifier" : kDYYYAutoMessageNoSendTime, @"title" : @"不发送时间段", @"detail" : @"", @"cellType" : @26, @"imageName" : @"ic_eyeslash_outlined_20" }];
    noSend.detail = [[self defaults] stringForKey:kDYYYAutoMessageNoSendTime] ?: @"未设置";
    noSend.cellTappedBlock = ^{ [DYYYSettingsHelper showTextInputAlert:@"不发送时间段" defaultText:[[self defaults] stringForKey:kDYYYAutoMessageNoSendTime] placeholder:@"格式：00-08" onConfirm:^(NSString *text) { [[self defaults] setObject:text ?: @"" forKey:kDYYYAutoMessageNoSendTime]; noSend.detail = text.length ? text : @"未设置"; [noSend refreshCell]; } onCancel:nil]; };
    AWESettingItemModel *toast = [self setting:@{ @"identifier" : kDYYYAutoMessageToast, @"title" : @"显示发送提示", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_bell_outlined_20" }];
    AWESettingItemModel *allToast = [self setting:@{ @"identifier" : kDYYYAutoMessageAllSentToast, @"title" : @"显示已全部发送提示", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_bell_outlined_20" }];

    AWESettingItemModel *feedEnabled = [self setting:@{ @"identifier" : kDYYYFriendShareEnabled, @"title" : @"启用好友分享进推荐", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_video_outlined_20" }];
    AWESettingItemModel *autoRefresh = [self setting:@{ @"identifier" : kDYYYFriendShareAutoRefresh, @"title" : @"自动刷新推荐", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_circlearrowin_outlined_20" }];
    AWESettingItemModel *sourceFriends = [self setting:@{ @"identifier" : kDYYYFriendShareFriends, @"title" : @"选择分享来源好友", @"detail" : @"", @"cellType" : @26, @"imageName" : @"ic_user_outlined_20" }];
    sourceFriends.detail = [NSString stringWithFormat:@"%lu 人", (unsigned long)[[[self defaults] arrayForKey:kDYYYFriendShareFriends] count]];
    sourceFriends.cellTappedBlock = ^{
        [DYYYAutoMessagePanel showFriendsFrom:rootViewController selectedIDs:[[self defaults] arrayForKey:kDYYYFriendShareFriends] completion:^(NSArray<NSDictionary *> *friends) {
            NSMutableArray *ids = [NSMutableArray array];
            for (NSDictionary *friend in friends) if ([friend[@"userID"] length]) [ids addObject:friend[@"userID"]];
            [[self defaults] setObject:ids forKey:kDYYYFriendShareFriends];
            sourceFriends.detail = [NSString stringWithFormat:@"%lu 人", (unsigned long)ids.count];
            [sourceFriends refreshCell];
        }];
    };
    AWESettingItemModel *scan = [self setting:@{ @"identifier" : @"DYYYFriendShareScan", @"title" : @"立即扫描好友分享", @"detail" : @"扫描", @"cellType" : @26, @"imageName" : @"ic_videosearch_outlined_20" }];
    scan.cellTappedBlock = ^{ [self scanFriendSharesWithToast:YES]; };
    AWESettingItemModel *clear = [self setting:@{ @"identifier" : @"DYYYFriendShareClear", @"title" : @"清除已刷记录", @"detail" : @"", @"cellType" : @26, @"imageName" : @"ic_trash_outlined_20" }];
    clear.cellTappedBlock = ^{ [[self defaults] removeObjectForKey:kDYYYFriendShareWatchedIDs]; [DYYYUtils showToast:@"已清除好友分享已刷记录"]; };

    return @[
        [DYYYSettingsHelper createSectionWithTitle:@"自动消息" footerTitle:@"开启后在抖音启动时处理配置；不发送时间段内不会触发。" items:@[enabled, configs, status, keyword, noSend, toast, allToast]],
        [DYYYSettingsHelper createSectionWithTitle:@"好友分享进推荐" footerTitle:@"仅处理所选好友的分享来源，并记录已处理作品。" items:@[feedEnabled, autoRefresh, sourceFriends, scan, clear]]
    ];
}

@end




