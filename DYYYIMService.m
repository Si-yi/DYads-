#import "DYYYIMService.h"
#import "AwemeHeaders.h"

@interface DYYYIMService ()
@property (nonatomic, strong) NSMapTable *services;
@property (nonatomic, strong) NSMutableDictionary *pending;
@property (nonatomic, strong) NSMutableDictionary *textTypes;
@property (nonatomic, copy) NSString *historyArgument;
@end

@implementation DYYYIMService

#pragma mark - 本地未读分享

+ (void)collectSharedIDs:(id)object into:(NSMutableOrderedSet *)ids depth:(NSUInteger)depth budget:(NSUInteger *)budget {
    if (!object || depth > 7 || *budget == 0) return;
    (*budget)--;
    if ([object isKindOfClass:NSDictionary.class]) {
        for (id rawKey in object) {
            if (![rawKey isKindOfClass:NSString.class]) continue;
            NSString *key = [[rawKey lowercaseString] stringByReplacingOccurrencesOfString:@"_" withString:@""];
            id value = object[rawKey];
            if ([key isEqual:@"itemid"] || [key isEqual:@"awemeid"]) {
                NSString *itemID = [value isKindOfClass:NSString.class] ? value : ([value isKindOfClass:NSNumber.class] ? [value stringValue] : nil);
                if (itemID.length >= 8 && itemID.length <= 22 && [itemID rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound) [ids addObject:itemID];
            } else [self collectSharedIDs:value into:ids depth:depth + 1 budget:budget];
        }
    } else if ([object isKindOfClass:NSArray.class]) {
        for (id value in object) [self collectSharedIDs:value into:ids depth:depth + 1 budget:budget];
    } else if ([object isKindOfClass:NSString.class] && [object length] < 65536) {
        NSString *text = [object stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([text hasPrefix:@"{"] || [text hasPrefix:@"["]) {
            id value = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            [self collectSharedIDs:value into:ids depth:depth + 1 budget:budget];
        }
    }
}

+ (NSArray<NSDictionary *> *)unreadSharesForUsers:(NSArray<NSString *> *)userIDs error:(NSString **)error {
    NSString *account = [self accountID];
    TIMXOConversationManager *manager = [[self shared].services objectForKey:@"conversations"];
    TIMXOMessageManager *messages = [[self shared].services objectForKey:@"messages"];
    id root = [self value:manager key:@"r"];
    if (!account.length || !manager || !messages || !root || [self value:messages key:@"r"] != root || ![self shared].historyArgument.length) {
        if (error) *error = @"本地消息服务尚未就绪，请先打开好友聊天再返回扫描";
        return @[];
    }
    Class convClass = NSClassFromString(@"TIMXOConversation");
    if (![convClass respondsToSelector:@selector(instanceWithRootObject:identifier:)]) {
        if (error) *error = @"当前版本的会话读取入口不可用";
        return @[];
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    @try {
        for (NSString *peer in userIDs) {
            if (![peer isKindOfClass:NSString.class] || peer.longLongValue <= 0 || [peer isEqual:account]) continue;
            NSString *cid = [manager conversationIDFor1to1ChatWithOtherUserID:peer.longLongValue inbox:0];
            if (!cid.length || ![manager conversationExitsInDB:cid]) continue;
            TIMXOConversation *conv = [(id)convClass instanceWithRootObject:root identifier:cid];
            if (conv.ownerID != account.longLongValue || [manager otherUserIDFor1to1ChatWithConversationID:cid] != peer.longLongValue) continue;
            unsigned long long unread = conv.unreadCount;
            if (!unread) continue;
            id argument = [[self shared].historyArgument isEqual:@"identifier"] ? (id)cid : conv;
            id result = [messages messagesInConversation:argument excludeMessageTypes:@[] limit:MIN(MAX(unread, 100ULL), 1000ULL)];
            if (![result isKindOfClass:NSArray.class]) continue;
            // 先按时间排序，避免底层返回顺序变化时取到旧的已读消息。
            NSArray *history = [result sortedArrayUsingComparator:^NSComparisonResult(TIMXOMessage *a, TIMXOMessage *b) {
                NSDate *da = a.createdAt, *db = b.createdAt;
                return [da isKindOfClass:NSDate.class] && [db isKindOfClass:NSDate.class] ? [db compare:da] : NSOrderedSame;
            }];
            NSString *boundary = conv.firstUnreadMessageID;
            NSUInteger incoming = 0;
            for (TIMXOMessage *message in history) {
                BOOL lastUnread = boundary.length && [message.identifier isEqual:boundary];
                if (incoming >= unread) break;
                if (message.sender != peer.longLongValue) { if (lastUnread) break; else continue; }
                incoming++;
                NSMutableOrderedSet *itemIDs = [NSMutableOrderedSet orderedSet];
                NSUInteger budget = 500;
                [self collectSharedIDs:message.content into:itemIDs depth:0 budget:&budget];
                for (NSString *itemID in itemIDs) {
                    if ([seen containsObject:itemID]) continue;
                    [seen addObject:itemID];
                    [rows addObject:@{@"itemID":itemID, @"friendID":peer}];
                }
                if (lastUnread) break;
            }
        }
    } @catch (__unused NSException *exception) {
        if (error) *error = @"读取本地未读消息失败，未修改会话或推荐列表";
        return @[];
    }
    return rows;
}

+ (instancetype)shared {
    static DYYYIMService *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [self new];
        instance.services = [NSMapTable strongToWeakObjectsMapTable];
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
    [[self shared].services setObject:service forKey:role];
}

+ (id)contactDatabase {
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

+ (void)observeTextModel:(id)model sender:(id)sender {
    [self captureService:sender role:@"sender"];
    id content = [self value:model key:@"messageContentDict"];
    id type = [self value:model key:@"messageType"];
    if (![content isKindOfClass:NSDictionary.class] || ![content[@"text"] isKindOfClass:NSString.class] || ![type isKindOfClass:NSNumber.class]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *account = [self accountID];
        if (account.length) [self shared].textTypes[account] = type;
    });
}

+ (void)observeHistoryQuery:(id)conversation manager:(id)manager {
    NSString *kind = nil;
    if ([conversation isKindOfClass:NSString.class]) kind = @"identifier";
    else if ([conversation isKindOfClass:NSClassFromString(@"TIMXOConversation")]) kind = @"conversation";
    if (!kind) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self captureService:manager role:@"messages"];
        [self shared].historyArgument = kind;
    });
}

