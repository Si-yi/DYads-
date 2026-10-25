#import "DYYYIMService.h"
#import "AwemeHeaders.h"
#import "DYYYIMHistoryReader.h"
#import "DYYYIMShareParser.h"

@interface DYYYIMService ()
@property (nonatomic, strong) NSMapTable *services;
@property (nonatomic, strong) NSMutableDictionary *pending;
@property (nonatomic, strong) NSMutableDictionary *textTypes;
@property (nonatomic, strong) NSMapTable *historyArguments;
@property (nonatomic, copy) NSDictionary *lastValidation;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSHashTable *> *instances;
@property (nonatomic) NSTimeInterval lastRegistryLookup;
@property (nonatomic, copy) NSString *lastFailure;
@property (nonatomic, strong) NSMutableDictionary *scanState;
@property (nonatomic) NSUInteger historyResultCount;
@end

@implementation DYYYIMService

#pragma mark - 本地未读分享

// 文字类型识别与分享扫描共用结果解包，支持原生按会话分组的返回值。
+ (NSArray *)messageArray:(id)value {
    return [DYYYIMHistoryReader messageArray:value];
}

+ (dispatch_queue_t)historyQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.dyyy.im-history", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

+ (void)unreadSharesForUsers:(NSArray<NSString *> *)userIDs revalidatingRows:(NSArray<NSDictionary *> *)legacyRows
                 completion:(void (^)(NSArray<NSDictionary *> *, NSArray<NSDictionary *> *, NSString *))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self unreadSharesForUsers:userIDs revalidatingRows:legacyRows completion:completion]; });
        return;
    }
    if (!completion) return;
    NSMutableDictionary *state = [@{ @"selectedUserCount": @(userIDs.count), @"stage": @"initializing" } mutableCopy];
    [self shared].scanState = state;
    if (!userIDs.count) { completion(@[], @[], nil); return; }
    NSString *account = [self accountID];
    id sender = [[self shared].services objectForKey:@"sender"];
    TIMXOConversationManager *manager = [self serviceForRole:@"conversations" root:[self value:sender key:@"sdkRoot"]];
    id root = [self value:manager key:@"r"];
    TIMXOMessageManager *messages = [self serviceForRole:@"messages" root:root];
    if (!account.length || !manager || !messages || !root || [self value:messages key:@"r"] != root) {
        state[@"stage"] = @"services_not_ready";
        completion(@[], @[], @"本地消息服务尚未就绪，请先打开消息页再返回扫描");
        return;
    }
    Class convClass = NSClassFromString(@"TIMXOConversation");
    if (![convClass respondsToSelector:@selector(instanceWithRootObject:identifier:)]) {
        state[@"stage"] = @"conversation_api_unavailable";
        completion(@[], @[], @"当前版本的会话读取入口不可用");
        return;
    }
    NSString *historyKind = [[[self shared].historyArguments objectForKey:messages] copy];
    state[@"historyKind"] = historyKind ?: @"recent_with_identifier_fallback";
    NSMutableArray *requests = [NSMutableArray array];
    __block NSUInteger failed = 0;
    // 在主线程校验账户及会话，后台只执行原生只读查询和消息解析。
    for (NSString *peer in userIDs) {
        if (![peer isKindOfClass:NSString.class] || peer.longLongValue <= 0 || [peer isEqual:account]) continue;
        @try {
            NSString *cid = [manager conversationIDFor1to1ChatWithOtherUserID:peer.longLongValue inbox:0];
            if (!cid.length || ![manager conversationExitsInDB:cid]) continue;
            TIMXOConversation *conv = [(id)convClass instanceWithRootObject:root identifier:cid];
            if (![self validateConversation:conv manager:manager account:account peer:peer identifier:cid]) { failed++; continue; }
            BOOL revalidate = NO;
            for (NSDictionary *row in legacyRows)
                if ([row[@"friendID"] isEqual:peer] && ![DYYYIMShareParser isCurrentReceipt:row]) { revalidate = YES; break; }
            if (!conv.unreadCount && !revalidate) continue;
            id latest = conv.lastMessage;
            if (!latest) { failed++; continue; }
            [requests addObject:[@{ @"peer": peer, @"cid": cid, @"conversation": conv, @"latest": latest,
                @"unread": @(conv.unreadCount), @"boundary": conv.firstUnreadMessageID ?: @"" } mutableCopy]];
        } @catch (__unused NSException *exception) { failed++; }
    }
    state[@"stage"] = @"reading_recent";
    NSUInteger unreadConversations = 0;
    for (NSDictionary *request in requests) if ([request[@"unread"] unsignedIntegerValue]) unreadConversations++;
    state[@"unreadConversationCount"] = @(unreadConversations);
    state[@"queriedConversationCount"] = @(requests.count);
    // 39.5 会话常有 unreadCount 却没有 firstUnreadMessageID；使用 SDK 的只读未读查询。
    // 不阻塞主线程/SDK 回调队列；每个请求只结算一次，超时后仍尝试有凭据的边界路径。
    dispatch_group_t unreadGroup = dispatch_group_create();
    for (NSMutableDictionary *request in requests) {
        if (![request[@"unread"] unsignedIntegerValue]) continue;
        if (![messages respondsToSelector:@selector(asyncGetUnreadMessagesFromSender:inConversation:limit:completion:)]) {
            request[@"nativeUnreadQueryStatus"] = @"unavailable"; continue;
        }
        dispatch_group_enter(unreadGroup);
        __block BOOL finished = NO; // 只在主队列访问，包括来自 SDK 的回调。
        void (^finish)(id, NSString *) = ^(id result, NSString *status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (finished) return;
                finished = YES;
                if (result) request[@"nativeUnreadResult"] = result;
                request[@"nativeUnreadQueryStatus"] = status;
                dispatch_group_leave(unreadGroup);
            });
        };
        @try {
            // 只读取回调的消息结果，不依赖附加回调参数或修改聊天已读状态。
            [messages asyncGetUnreadMessagesFromSender:[request[@"peer"] longLongValue] inConversation:request[@"cid"]
                limit:MIN([request[@"unread"] unsignedIntegerValue], 2000) completion:^(id result) { finish(result, @"returned"); }];
        } @catch (__unused NSException *exception) { finish(nil, @"exception"); }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ finish(nil, @"timeout"); });
    }
    dispatch_group_notify(unreadGroup, [self historyQueue], ^{
        NSMutableArray *rows = [NSMutableArray array], *rejectedRows = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        NSMutableArray *queries = [NSMutableArray array];
        for (NSDictionary *request in requests) {
            @autoreleasepool {
                NSMutableDictionary *diagnostics = [NSMutableDictionary dictionary];
                [queries addObject:diagnostics];
                NSString *cid = request[@"cid"], *peer = request[@"peer"];
                @try {
                    id observed = nil;
                    if (historyKind.length && [messages respondsToSelector:@selector(messagesInConversation:excludeMessageTypes:limit:)]) {
                        // 仅使用已经观察到的参数类型，不能根据 id 声明猜会话对象/字符串。
                        id argument = [historyKind isEqual:@"identifier"] ? (id)cid : request[@"conversation"];
                        @try { observed = [messages messagesInConversation:argument excludeMessageTypes:@[] limit:2000]; }
                        @catch (__unused NSException *exception) { diagnostics[@"observedQueryFailed"] = @YES; }
                    }
                    id (^recentQuery)(NSTimeInterval, NSUInteger) = nil;
                    if ([messages respondsToSelector:@selector(messagesBeforeTime:inTypes:limit:)]) {
                        recentQuery = ^id(NSTimeInterval before, NSUInteger limit) {
                            return [messages messagesBeforeTime:before inTypes:nil limit:limit];
                        };
                    }
                    id (^earliestQuery)(NSUInteger) = nil;
                    if ([messages respondsToSelector:@selector(earliestMessagesInConversationWithIdentifier:limit:)]) {
                        earliestQuery = ^id(NSUInteger limit) {
                            return [messages earliestMessagesInConversationWithIdentifier:cid limit:(long long)limit];
                        };
                    }
                    NSArray *history = [DYYYIMHistoryReader historyForConversation:cid latestMessage:request[@"latest"] firstUnreadID:request[@"boundary"]
                        observedResult:observed recentQuery:recentQuery earliestQuery:earliestQuery diagnostics:diagnostics];
                    diagnostics[@"messageCount"] = @(history.count);
                    NSUInteger unreadCount = [request[@"unread"] unsignedIntegerValue];
                    diagnostics[@"nativeUnreadCount"] = @(unreadCount);
                    diagnostics[@"nativeUnreadQueryStatus"] = request[@"nativeUnreadQueryStatus"] ?: @"not_needed";
                    NSArray *incoming = nil;
                    if (unreadCount && request[@"nativeUnreadResult"])
                        incoming = [DYYYIMHistoryReader nativeUnreadIncomingMessages:request[@"nativeUnreadResult"]
                            conversation:cid peerID:peer.longLongValue unreadCount:unreadCount diagnostics:diagnostics];
                    if (!incoming) {
                        incoming = [DYYYIMHistoryReader unreadIncomingMessages:history peerID:peer.longLongValue
                            unreadCount:unreadCount firstUnreadID:request[@"boundary"] diagnostics:diagnostics];
                        if (unreadCount && ![diagnostics[@"unreadSelection"] isEqual:@"verified_boundary"]) failed++;
                    }
                    // 专用未读查询不要求结果包含末条（末条可能是自己发出或系统消息）。
                    // 历史不可读时仍交付已验证的未读，但不拿残缺历史撤销旧来源。
                    if (!history && !unreadCount) failed++;
                    diagnostics[@"incomingCount"] = @(incoming.count);
                    NSMutableArray *kinds = [NSMutableArray array];
                    for (TIMXOMessage *message in incoming) {
                        NSArray *ids = [DYYYIMShareParser directItemIDsForMessage:message peerID:peer accountID:account];
                        if (kinds.count < 16) [kinds addObject:[DYYYIMShareParser diagnosticsForMessage:message peerID:peer accountID:account]];
                        for (NSString *itemID in ids) {
                            if ([seen containsObject:itemID]) continue;
                            NSDictionary *receipt = [DYYYIMShareParser receiptForUnreadMessage:message peerID:peer itemID:itemID];
                            if (!receipt) continue;
                            [seen addObject:itemID];
                            [rows addObject:receipt];
                        }
                    }
                    diagnostics[@"incomingMessageKinds"] = kinds;
                    NSDictionary *reconciliation = [DYYYIMShareParser reconcileRows:legacyRows history:history unreadMessages:incoming peerID:peer accountID:account];
                    [rows addObjectsFromArray:reconciliation[@"verifiedRows"]];
                    [rejectedRows addObjectsFromArray:reconciliation[@"rejectedRows"]];
                    diagnostics[@"verifiedLegacyCount"] = @([reconciliation[@"verifiedRows"] count]);
                    diagnostics[@"rejectedLegacyCount"] = @([reconciliation[@"rejectedRows"] count]);
                } @catch (__unused NSException *exception) { diagnostics[@"query"] = @"query_exception"; failed++; }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // 读取途中切换账户时整批丢弃，不向新账户插入上一账户的分享。
            if (![[self accountID] isEqual:account]) {
                state[@"stage"] = @"account_changed";
                completion(@[], @[], @"扫描时登录账户已变化，请重新扫描");
                return;
            }
            state[@"queries"] = queries;
            state[@"failedConversationCount"] = @(failed);
            state[@"sharedVideoCount"] = @([NSSet setWithArray:[rows valueForKey:@"itemID"]].count);
            state[@"rejectedLegacyCount"] = @(rejectedRows.count);
            state[@"stage"] = failed ? @"partial" : @"complete";
            NSString *warning = failed ? (rows.count ? @"部分好友近期消息暂不可读，已继续加载其余好友的分享" : @"好友近期消息暂不可读，请导出本次调试记录") : nil;
            completion(rows, rejectedRows, warning);
        });
    });
}

