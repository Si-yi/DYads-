#import "DYYYAutoMessage.h"
#import "DYYYAutoMessageBatch.h"
#import "DYYYAutoMessagePanel.h"
#import "DYYYAutoMessageQuietHoursPanel.h"
#import "DYYYAutoMessageEditor.h"
#import "DYYYIMService.h"
#import "DYYYFriendShareService.h"

#import "AwemeHeaders.h"
#import "DYYYSettingsHelper.h"
#import "DYYYUtils.h"
#include <stdint.h>

static NSString *const kDYYYAutoMessageEnabled = @"DYYYAutoMessageEnabled";
static NSString *const kDYYYAutoMessageConfigs = @"DYYYAutoMessageConfigs";
static NSString *const kDYYYAutoMessageQueryKeyword = @"DYYYAutoMessageIDQueryKeyword";
static NSString *const kDYYYAutoMessageNoSendTime = @"DYYYAutoMessageNoSendTime";
static NSString *const kDYYYAutoMessageToast = @"DYYYAutoMessageToastEnabled";
static NSString *const kDYYYAutoMessageAllSentToast = @"DYYYAutoMessageAllSentToastEnabled";

static NSString *const kDYYYFriendShareEnabled = @"DYYYFriendShareFeedEnabled";
static NSString *const kDYYYFriendShareAutoRefresh = @"DYYYFriendShareAutoRefreshEnabled";
static NSString *const kDYYYFriendShareFriends = @"DYYYFriendShareFeedFriends";

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
            NSMutableDictionary *config = [row mutableCopy];
            [config addEntriesFromDictionary:@{
                @"userID" : userID,
                @"name" : [row[@"name"] isKindOfClass:NSString.class] ? row[@"name"] : userID,
                @"ownerID" : [row[@"ownerID"] isKindOfClass:NSString.class] ? row[@"ownerID"] : @"",
                @"message" : [row[@"message"] isKindOfClass:NSString.class] ? row[@"message"] : @"",
                @"enabled" : @([row[@"enabled"] respondsToSelector:@selector(boolValue)] ? [row[@"enabled"] boolValue] : YES)
            }];
            NSInteger mode = [row[@"sendMode"] respondsToSelector:@selector(integerValue)] ? [row[@"sendMode"] integerValue] : 0;
            config[@"sendMode"] = @(MIN(2, MAX(0, mode)));
            config[@"randomText"] = @([row[@"randomText"] respondsToSelector:@selector(boolValue)] && [row[@"randomText"] boolValue]);
            NSMutableArray *images = [NSMutableArray array];
            if ([row[@"imagePaths"] isKindOfClass:NSArray.class]) for (id path in row[@"imagePaths"])
                if ([path isKindOfClass:NSString.class] && [[path stringByStandardizingPath] hasPrefix:[[self imageDirectory] stringByAppendingString:@"/"]]) [images addObject:[path stringByStandardizingPath]];
            config[@"imagePaths"] = images;
            [configs addObject:config];
        }
    }
    return configs;
}

