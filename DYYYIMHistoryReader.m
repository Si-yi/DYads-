#import "DYYYIMHistoryReader.h"

@implementation DYYYIMHistoryReader
+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}

+ (BOOL)appendResult:(id)result to:(NSMutableArray *)messages depth:(NSUInteger)depth {
    if (!result || depth > 6 || messages.count > 65536) return NO;
    if ([result respondsToSelector:NSSelectorFromString(@"belongingConversationIdentifier")] &&
        [result respondsToSelector:NSSelectorFromString(@"identifier")]) {
        [messages addObject:result];
        return YES;
    }
    if ([result isKindOfClass:NSArray.class] || [result isKindOfClass:NSSet.class] || [result isKindOfClass:NSOrderedSet.class]) {
        for (id value in result) if (![self appendResult:value to:messages depth:depth + 1]) return NO;
        return YES;
    }
    if ([result isKindOfClass:NSDictionary.class]) {
        for (NSString *key in @[ @"messages", @"messageList", @"list", @"data" ])
            if (result[key]) return [self appendResult:result[key] to:messages depth:depth + 1];
        // 部分原生查询按会话 ID 分组，不能把整个字典误认为不可读结果。
        for (id value in [result allValues]) if (![self appendResult:value to:messages depth:depth + 1]) return NO;
        return YES;
    }
    for (NSString *key in @[ @"messages", @"messageList" ]) {
        if (![result respondsToSelector:NSSelectorFromString(key)]) continue;
        id value = [self value:result key:key];
        if (value && value != result) return [self appendResult:value to:messages depth:depth + 1];
    }
    return NO;
}

+ (NSArray *)messageArray:(id)result {
    NSMutableArray *messages = [NSMutableArray array];
    return [self appendResult:result to:messages depth:0] ? messages : nil;
}

+ (NSArray *)validatedHistory:(id)result conversation:(NSString *)identifier latestID:(NSString *)latestID {
    NSArray *messages = [self messageArray:result];
    if (!messages || !latestID.length) return nil;
    NSMutableDictionary *unique = [NSMutableDictionary dictionary];
    for (id message in messages) {
        if (![[self value:message key:@"belongingConversationIdentifier"] isEqual:identifier]) continue;
        NSString *messageID = [self value:message key:@"identifier"];
        if ([messageID isKindOfClass:NSString.class] && messageID.length) unique[messageID] = message;
    }
    // 必须覆盖会话末条；最早的旧消息即使有 2000 条也不能充当近期未读。
    if (!unique[latestID]) return nil;
    return [unique.allValues sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSNumber *ia = [self value:a key:@"orderInConversation"], *ib = [self value:b key:@"orderInConversation"];
        if ([ia isKindOfClass:NSNumber.class] && [ib isKindOfClass:NSNumber.class] && ![ia isEqual:ib]) return [ib compare:ia];
        NSDate *da = [self value:a key:@"createdAt"], *db = [self value:b key:@"createdAt"];
        if ([da isKindOfClass:NSDate.class] && [db isKindOfClass:NSDate.class]) return [db compare:da];
        return NSOrderedSame;
    }];
}

+ (NSArray *)historyForConversation:(NSString *)identifier latestMessage:(id)latest observedResult:(id)observed
                       recentQuery:(id (^)(NSTimeInterval, NSUInteger))recentQuery
                     earliestQuery:(id (^)(NSUInteger))earliestQuery diagnostics:(NSMutableDictionary *)diagnostics {
    NSString *latestID = [self value:latest key:@"identifier"];
    NSArray *history = [self validatedHistory:observed conversation:identifier latestID:latestID];
    if (history) { diagnostics[@"query"] = @"observed_conversation"; return history; }
    NSDate *date = [self value:latest key:@"createdAt"];
    if (recentQuery && [date isKindOfClass:NSDate.class]) {
        // 从目标会话末条的时间附近读取近期消息，再严格按会话 ID 分流。
        // 是否可用由末条覆盖校验决定，不能仅凭原生返回了数组就判定成功。
        @try {
            id raw = recentQuery(date.timeIntervalSince1970 + 1, 2000);
            diagnostics[@"recentReturnClass"] = raw ? NSStringFromClass([raw class]) : @"nil";
            history = [self validatedHistory:raw conversation:identifier latestID:latestID];
            if (history) { diagnostics[@"query"] = @"recent_by_time"; return history; }
        } @catch (__unused NSException *exception) { diagnostics[@"recentQueryFailed"] = @YES; }
    }
    // 兼容仅支持明确会话 ID 查询的版本，按需扩展，不能固定读最早 2000 条后退出。
    if (earliestQuery) for (NSUInteger limit = 2000; limit <= 32000; limit *= 2) {
        @try {
            id raw = earliestQuery(limit);
            NSArray *messages = [self messageArray:raw];
            diagnostics[@"earliestLimit"] = @(limit);
            diagnostics[@"earliestMessageCount"] = @(messages.count);
            history = [self validatedHistory:messages conversation:identifier latestID:latestID];
            if (history) { diagnostics[@"query"] = @"expanded_by_identifier"; return history; }
            if (!messages || messages.count < limit) break;
        } @catch (__unused NSException *exception) { diagnostics[@"earliestQueryFailed"] = @YES; break; }
    }
    diagnostics[@"query"] = @"latest_not_covered";
    return nil;
}

+ (NSArray *)unreadIncomingMessages:(NSArray *)history peerID:(long long)peer unreadCount:(NSUInteger)count firstUnreadID:(NSString *)boundary {
    NSMutableArray *incoming = [NSMutableArray array];
    for (id message in history) {
        if (incoming.count >= count) break;
        BOOL atBoundary = boundary.length && [[self value:message key:@"identifier"] isEqual:boundary];
        if ([[self value:message key:@"sender"] longLongValue] == peer) [incoming addObject:message];
        if (atBoundary) break;
    }
    return incoming;
}
@end