+ (instancetype)shared {
    static DYYYIMService *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [self new];
        instance.services = [NSMapTable strongToWeakObjectsMapTable];
        instance.instances = [NSMutableDictionary dictionary];
        instance.historyArguments = [NSMapTable weakToStrongObjectsMapTable];
        instance.pending = [NSMutableDictionary dictionary];
        instance.textTypes = [NSMutableDictionary dictionary];
    });
    return instance;
}

+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}

+ (void)captureService:(id)service role:(NSString *)role {
    if (!service) return;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self captureService:service role:role]; });
        return;
    }
    DYYYIMService *s = [self shared];
    [s.services setObject:service forKey:role];
    NSHashTable *instances = s.instances[role];
    if (!instances) { instances = [NSHashTable weakObjectsHashTable]; s.instances[role] = instances; }
    [instances addObject:service];
}

+ (id)serviceForRole:(NSString *)role root:(id)root {
    id last = [[self shared].services objectForKey:role];
    if (!root || [self value:last key:@"r"] == root) return last;
    for (id service in [self shared].instances[role].allObjects)
        if ([self value:service key:@"r"] == root) return service;
    return nil;
}

+ (BOOL)validateConversation:(TIMXOConversation *)conversation manager:(TIMXOConversationManager *)manager
                    account:(NSString *)account peer:(NSString *)peer identifier:(NSString *)cid {
    if (!conversation || ![conversation.identifier isEqual:cid] ||
        [manager otherUserIDFor1to1ChatWithConversationID:cid] != peer.longLongValue) return NO;
    // ownerID 是会话所有者，不能用来判断登录账户。校验一对一会话的双方参与者。
    NSDictionary *participants = conversation.participantsMap;
    if (![participants isKindOfClass:NSDictionary.class]) participants = @{};
    BOOL hasAccount = participants[account] != nil || participants[@(account.longLongValue)] != nil;
    BOOL hasPeer = participants[peer] != nil || participants[@(peer.longLongValue)] != nil;
    NSArray *parts = [cid componentsSeparatedByCharactersInSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet];
    BOOL cidHasBoth = [parts containsObject:account] && [parts containsObject:peer];
    BOOL currentParticipant = conversation.isCurrentUserAParticipant;
    [self shared].lastValidation = @{@"accountInParticipants":@(hasAccount), @"peerInParticipants":@(hasPeer),
        @"identifierHasBothUsers":@(cidHasBoth), @"currentUserParticipates":@(currentParticipant)};
    if (hasAccount && hasPeer) return YES;
    // 部分本地会话尚未展开参与者表；仅接受 ID 明确包含双方且原生确认当前用户在会话内的情况。
    return currentParticipant && cidHasBoth;
}