+ (void)saveMessageConfigs:(NSArray *)configs {
    NSArray *previous = [[self defaults] arrayForKey:kDYYYAutoMessageConfigs] ?: @[];
    NSMutableArray *saved = [NSMutableArray array];
    for (NSDictionary *row in configs) {
        NSMutableDictionary *config = [row mutableCopy];
        [saved addObject:config];
    }
    [[self defaults] setObject:saved forKey:kDYYYAutoMessageConfigs];
    // 仅清理原配置引用过且已不再使用的托管图片，不碰图库原文件。
    NSMutableSet *referenced = [NSMutableSet set];
    for (NSDictionary *config in saved) if ([config[@"imagePaths"] isKindOfClass:NSArray.class]) [referenced addObjectsFromArray:config[@"imagePaths"]];
    NSString *prefix = [[self imageDirectory] stringByAppendingString:@"/"];
    for (NSDictionary *config in previous) for (id path in ([config[@"imagePaths"] isKindOfClass:NSArray.class] ? config[@"imagePaths"] : @[])) {
        if ([path isKindOfClass:NSString.class] && [[path stringByStandardizingPath] hasPrefix:prefix] && ![referenced containsObject:path])
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}

+ (NSUInteger)updateText:(NSString *)text randomText:(BOOL)randomText userIDs:(NSSet<NSString *> *)userIDs ownerID:(NSString *)ownerID {
    if (!NSThread.isMainThread || !ownerID.length || ![ownerID isEqual:[DYYYIMService accountID]] || !userIDs.count ||
        ![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) return NSNotFound;
    // 保存时重新读取，避免把已删除的配置加回来或覆盖其他好友在此期间的修改。
    NSArray *configs = [self messageConfigs];
    NSUInteger count = 0;
    for (NSDictionary *row in configs) if ([row[@"ownerID"] isEqual:ownerID] && [userIDs containsObject:row[@"userID"]]) count++;
    if (count) [self saveMessageConfigs:[DYYYAutoMessageBatch configsByUpdatingText:text randomText:randomText configs:configs ownerID:ownerID selectedUserIDs:userIDs]];
    return count;
}

+ (NSString *)todayKey {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:[NSDate date]];
}

#pragma mark - 配置解析与文字模板

+ (NSString *)imageDirectory {
    NSString *base = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [base stringByAppendingPathComponent:@"DYYY/AutoMessageImages"];
}

+ (void)resolveRecipient:(NSString *)input completion:(void (^)(NSDictionary *, NSString *))completion {
    NSString *account = [DYYYIMService accountID];
    NSString *query = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!account.length) { completion(nil, @"登录账户尚未就绪"); return; }
    if ([query containsString:@":"]) {
        NSArray *parts = [query componentsSeparatedByString:@":"];
        BOOL full = parts.count == 4 && [parts[0] isEqual:@"0"] && [parts[1] isEqual:@"1"];
        if (!(full || parts.count == 2)) { completion(nil, @"目前仅支持一对一会话，群聊尚未适配"); return; }
        NSArray *users = full ? [parts subarrayWithRange:NSMakeRange(2, 2)] : parts;
        if (![users containsObject:account]) { completion(nil, @"会话 ID 不属于当前登录账户"); return; }
        query = [users[0] isEqual:account] ? users[1] : users[0];
    }
    if ([query hasPrefix:@"@"]) query = [query substringFromIndex:1];
    if ([query isEqual:account] || !query.length) { completion(nil, @"请选择其他好友"); return; }
    BOOL numeric = [query rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
    if (numeric && query.longLongValue > 0 && query.length <= 19) {
        // 已有配置按 UID 保存，不为每次保存和测试重读整个联系人数据库。
        NSArray *cached = [[self defaults] arrayForKey:[@"DYYYMutualFriendsCache." stringByAppendingString:account]] ?: @[];
        NSMutableArray *displayMatches = [NSMutableArray array];
        for (NSDictionary *row in cached) {
            if ([row[@"userID"] isEqual:query]) { completion(row, nil); return; }
            if ([row[@"displayID"] isEqual:query]) [displayMatches addObject:row];
        }
        if (displayMatches.count > 1) { completion(nil, @"存在重复抖音号，请填写完整用户 ID"); return; }
        completion(displayMatches.firstObject ?: @{@"userID":query, @"name":query}, nil);
        return;
    }
    [self loadMutualFriends:^(NSArray<NSDictionary *> *friends) {
        if (![account isEqual:[DYYYIMService accountID]]) { completion(nil, @"登录账户已变化，请重试"); return; }
        NSMutableArray *matches = [NSMutableArray array];
        for (NSDictionary *friend in friends) {
            if ([friend[@"userID"] isEqual:query]) { completion(friend, nil); return; }
            BOOL aliasMatch = NO;
            if ([friend[@"aliases"] isKindOfClass:NSArray.class]) for (id alias in friend[@"aliases"])
                if ([alias isKindOfClass:NSString.class] && [alias caseInsensitiveCompare:query] == NSOrderedSame) { aliasMatch = YES; break; }
            if ([friend[@"name"] caseInsensitiveCompare:query] == NSOrderedSame || [friend[@"displayID"] caseInsensitiveCompare:query] == NSOrderedSame || aliasMatch)
                [matches addObject:friend];
        }
        if (matches.count == 1) { completion(matches.firstObject, nil); return; }
        if (matches.count > 1) { completion(nil, @"存在同名好友，请使用完整用户 ID"); return; }
        BOOL digits = [query rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
        if (digits && query.longLongValue > 0 && query.length <= 19) { completion(@{@"userID":query, @"name":query}, nil); return; }
        completion(nil, @"未找到匹配的本地好友，请选择互关好友或填写完整用户 ID");
    }];
}

+ (NSString *)progressKey:(NSDictionary *)config {
    return [NSString stringWithFormat:@"DYYYAutoMessageProgress.%@.%@", config[@"ownerID"] ?: @"", config[@"userID"] ?: @""];
}

+ (NSArray<NSString *> *)randomEntries:(NSString *)text {
    NSMutableArray *entries = [NSMutableArray array];
    NSMutableString *current = nil;
    NSRegularExpression *numbered = [NSRegularExpression regularExpressionWithPattern:@"^\\s*[0-9]+[.、．]\\s*" options:0 error:nil];
    NSArray *lines = [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    BOOL grouped = NO;
    for (NSString *line in lines) if ([numbered firstMatchInString:line options:0 range:NSMakeRange(0, line.length)]) { grouped = YES; break; }
    for (NSString *line in lines) {
        NSTextCheckingResult *match = [numbered firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!grouped) {
            NSString *entry = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (entry.length) [entries addObject:entry];
        } else if (match) {
            if (current.length) [entries addObject:[current copy]];
            current = [[line substringFromIndex:NSMaxRange(match.range)] mutableCopy];
        } else if (current) {
            [current appendFormat:@"\n%@", line];
        } else if ([line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) {
            current = [line mutableCopy];
        }
    }
    if (current.length) [entries addObject:[current copy]];
    return entries;
}

+ (NSString *)renderMessageForConfig:(NSDictionary *)config {
    NSDate *now = NSDate.date;
    NSString *text = [config[@"message"] isKindOfClass:NSString.class] ? config[@"message"] : @"";
    if ([config[@"randomText"] boolValue]) {
        NSArray *entries = [self randomEntries:text];
        if (!entries.count) return @"";
        // 稳定的逐日散列：同一账户、好友、日期和文本在重启后仍选同一条。
        NSData *seed = [[NSString stringWithFormat:@"%@/%@/%@/%@", config[@"ownerID"], config[@"userID"], [self todayKey], text] dataUsingEncoding:NSUTF8StringEncoding];
        uint32_t hash = 2166136261u;
        const unsigned char *bytes = seed.bytes;
        for (NSUInteger i = 0; i < seed.length; i++) hash = (hash ^ bytes[i]) * 16777619u;
        text = entries[hash % entries.count];
    }
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:now];
    NSDictionary *progress = [[self defaults] dictionaryForKey:[self progressKey:config]] ?: @{};
    NSUInteger count = [progress[@"count"] unsignedIntegerValue];
    // 当天测试已成功后预览仍显示同一次发送的序号。
    NSUInteger sequence = count + ([progress[@"date"] isEqual:[self todayKey]] ? 0 : 1);
    NSTimeInterval created = [config[@"createdAt"] respondsToSelector:@selector(doubleValue)] ? [config[@"createdAt"] doubleValue] : 0;
    NSDate *start = created > 0 ? [NSDate dateWithTimeIntervalSince1970:created] : now;
    NSInteger days = MAX(1, [calendar components:NSCalendarUnitDay fromDate:[calendar startOfDayForDate:start] toDate:[calendar startOfDayForDate:now] options:0].day + 1);
    NSDateFormatter *format = [NSDateFormatter new];
    format.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    format.dateFormat = @"yyyy-MM-dd";
    NSString *date = [format stringFromDate:now];
    format.dateFormat = @"EEEE";
    NSDictionary *tokens = @{
        @"n":[NSString stringWithFormat:@"%lu", (unsigned long)sequence], @"d":@(days).stringValue,
        @"remark":config[@"name"] ?: @"", @"备注":config[@"name"] ?: @"", @"date":date, @"日期":date,
        @"weekday":[format stringFromDate:now], @"星期":[format stringFromDate:now],
        @"year":@(components.year).stringValue, @"年":@(components.year).stringValue,
        @"month":@(components.month).stringValue, @"月":@(components.month).stringValue,
        @"day":@(components.day).stringValue, @"日":@(components.day).stringValue,
        @"hour":@(components.hour).stringValue, @"时":@(components.hour).stringValue,
        @"minute":@(components.minute).stringValue, @"分":@(components.minute).stringValue,
        @"second":@(components.second).stringValue, @"秒":@(components.second).stringValue, @"换行":@"\n"
    };
    // 单遍替换，不把备注中碰巧存在的花括号当成新模板执行。
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"\\{([^{}\\n]{1,100})\\}" options:0 error:nil];
    NSArray *matches = [pattern matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    NSMutableString *result = [text mutableCopy];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSString *key = [text substringWithRange:[match rangeAtIndex:1]];
        NSString *value = tokens[key];
        if ([key hasPrefix:@"datetime:"]) {
            format.dateFormat = [key substringFromIndex:9];
            value = [format stringFromDate:now];
        }
        if (value) [result replaceCharactersInRange:match.range withString:value];
    }
    return result;
}

+ (void)sendConfig:(NSDictionary *)config completion:(void (^)(BOOL, NSString *))completion {
    [self sendConfig:config manualTest:NO completion:completion];
}

+ (void)sendConfig:(NSDictionary *)config manualTest:(BOOL)manualTest completion:(void (^)(BOOL, NSString *))completion {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self sendConfig:config manualTest:manualTest completion:completion]; }); return; }
    NSString *account = [DYYYIMService accountID];
    if (!account.length || ![config[@"ownerID"] isEqual:account]) { if (completion) completion(NO, @"配置不属于当前登录账户"); return; }
    if ([config[@"sendMode"] integerValue] != 0) {
        if (completion) completion(NO, @"原生图片上传尚未适配，本次未发送");
        return;
    }
    NSString *message = [self renderMessageForConfig:config];
    if (!message.length) { if (completion) completion(NO, @"没有可发送的文字内容"); return; }
    [DYYYIMService sendText:message toUserID:config[@"userID"] manualTest:manualTest completion:^(BOOL success, NSString *reason) {
        if (success && !manualTest) {
            NSString *key = [self progressKey:config];
            NSDictionary *previous = [[self defaults] dictionaryForKey:key] ?: @{};
            if (![previous[@"date"] isEqual:[self todayKey]]) [[self defaults] setObject:@{@"count":@([previous[@"count"] unsignedIntegerValue] + 1), @"date":[self todayKey]} forKey:key];
        }
        if (completion) completion(success, reason);
    }];
}