+ (void)finishPending:(NSMutableDictionary *)pending success:(BOOL)success reason:(NSString *)reason confirmed:(BOOL)confirmed {
    if (confirmed) [self setState:success ? @"sent" : nil key:pending[@"stateKey"]];
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
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self sendText:text toUserID:userID completion:completion]; });
        return;
    }
    void (^fail)(NSString *) = ^(NSString *reason) { if (completion) completion(NO, reason); };
    NSString *account = [self accountID];
    if (!account.length || !text.length || !userID.length || userID.longLongValue <= 0) { fail(@"账户、用户 ID 或消息内容未就绪"); return; }
    NSString *stateKey = [self stateKey:userID];
    if ([self dailyStateForUserID:userID].length) { fail(@"该好友今天已有发送或待确认记录，不重复发送"); return; }
    TIMXOConversationManager *manager = [[self shared].services objectForKey:@"conversations"];
    IESIMMessageSender *sender = [[self shared].services objectForKey:@"sender"];
    if (!manager || !sender || ![manager respondsToSelector:@selector(conversationIDFor1to1ChatWithOtherUserID:inbox:)] || ![sender respondsToSelector:@selector(sendMessage:)]) { fail(@"消息服务尚未初始化，请先打开一次好友聊天"); return; }
    NSString *cid = [manager conversationIDFor1to1ChatWithOtherUserID:userID.longLongValue inbox:0];
    if (![cid isKindOfClass:NSString.class] || !cid.length || ![manager conversationExitsInDB:cid]) { fail(@"没有找到已有会话，请先打开一次该好友聊天"); return; }
    id root = [self value:manager key:@"r"];
    id senderRoot = [self value:sender key:@"sdkRoot"];
    if (!root || root != senderRoot) { fail(@"消息服务账户尚未同步，请重新进入好友聊天"); return; }
    Class convClass = NSClassFromString(@"TIMXOConversation");
    if (![convClass respondsToSelector:@selector(instanceWithRootObject:identifier:)]) { fail(@"当前版本没有可用的会话读取入口"); return; }
    TIMXOConversation *conversation = [(id)convClass instanceWithRootObject:root identifier:cid];
    if (![conversation respondsToSelector:@selector(ownerID)] || conversation.ownerID != account.longLongValue || [manager otherUserIDFor1to1ChatWithConversationID:cid] != userID.longLongValue) { fail(@"会话账户或接收人不匹配，已停止发送"); return; }
    TIMXOMessage *last = conversation.lastMessage;
    NSDictionary *content = last.content;
    NSNumber *type = [self shared].textTypes[account];
    // 参数是 ID 还是会话对象，必须先观察抖音自己的调用，不能根据 id 类型猜测。
    TIMXOMessageManager *messages = [[self shared].services objectForKey:@"messages"];
    if (messages && [self value:messages key:@"r"] == root && [self shared].historyArgument.length) {
        id argument = [[self shared].historyArgument isEqual:@"identifier"] ? (id)cid : conversation;
        @try {
            id history = [messages messagesInConversation:argument excludeMessageTypes:@[] limit:1000];
            if ([history isKindOfClass:NSArray.class]) {
                for (TIMXOMessage *message in history) {
                    if (![message respondsToSelector:@selector(sender)] || ![message respondsToSelector:@selector(createdAt)]) continue;
                    if (message.sender == account.longLongValue && [message.createdAt isKindOfClass:NSDate.class] && [NSCalendar.currentCalendar isDateInToday:message.createdAt]) {
                        [self setState:@"sent" key:stateKey];
                        fail(@"本地历史记录显示你今天已经发送，不再重复发送"); return;
                    }
                    NSDictionary *body = message.content;
                    if (!type && [body isKindOfClass:NSDictionary.class] && [body[@"text"] isKindOfClass:NSString.class]) type = @(message.messageType);
                }
            }
        } @catch (__unused NSException *exception) {
            fail(@"本地消息历史暂不可读，已停止本次发送"); return;
        }
    }
    if (!type && [content isKindOfClass:NSDictionary.class] && [content[@"text"] isKindOfClass:NSString.class]) type = @(last.messageType);
    if (!type) { fail(@"尚未识别文字消息格式，请先手动发送一条普通文字"); return; }
    if (last.sender == account.longLongValue && [last.createdAt isKindOfClass:NSDate.class] && [NSCalendar.currentCalendar isDateInToday:last.createdAt]) {
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
    NSMutableDictionary *pending = [@{@"stateKey":stateKey, @"conversationID":cid} mutableCopy];
    if (completion) pending[@"completion"] = [completion copy];
    [self shared].pending[requestID] = pending;
    [self setState:@"pending" key:stateKey];
    @try {
        id message = [sender sendMessage:model];
        NSString *nativeID = [self value:message key:@"identifier"];
        if ([nativeID isKindOfClass:NSString.class] && nativeID.length && ![nativeID isEqual:requestID]) {
            [[self shared].pending removeObjectForKey:requestID];
            [self shared].pending[nativeID] = pending;
            requestID = nativeID;
        }
    } @catch (__unused NSException *exception) {
        [self finishPending:pending success:NO reason:@"发送接口发生异常，状态待确认，不自动重试" confirmed:NO];
    }
    NSString *trackingID = requestID;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSMutableDictionary *waiting = [self shared].pending[trackingID];
        if (waiting) [self finishPending:waiting success:NO reason:@"暂未收到发送回执，保留待确认状态避免重复发送" confirmed:NO];
    });
}
@end