+ (NSDictionary *)diagnostics {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *role in @[@"contacts", @"conversations", @"messages", @"sender"]) {
        result[role] = @([self shared].instances[role].allObjects.count);
    }
    result[@"observedHistoryManagers"] = @([self shared].historyArguments.count);
    result[@"lastValidation"] = [self shared].lastValidation ?: @{};
    result[@"lastFailure"] = [self shared].lastFailure ?: @"";
    result[@"knownTextFormats"] = @([self shared].textTypes.count);
    result[@"lastHistoryResultCount"] = @([self shared].historyResultCount);
    result[@"lastScan"] = [[self shared].scanState copy] ?: @{};
    return result;
}

+ (id)contactDatabase {
    id cached = [[self shared].services objectForKey:@"contacts"];
    if ([cached respondsToSelector:@selector(currentDataBaseUid)] &&
        [cached respondsToSelector:@selector(fetchFriendUsersWithLimits:readScene:)]) return cached;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now - [self shared].lastRegistryLookup < 2) return cached;
    [self shared].lastRegistryLookup = now;
    // 使用抖音自己的服务容器获取已配置的联系人数据库，而不是构造新实例。
    Class centerClass = NSClassFromString(@"HTSServiceCenter");
    Class databaseClass = NSClassFromString(@"AWEIMUserDBManager");
    if (databaseClass && [centerClass respondsToSelector:@selector(defaultCenter)]) {
        @try {
            HTSServiceCenter *center = [(id)centerClass defaultCenter];
            id database = [center getService:databaseClass];
            if ([database respondsToSelector:@selector(currentDataBaseUid)] && [database respondsToSelector:@selector(fetchFriendUsersWithLimits:readScene:)]) {
                [self captureService:database role:@"contacts"];
                return database;
            }
        } @catch (__unused NSException *exception) {}
    }
    Class cls = NSClassFromString(@"AWEIMContactDataManager");
    if ([cls respondsToSelector:@selector(sharedInstance)]) {
        AWEIMContactDataManager *contacts = [(id)cls sharedInstance];
        id database = [contacts respondsToSelector:@selector(userManager)] ? [contacts userManager] : nil;
        if (database) { [self captureService:database role:@"contacts"]; return database; }
    }
    return [[self shared].services objectForKey:@"contacts"];
}