#pragma mark - 不发送时间段

+ (NSNumber *)noSendHour:(id)value {
    if ([value isKindOfClass:NSNumber.class]) {
        NSInteger hour = [value integerValue];
        return hour >= 0 && hour <= 23 && [value doubleValue] == hour ? @(hour) : nil;
    }
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray *time = [text componentsSeparatedByString:@":"];
    if (time.count == 2 && [time[1] isEqualToString:@"00"]) text = time[0];
    else if (time.count != 1) return nil;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    if (!text.length || text.length > 2 || [text rangeOfCharacterFromSet:invalid].location != NSNotFound) return nil;
    NSInteger hour = text.integerValue;
    return hour <= 23 ? @(hour) : nil;
}
+ (NSMutableArray<NSMutableDictionary *> *)normalizedNoSendTimePeriods:(id)value {
    NSMutableArray *periods = [NSMutableArray array];
    NSArray *rows = [value isKindOfClass:NSArray.class] ? value : @[];
    if ([value isKindOfClass:NSString.class]) {
        NSArray *parts = [value componentsSeparatedByString:@"-"];
        if (parts.count == 2) rows = @[@{ @"startHour": parts[0], @"endHour": parts[1], @"enabled": @YES }];
    }
    for (id row in rows) {
        if (![row isKindOfClass:NSDictionary.class]) continue;
        NSNumber *start = [self noSendHour:row[@"startHour"]];
        NSNumber *end = [self noSendHour:row[@"endHour"]];
        if (!start || !end || [start isEqual:end]) continue;
        BOOL enabled = [row[@"enabled"] respondsToSelector:@selector(boolValue)] ? [row[@"enabled"] boolValue] : YES;
        NSString *identifier = [row[@"id"] isKindOfClass:NSString.class] && [row[@"id"] length] ? row[@"id"] : NSUUID.UUID.UUIDString;
        [periods addObject:[@{ @"id": identifier, @"startHour": start, @"endHour": end, @"enabled": @(enabled) } mutableCopy]];
    }
    return periods;
}
+ (NSMutableArray<NSMutableDictionary *> *)noSendTimePeriods {
    NSUserDefaults *defaults = [self defaults];
    @synchronized (defaults) {
        id stored = [defaults objectForKey:kDYYYAutoMessageNoSendTime];
        NSMutableArray *periods = [self normalizedNoSendTimePeriods:stored];
        // 沿用原偏好键，将旧版单个字符串无损迁移为已启用的一段；空数组表示用户已清空。
        if (stored && ![stored isEqual:periods]) [defaults setObject:periods forKey:kDYYYAutoMessageNoSendTime];
        return periods;
    }
}
+ (void)saveNoSendTimePeriods:(NSArray *)periods {
    NSUserDefaults *defaults = [self defaults];
    @synchronized (defaults) {
        [defaults setObject:[self normalizedNoSendTimePeriods:periods] forKey:kDYYYAutoMessageNoSendTime];
    }
}
+ (NSString *)noSendTimeSummary {
    NSArray *periods = [self noSendTimePeriods];
    if (!periods.count) return @"未设置";
    NSMutableArray *enabled = [NSMutableArray array];
    for (NSDictionary *period in periods) if ([period[@"enabled"] boolValue]) [enabled addObject:period];
    if (periods.count == 1 && enabled.count == 1) {
        NSDictionary *period = enabled.firstObject;
        return [NSString stringWithFormat:@"%02ld:00 - %02ld:00", (long)[period[@"startHour"] integerValue], (long)[period[@"endHour"] integerValue]];
    }
    return enabled.count ? [NSString stringWithFormat:@"已启用 %lu 个时段", (unsigned long)enabled.count] : @"均已关闭";
}
+ (BOOL)isNoSendTime {
    NSInteger hour = [NSCalendar.currentCalendar component:NSCalendarUnitHour fromDate:NSDate.date];
    for (NSDictionary *period in [self noSendTimePeriods]) {
        if (![period[@"enabled"] boolValue]) continue;
        NSInteger start = [period[@"startHour"] integerValue], end = [period[@"endHour"] integerValue];
        if (start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)) return YES;
    }
    return NO;
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
    [self sendConfig:config completion:^(BOOL success, NSString *reason) {
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
    NSString *account = [DYYYIMService accountID];
    static NSString *lastAccount;
    static NSTimeInterval lastCheck;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if ([lastAccount isEqual:account] && now - lastCheck < 60) return;
    lastAccount = account;
    lastCheck = now;
    processing = YES;
    NSMutableArray *configs = [NSMutableArray array];
    for (NSDictionary *config in [self messageConfigs]) if ([config[@"ownerID"] isEqual:account]) [configs addObject:config];
    [self processDailyConfigs:configs completion:^{ processing = NO; }];
}

+ (void)scanFriendSharesWithToast:(BOOL)showToast {
    [DYYYFriendShareService scanWithToast:showToast];
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

// 昵称与备注均只接收非空文本，跳过空白、NSNull 及未适配的字段类型。
+ (NSString *)friendTextInSources:(NSArray *)sources keys:(NSArray<NSString *> *)keys {
    for (id source in sources) for (NSString *key in keys) {
        id value = [self friendValue:source keys:@[key]];
        if (![value isKindOfClass:NSString.class]) continue;
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length) return text;
    }
    return nil;
}

+ (NSString *)avatarURL:(id)value depth:(NSUInteger)depth {
    if (!value || depth > 5) return nil;
    if ([value isKindOfClass:NSURL.class]) value = [value absoluteString];
    if ([value isKindOfClass:NSString.class]) {
        NSString *text = [value hasPrefix:@"//"] ? [@"https:" stringByAppendingString:value] : value;
        NSString *scheme = [NSURL URLWithString:text].scheme.lowercaseString;
        return ([scheme isEqual:@"https"] || [scheme isEqual:@"http"]) ? text : nil;
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id item in value) { NSString *url = [self avatarURL:item depth:depth + 1]; if (url.length) return url; }
        return nil;
    }
    for (NSString *key in @[@"urlList", @"url_list", @"originURLList", @"originURL", @"originUrl", @"URL", @"url", @"absoluteString"]) {
        NSString *url = [self avatarURL:[self friendValue:value keys:@[key]] depth:depth + 1];
        if (url.length) return url;
    }
    return nil;
}

