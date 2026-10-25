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

// 原生首条未读可能是本地 identifier，也可能是数值 serverMessageID，不能只比一种。
+ (NSString *)normalizedBoundary:(id)boundary {
    NSString *text = [boundary isKindOfClass:NSString.class] ? boundary :
        ([boundary isKindOfClass:NSNumber.class] ? [boundary stringValue] : nil);
    return text.length && ![text isEqual:@"0"] ? text : nil;
}
+ (NSString *)boundaryKind:(NSString *)boundary message:(id)message {
    if (!boundary.length) return nil;
    if ([[self value:message key:@"identifier"] isEqual:boundary]) return @"identifier";
    id server = [self value:message key:@"serverMessageID"];
    NSString *serverID = [server isKindOfClass:NSNumber.class] ? [server stringValue] :
        ([server isKindOfClass:NSString.class] ? server : nil);
    return [serverID isEqual:boundary] ? @"serverMessageID" : nil;
}
+ (BOOL)history:(NSArray *)history coversBoundary:(NSString *)boundary {
    if (!boundary.length) return YES;
    for (id message in history) if ([self boundaryKind:boundary message:message]) return YES;
    return NO;
}
+ (NSArray *)historyForConversation:(NSString *)identifier latestMessage:(id)latest observedResult:(id)observed
                       recentQuery:(id (^)(NSTimeInterval, NSUInteger))recentQuery
                     earliestQuery:(id (^)(NSUInteger))earliestQuery diagnostics:(NSMutableDictionary *)diagnostics {
    return [self historyForConversation:identifier latestMessage:latest firstUnreadID:nil observedResult:observed
        recentQuery:recentQuery earliestQuery:earliestQuery diagnostics:diagnostics];
}
+ (NSArray *)historyForConversation:(NSString *)identifier latestMessage:(id)latest firstUnreadID:(NSString *)rawBoundary
                    observedResult:(id)observed recentQuery:(id (^)(NSTimeInterval, NSUInteger))recentQuery
                     earliestQuery:(id (^)(NSUInteger))earliestQuery diagnostics:(NSMutableDictionary *)diagnostics {
    NSString *latestID = [self value:latest key:@"identifier"];
    NSString *boundary = [self normalizedBoundary:rawBoundary];
    NSArray *history = [self validatedHistory:observed conversation:identifier latestID:latestID];
    NSArray *best = history;
    NSString *bestQuery = history ? @"observed_conversation" : nil;
    if (history && [self history:history coversBoundary:boundary]) { diagnostics[@"query"] = bestQuery; return history; }
    NSDate *date = [self value:latest key:@"createdAt"];
    if (recentQuery && [date isKindOfClass:NSDate.class]) {
        @try {
            id raw = recentQuery(date.timeIntervalSince1970 + 1, 2000);
            diagnostics[@"recentReturnClass"] = raw ? NSStringFromClass([raw class]) : @"nil";
            history = [self validatedHistory:raw conversation:identifier latestID:latestID];
            if (history) {
                best = history; bestQuery = @"recent_by_time";
                if ([self history:history coversBoundary:boundary]) { diagnostics[@"query"] = bestQuery; return history; }
            }
        } @catch (__unused NSException *exception) { diagnostics[@"recentQueryFailed"] = @YES; }
    }
    // 不仅要含末条，还要覆盖确切的未读边界；否则继续扩大明确会话 ID 的只读窗口。
    if (earliestQuery) for (NSUInteger limit = 2000; limit <= 32000; limit *= 2) {
        @try {
            id raw = earliestQuery(limit);
            NSArray *messages = [self messageArray:raw];
            diagnostics[@"earliestLimit"] = @(limit);
            diagnostics[@"earliestMessageCount"] = @(messages.count);
            history = [self validatedHistory:messages conversation:identifier latestID:latestID];
            if (history) {
                best = history; bestQuery = @"expanded_by_identifier";
                if ([self history:history coversBoundary:boundary]) { diagnostics[@"query"] = bestQuery; return history; }
            }
            if (!messages || messages.count < limit) break;
        } @catch (__unused NSException *exception) { diagnostics[@"earliestQueryFailed"] = @YES; break; }
    }
    // 仍可用本地历史核对旧错误凭据；未读截取会单独拒绝缺失的边界，不能退回按数量扫旧消息。
    diagnostics[@"query"] = bestQuery ?: @"latest_not_covered";
    return best;
}
+ (NSArray *)unreadIncomingMessages:(NSArray *)history peerID:(long long)peer unreadCount:(NSUInteger)count firstUnreadID:(NSString *)boundary {
    return [self unreadIncomingMessages:history peerID:peer unreadCount:count firstUnreadID:boundary diagnostics:nil];
}
+ (NSArray *)unreadIncomingMessages:(NSArray *)history peerID:(long long)peer unreadCount:(NSUInteger)count
                     firstUnreadID:(NSString *)rawBoundary diagnostics:(NSMutableDictionary *)diagnostics {
    diagnostics[@"nativeUnreadCount"] = @(count);
    NSString *boundary = [self normalizedBoundary:rawBoundary];
    diagnostics[@"unreadBoundaryProvided"] = @(boundary.length > 0);
    if (!count) { diagnostics[@"unreadSelection"] = @"read_conversation"; return @[]; }
    if (!boundary.length) { diagnostics[@"unreadSelection"] = @"boundary_missing"; return @[]; }
    NSUInteger end = NSNotFound;
    for (NSUInteger i = 0; i < history.count; i++) {
        NSString *kind = [self boundaryKind:boundary message:history[i]];
        if (kind) { end = i; diagnostics[@"unreadBoundaryMatchedBy"] = kind; break; }
    }
    if (end == NSNotFound) { diagnostics[@"unreadSelection"] = @"boundary_not_covered"; return @[]; }
    NSMutableArray *incoming = [NSMutableArray array];
    for (NSUInteger i = 0; i <= end && incoming.count < count; i++) {
        id message = history[i];
        if ([[self value:message key:@"sender"] longLongValue] == peer) [incoming addObject:message];
    }
    diagnostics[@"unreadSelection"] = @"verified_boundary";
    diagnostics[@"unreadBoundaryOffset"] = @(end);
    diagnostics[@"unreadSliceCount"] = @(incoming.count);
    return incoming;
}
@end