+ (NSString *)accountID {
    id database = [self contactDatabase];
    id uid = [database respondsToSelector:@selector(currentDataBaseUid)] ? [(AWEIMUserDBManager *)database currentDataBaseUid] : nil;
    if ([uid isKindOfClass:NSNumber.class]) uid = [uid stringValue];
    return [uid isKindOfClass:NSString.class] ? uid : @"";
}

+ (NSString *)stateKey:(NSString *)userID {
    NSString *account = [self accountID];
    if (!account.length || !userID.length) return nil;
    NSDateFormatter *format = [NSDateFormatter new];
    format.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    format.dateFormat = @"yyyy-MM-dd";
    return [NSString stringWithFormat:@"%@/%@/%@", account, [format stringFromDate:NSDate.date], userID];
}

+ (NSString *)dailyStateForUserID:(NSString *)userID {
    NSString *key = [self stateKey:userID];
    return key ? [NSUserDefaults.standardUserDefaults dictionaryForKey:@"DYYYIMDailySendState"][key] : nil;
}

+ (void)setState:(NSString *)state key:(NSString *)key {
    if (!key.length) return;
    NSMutableDictionary *states = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"DYYYIMDailySendState"] mutableCopy] ?: [NSMutableDictionary dictionary];
    // 保留当天各账户状态，切换账户再切回来也不能重新发送。
    NSArray *parts = [key componentsSeparatedByString:@"/"];
    NSDateFormatter *format = [NSDateFormatter new];
    format.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    format.dateFormat = @"yyyy-MM-dd";
    if (parts.count != 3 || ![parts[1] isEqual:[format stringFromDate:NSDate.date]]) return;
    for (NSString *old in states.allKeys) {
        NSArray *oldParts = [old componentsSeparatedByString:@"/"];
        if (oldParts.count != 3 || ![oldParts[1] isEqual:parts[1]]) [states removeObjectForKey:old];
    }
    if (state) states[key] = state; else [states removeObjectForKey:key];
    [NSUserDefaults.standardUserDefaults setObject:states forKey:@"DYYYIMDailySendState"];
}