+ (NSArray<NSDictionary *> *)normalizedFriends:(id)rows requireMutual:(BOOL)requireMutual {
    if ([rows isKindOfClass:NSDictionary.class]) rows = [self friendValue:rows keys:@[@"friends", @"users", @"userList", @"data"]];
    if (![rows isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *friends = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    // 已在当前账户中加载的原生用户可补足数据库中没有的备注/头像，不发逐人网络请求。
    Class userManagerClass = NSClassFromString(@"AWEIMUserManager");
    AWEIMUserManager *userManager = [userManagerClass respondsToSelector:@selector(sharedManager)] ? [(id)userManagerClass sharedManager] : nil;
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
        id cachedUser = nil;
        @try {
            if ([userManager respondsToSelector:@selector(localCachedUserForUserID:)]) cachedUser = [userManager localCachedUserForUserID:uid];
        } @catch (__unused NSException *exception) {}
        NSArray *nameSources = cachedUser ? @[model, row, cachedUser] : @[model, row];
        NSString *nickname = [self friendTextInSources:nameSources keys:@[@"nickname", @"nickName", @"name", @"displayName", @"display_name"]] ?: uid;
        // 39.5 的 AWEIMUser/AWEUserModel 使用 alias 保存好友备注，不取群昵称。
        NSString *remark = [self friendTextInSources:nameSources keys:@[@"alias"]] ?:
            [self friendTextInSources:nameSources keys:@[@"remarkName", @"remark", @"remark_name"]];
        NSString *name = remark ?: nickname;
        id displayValue = [self friendValue:model keys:@[@"displayID", @"uniqueID", @"uniqueId", @"shortID", @"shortId", @"short_id", @"username"]];
        NSString *display = [displayValue isKindOfClass:NSString.class] ? displayValue : uid;
        id flameInfo = [self friendValue:row keys:@[@"streakInfo", @"flameInfo"]];
        id daysValue = [self friendValue:row keys:@[@"flameDays", @"streakDays", @"streakCount"]] ?:
            [self friendValue:flameInfo keys:@[@"days", @"streakDays", @"streakCount"]];
        NSInteger days = [daysValue respondsToSelector:@selector(integerValue)] ? [daysValue integerValue] : 0;
        id hasFlame = [self friendValue:row keys:@[@"hasFlame", @"isFlameFriend"]];
        NSString *avatar = nil;
        for (id source in @[model, row]) {
            for (NSString *key in @[@"avatarThumb", @"avatarSmall", @"avatarSmallStrURL", @"avatarSmallStrUrl", @"avatarURLSmall", @"avatarURL", @"avatarUrl", @"avatar_thumb", @"avatar", @"avatarMedium", @"avatarStrUrls", @"avatarURLList"]) {
                avatar = [self avatarURL:[self friendValue:source keys:@[key]] depth:0];
                if (avatar.length) break;
            }
            if (avatar.length) break;
        }
        if (!avatar.length) {
            // 联系人数据库可能只存基础字段；复用抖音内存中已加载的完整用户，不发起逐人网络请求。
            for (NSString *key in @[@"avatarThumb", @"avatarURLSmall", @"avatarSmallStrUrl", @"avatarMedium", @"avatarStrUrls", @"avatarURL", @"avatar"]) {
                avatar = [self avatarURL:[self friendValue:cachedUser keys:@[key]] depth:0];
                if (avatar.length) break;
            }
        }
        NSMutableOrderedSet *aliases = [NSMutableOrderedSet orderedSet];
        [aliases addObject:nickname];
        if (remark.length) [aliases addObject:remark];
        for (id source in nameSources) {
            for (NSString *key in @[@"name", @"nickname", @"nickName", @"displayName", @"contactName", @"alias", @"remarkName", @"remark", @"remark_name", @"uniqueID", @"uniqueId"] ) {
                NSString *value = [self friendTextInSources:@[source] keys:@[key]];
                if (value.length) [aliases addObject:value];
            }
            id storedAliases = [self friendValue:source keys:@[@"aliases"]];
            if ([storedAliases isKindOfClass:NSArray.class]) for (id value in storedAliases)
                if ([value isKindOfClass:NSString.class] && [value length]) [aliases addObject:value];
        }
        [friends addObject:@{ @"userID":uid, @"name":name, @"nickname":nickname, @"remarkName":remark ?: @"", @"displayID":display, @"aliases":aliases.array,
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
    if (!friends.count && cacheKey) {
        // 离线缓存也重新应用备注优先规则，保留 UID、火花、头像和原选择。
        friends = [self normalizedFriends:[[self defaults] arrayForKey:cacheKey] ?: @[] requireMutual:NO];
    }
    if (!database) [DYYYUtils showToast:@"联系人服务尚未就绪，请先进入抖音消息页"];
    if (completion) completion(friends);
}


#pragma mark - 设置页面

+ (AWESettingItemModel *)setting:(NSDictionary *)dictionary {
    return [DYYYSettingsHelper createSettingItem:dictionary];
}

// 添加与编辑使用同一个可滚动配置窗口。
+ (void)editConfigFrom:(UIViewController *)root existing:(NSMutableDictionary *)existing completion:(void (^)(void))completion {
    [DYYYAutoMessageEditor showFrom:root config:existing completion:completion];
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
    AWESettingItemModel *noSend = [[NSClassFromString(@"AWESettingItemModel") alloc] init];
    noSend.identifier = kDYYYAutoMessageNoSendTime;
    noSend.title = @"不发送时间段";
    noSend.detail = [self noSendTimeSummary];
    noSend.type = 0; noSend.cellType = 26; noSend.colorStyle = 0; noSend.isEnable = YES;
    noSend.svgIconImageName = @"ic_eyeslash_outlined_20";
    __weak AWESettingItemModel *weakNoSend = noSend;
    __weak UIViewController *weakQuietRoot = rootViewController;
    noSend.cellTappedBlock = ^{
        [DYYYAutoMessageQuietHoursPanel showFrom:topView() ?: weakQuietRoot onChange:^{
            weakNoSend.detail = [self noSendTimeSummary];
            [weakNoSend refreshCell];
        }];
    };
    AWESettingItemModel *toast = [self setting:@{ @"identifier" : kDYYYAutoMessageToast, @"title" : @"显示发送提示", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_bell_outlined_20" }];
    AWESettingItemModel *allToast = [self setting:@{ @"identifier" : kDYYYAutoMessageAllSentToast, @"title" : @"显示已全部发送提示", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_bell_outlined_20" }];

    AWESettingItemModel *feedEnabled = [self setting:@{ @"identifier" : kDYYYFriendShareEnabled, @"title" : @"启用好友分享进推荐", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_video_outlined_20" }];
    AWESettingItemModel *autoRefresh = [self setting:@{ @"identifier" : kDYYYFriendShareAutoRefresh, @"title" : @"每次打开抖音刷新", @"subTitle" : @"继续推送未刷分享，并加入新分享", @"detail" : @"", @"cellType" : @6, @"imageName" : @"ic_circlearrowin_outlined_20" }];
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
    clear.cellTappedBlock = ^{ [DYYYFriendShareService clearWatched]; [DYYYUtils showToast:@"已清除当前账户的已刷记录"]; };

    return @[
        [DYYYSettingsHelper createSectionWithTitle:@"自动消息" footerTitle:@"开启后在抖音启动时处理配置；不发送时间段内不会触发。" items:@[enabled, configs, status, keyword, noSend, toast, allToast]],
        [DYYYSettingsHelper createSectionWithTitle:@"好友分享进推荐" footerTitle:@"未刷分享会保存到下次打开；刷视频途中收到的新分享接在当前视频后，刷完后继续原推荐。手动划走或播完一轮记为已刷，搜索或退出保留未刷记录。" items:@[feedEnabled, autoRefresh, sourceFriends, scan, clear]]
    ];
}

@end