+ (NSString *)textTypeCacheKey {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return [NSString stringWithFormat:@"DYYYIMTextType.%@.%@", info[@"CFBundleShortVersionString"] ?: @"", info[@"CFBundleVersion"] ?: @""];
}

+ (NSNumber *)textTypeForBody:(id)body number:(id)number {
    if (![body isKindOfClass:NSDictionary.class] || ![body[@"text"] isKindOfClass:NSString.class] ||
        ![number isKindOfClass:NSNumber.class] || [number longLongValue] <= 0) return nil;
    // 分享卡片、图片消息也可能带 text 字段，不能拿它们的类型当作普通文字。
    for (id key in body) if ([key isKindOfClass:NSString.class]) {
        NSString *lower = [key lowercaseString];
        if ([lower containsString:@"aweme"] || [lower containsString:@"image"] || [lower containsString:@"resource"] ||
            [lower isEqual:@"item_id"] || [lower isEqual:@"itemid"] || [lower containsString:@"video"]) return nil;
    }
    return number;
}

+ (void)rememberTextType:(NSNumber *)type account:(NSString *)account {
    if (!account.length || !type) return;
    [self shared].textTypes[account] = type;
    NSString *key = [self textTypeCacheKey];
    NSMutableDictionary *known = [[NSUserDefaults.standardUserDefaults dictionaryForKey:key] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (![known[account] isEqual:type]) {
        known[account] = type;
        [NSUserDefaults.standardUserDefaults setObject:known forKey:key];
    }
}

+ (NSString *)manualIDsKey:(NSString *)account {
    return [@"DYYYIMManualTestMessageIDs." stringByAppendingString:account ?: @""];
}
+ (void)rememberManualID:(NSString *)identifier account:(NSString *)account {
    if (!identifier.length || !account.length) return;
    NSString *key = [self manualIDsKey:account];
    NSMutableOrderedSet *ids = [NSMutableOrderedSet orderedSetWithArray:[NSUserDefaults.standardUserDefaults arrayForKey:key] ?: @[]];
    [ids addObject:identifier];
    while (ids.count > 500) [ids removeObjectAtIndex:0];
    [NSUserDefaults.standardUserDefaults setObject:ids.array forKey:key];
}

+ (void)observeConversationSend:(id)model conversation:(id)conversation {
    id body = [self value:model key:@"content"] ?: [self value:model key:@"messageContentDict"];
    NSNumber *type = [self textTypeForBody:body number:[self value:model key:@"messageType"]];
    if (!type) return;
    id root = [self value:conversation key:@"r"];
    dispatch_async(dispatch_get_main_queue(), ^{
        id manager = [self serviceForRole:@"conversations" root:root];
        if (!root || [self value:manager key:@"r"] != root) return;
        NSString *account = [self accountID];
        NSString *cid = [self value:conversation key:@"identifier"];
        if (![cid isKindOfClass:NSString.class] || !cid.length) return;
        long long peer = [manager otherUserIDFor1to1ChatWithConversationID:cid];
        NSString *peerID = [NSString stringWithFormat:@"%lld", peer];
        if (account.length && peer > 0 && [self validateConversation:conversation manager:manager account:account peer:peerID identifier:cid])
            [self rememberTextType:type account:account];
    });
}

+ (void)observeTextModel:(id)model sender:(id)sender {
    [self captureService:sender role:@"sender"];
    id content = [self value:model key:@"messageContentDict"];
    NSNumber *type = [self textTypeForBody:content number:[self value:model key:@"messageType"]];
    if (!type) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *account = [self accountID];
        if (account.length) [self rememberTextType:type account:account];
    });
}

+ (void)observeHistoryQuery:(id)conversation manager:(id)manager {
    NSString *kind = nil;
    if ([conversation isKindOfClass:NSString.class]) kind = @"identifier";
    else if ([conversation isKindOfClass:NSClassFromString(@"TIMXOConversation")]) kind = @"conversation";
    if (!kind) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self captureService:manager role:@"messages"];
        [[self shared].historyArguments setObject:kind forKey:manager];
    });
}

+ (void)observeHistoryResults:(id)results manager:(id)manager {
    if (![results isKindOfClass:NSArray.class]) return;
    NSArray *sample = [results subarrayWithRange:NSMakeRange(0, MIN(30, [results count]))];
    NSUInteger count = [results count];
    id root = [self value:manager key:@"r"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self shared].historyResultCount = count;
        NSString *account = [self accountID];
        if (!account.length || !root || [self shared].textTypes[account]) return;
        for (id message in sample) {
            NSString *cid = [self value:message key:@"belongingConversationIdentifier"];
            if (![cid isKindOfClass:NSString.class]) continue;
            NSArray *parts = [cid componentsSeparatedByCharactersInSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet];
            if (![parts containsObject:account]) continue;
            NSNumber *type = [self textTypeForBody:[self value:message key:@"content"] number:[self value:message key:@"messageType"]];
            if (type) { [self rememberTextType:type account:account]; break; }
        }
    });
}

+ (void)finishPending:(NSMutableDictionary *)pending success:(BOOL)success reason:(NSString *)reason confirmed:(BOOL)confirmed {
    if (confirmed && ![pending[@"manualTest"] boolValue]) [self setState:success ? @"sent" : nil key:pending[@"stateKey"]];
    void (^completion)(BOOL, NSString *) = pending[@"completion"];
    [pending removeObjectForKey:@"completion"];
    if (completion) completion(success, reason);
}

+ (void)observeMessage:(id)message conversation:(id)conversation error:(id)error {
    id identifier = [self value:message key:@"identifier"];
    if (![identifier isKindOfClass:NSString.class]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *pending = [self shared].pending[identifier];
        if (!pending) return;
        NSString *cid = [conversation isKindOfClass:NSString.class] ? conversation : [self value:conversation key:@"identifier"];
        if (![cid isEqual:pending[@"conversationID"]]) return;
        [self finishPending:pending success:error == nil reason:error ? @"抖音返回发送失败" : @"抖音已确认发送成功" confirmed:YES];
        [[self shared].pending removeObjectForKey:identifier];
    });
}

+ (void)sendText:(NSString *)text toUserID:(NSString *)userID completion:(void (^)(BOOL, NSString *))completion {
    [self sendText:text toUserID:userID manualTest:NO completion:completion];
}

+ (void)sendText:(NSString *)text toUserID:(NSString *)userID manualTest:(BOOL)manualTest completion:(void (^)(BOOL, NSString *))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self sendText:text toUserID:userID manualTest:manualTest completion:completion]; });
        return;
    }
    void (^fail)(NSString *) = ^(NSString *reason) { [self shared].lastFailure = reason; if (completion) completion(NO, reason); };
    NSString *account = [self accountID];
    if (!account.length || !text.length || !userID.length || userID.longLongValue <= 0) { fail(@"账户、用户 ID 或消息内容未就绪"); return; }
    NSString *stateKey = [self stateKey:userID];
    if (!manualTest && [self dailyStateForUserID:userID].length) { fail(@"该好友今天已有发送或待确认记录，不重复发送"); return; }
    IESIMMessageSender *sender = [[self shared].services objectForKey:@"sender"];
    TIMXOConversationManager *manager = [self serviceForRole:@"conversations" root:[self value:sender key:@"sdkRoot"]];
    if (!manager || !sender || ![manager respondsToSelector:@selector(conversationIDFor1to1ChatWithOtherUserID:inbox:)] || ![sender respondsToSelector:@selector(sendMessage:)]) { fail(@"消息服务尚未初始化，请先打开一次好友聊天"); return; }
    NSString *cid = [manager conversationIDFor1to1ChatWithOtherUserID:userID.longLongValue inbox:0];
    if (![cid isKindOfClass:NSString.class] || !cid.length || ![manager conversationExitsInDB:cid]) { fail(@"没有找到已有会话，请先打开一次该好友聊天"); return; }
    id root = [self value:manager key:@"r"];
    id senderRoot = [self value:sender key:@"sdkRoot"];
    if (!root || root != senderRoot) { fail(@"消息服务账户尚未同步，请重新进入好友聊天"); return; }
    Class convClass = NSClassFromString(@"TIMXOConversation");
    if (![convClass respondsToSelector:@selector(instanceWithRootObject:identifier:)]) { fail(@"当前版本没有可用的会话读取入口"); return; }
    TIMXOConversation *conversation = [(id)convClass instanceWithRootObject:root identifier:cid];
    if (![self validateConversation:conversation manager:manager account:account peer:userID identifier:cid]) { fail(@"会话账户或接收人不匹配，已停止发送"); return; }
    TIMXOMessage *last = conversation.lastMessage;
    NSDictionary *content = last.content;
    NSNumber *type = [self shared].textTypes[account];
    if (!type) type = [NSUserDefaults.standardUserDefaults dictionaryForKey:[self textTypeCacheKey]][account];
    if (![type isKindOfClass:NSNumber.class] || type.longLongValue <= 0) type = nil;
    // 参数是 ID 还是会话对象，必须先观察抖音自己的调用，不能根据 id 类型猜测。
    TIMXOMessageManager *messages = [self serviceForRole:@"messages" root:root];
    NSString *historyKind = messages ? [[self shared].historyArguments objectForKey:messages] : nil;
    NSSet *manualIDs = [NSSet setWithArray:[NSUserDefaults.standardUserDefaults arrayForKey:[self manualIDsKey:account]] ?: @[]];
    if (messages && [self value:messages key:@"r"] == root && historyKind.length && (!manualTest || !type)) {
        id argument = [historyKind isEqual:@"identifier"] ? (id)cid : conversation;
        @try {
            id history = [messages messagesInConversation:argument excludeMessageTypes:@[] limit:manualTest ? 200 : 1000];
            if ([history isKindOfClass:NSArray.class]) {
                for (TIMXOMessage *message in history) {
                    if (![message respondsToSelector:@selector(sender)] || ![message respondsToSelector:@selector(createdAt)]) continue;
                    if (!manualTest && ![manualIDs containsObject:message.identifier ?: @""] && message.sender == account.longLongValue && [message.createdAt isKindOfClass:NSDate.class] && [NSCalendar.currentCalendar isDateInToday:message.createdAt]) {
                        [self setState:@"sent" key:stateKey];
                        fail(@"本地历史记录显示你今天已经发送，不再重复发送"); return;
                    }
                    NSDictionary *body = message.content;
                    if (!type) type = [self textTypeForBody:body number:@(message.messageType)];
                }
            }
        } @catch (__unused NSException *exception) {
            if (!manualTest) { fail(@"本地消息历史暂不可读，已停止本次发送"); return; }
        }
    }
    if (!type) type = [self textTypeForBody:content number:@(last.messageType)];
    if (!type && [messages respondsToSelector:@selector(earliestMessagesInConversationWithIdentifier:limit:)]) {
        // 同样使用参数明确的会话 ID 入口识别文字类型，避免时间查询的非列表返回。
        @try {
            NSArray *recent = [self messageArray:[messages earliestMessagesInConversationWithIdentifier:cid limit:200]];
            for (TIMXOMessage *message in recent) {
                type = [self textTypeForBody:message.content number:@(message.messageType)];
                if (type) break;
            }
        } @catch (__unused NSException *exception) {}
    }
    if (!type) { fail(@"当前消息服务没有可识别的文字格式，尚未请求发送；请导出消息接口记录"); return; }
    [self rememberTextType:type account:account];
    if (!manualTest && ![manualIDs containsObject:last.identifier ?: @""] && last.sender == account.longLongValue && [last.createdAt isKindOfClass:NSDate.class] && [NSCalendar.currentCalendar isDateInToday:last.createdAt]) {
        [self setState:@"sent" key:stateKey];
        fail(@"会话末条消息显示你今天已发送，不再重复发送"); return;
    }
    Class modelClass = NSClassFromString(@"IESIMSendMessageModel");
    if (![modelClass instancesRespondToSelector:@selector(initWithConversationId:)]) { fail(@"文字消息模型不可用"); return; }
    IESIMSendMessageModel *model = [[modelClass alloc] initWithConversationId:cid];
    NSString *requestID = NSUUID.UUID.UUIDString;
    model.messageType = type.longLongValue;
    model.messageContentDict = @{@"text":text};
    model.preferMessageId = requestID;
    NSMutableDictionary *pending = [@{@"stateKey":stateKey, @"conversationID":cid, @"manualTest":@(manualTest)} mutableCopy];
    if (completion) pending[@"completion"] = [completion copy];
    [self shared].pending[requestID] = pending;
    if (manualTest) [self rememberManualID:requestID account:account];
    if (!manualTest) [self setState:@"pending" key:stateKey];
    @try {
        id message = [sender sendMessage:model];
        NSString *nativeID = [self value:message key:@"identifier"];
        if ([nativeID isKindOfClass:NSString.class] && nativeID.length && ![nativeID isEqual:requestID]) {
            [[self shared].pending removeObjectForKey:requestID];
            [self shared].pending[nativeID] = pending;
            if (manualTest) [self rememberManualID:nativeID account:account];
            requestID = nativeID;
        }
    } @catch (__unused NSException *exception) {
        [self finishPending:pending success:NO reason:@"发送接口发生异常，状态待确认，不自动重试" confirmed:NO];
    }
    NSString *trackingID = requestID;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSMutableDictionary *waiting = [self shared].pending[trackingID];
        if (waiting) {
            NSString *reason = manualTest ? @"暂未收到测试回执，不能确认结果；仍可手动再次测试" : @"暂未收到发送回执，保留待确认状态避免重复发送";
            [self finishPending:waiting success:NO reason:reason confirmed:NO];
            if (manualTest) [[self shared].pending removeObjectForKey:trackingID];
        }
    });
}
@end


