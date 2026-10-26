#import <Foundation/Foundation.h>
#import "DYYYIMHistoryReader.h"

@interface DYYYHistoryTestMessage : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *belongingConversationIdentifier;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSNumber *orderInConversation;
@property (nonatomic, strong) NSNumber *serverMessageID;
@property (nonatomic) long long sender;
@end
@implementation DYYYHistoryTestMessage
@end

@interface DYYYIMHistoryReaderTests : NSObject
+ (void)run;
@end
@implementation DYYYIMHistoryReaderTests
+ (DYYYHistoryTestMessage *)message:(NSUInteger)index conversation:(NSString *)cid sender:(long long)sender {
    DYYYHistoryTestMessage *message = [DYYYHistoryTestMessage new];
    message.identifier = [NSString stringWithFormat:@"message-%lu", (unsigned long)index];
    message.belongingConversationIdentifier = cid;
    message.createdAt = [NSDate dateWithTimeIntervalSince1970:1700000000 + index];
    message.orderInConversation = @(index);
    message.sender = sender;
    return message;
}
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    NSMutableArray *all = [NSMutableArray array];
    for (NSUInteger i = 0; i < 2505; i++) [all addObject:[self message:i conversation:@"chat-A" sender:42]];
    id latest = all.lastObject;
    NSArray *recent = [all subarrayWithRange:NSMakeRange(all.count - 13, 13)];
    NSMutableDictionary *diagnostics = [NSMutableDictionary dictionary];
    __block NSUInteger earliestCalls = 0;
    NSArray *history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest observedResult:nil
        recentQuery:^id(NSTimeInterval before, NSUInteger limit) {
            [self check:before > [latest createdAt].timeIntervalSince1970 reason:@"近期查询必须覆盖会话末条"];
            // 原生结果按会话分组，并带 data 外壳。
            return @{ @"data": @{ @"chat-A": recent, @"chat-B": @[ [self message:8000 conversation:@"chat-B" sender:84] ] } };
        } earliestQuery:^id(NSUInteger limit) { earliestCalls++; return all; } diagnostics:diagnostics];
    [self check:history.count == 13 && earliestCalls == 0 reason:@"13 条未读应直接取近期消息，不受 2505 条历史影响"];
    NSArray *incoming = [DYYYIMHistoryReader unreadIncomingMessages:history peerID:42 unreadCount:13 firstUnreadID:[recent.firstObject identifier]];
    [self check:incoming.count == 13 reason:@"近期 13 条未读必须完整保留"];

    // 只支持最早消息入口时，必须扩大窗口，不能把旧的前 2000 条当成未读。
    diagnostics = [NSMutableDictionary dictionary];
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest
        observedResult:[all subarrayWithRange:NSMakeRange(0, 2000)] recentQuery:nil earliestQuery:^id(NSUInteger limit) {
            return [all subarrayWithRange:NSMakeRange(0, MIN(limit, all.count))];
        } diagnostics:diagnostics];
    [self check:history.count == all.count && [diagnostics[@"earliestLimit"] unsignedIntegerValue] == 4000 reason:@"旧窗口必须扩展至包含末条"];

    // 少于 2000 条也可能读错会话，不能用条数判断覆盖成功或宣称历史过多。
    id foreign = [self message:2504 conversation:@"chat-B" sender:84];
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest observedResult:@[ foreign ]
        recentQuery:^id(NSTimeInterval before, NSUInteger limit) { return @[ foreign ]; }
        earliestQuery:^id(NSUInteger limit) { return @[ all.firstObject ]; } diagnostics:[NSMutableDictionary dictionary]];
    [self check:history == nil reason:@"错误会话或不含末条的短窗口必须拒绝"];

    // 某个原生入口抛异常时仍应尝试可用的会话 ID 入口。
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest observedResult:nil
        recentQuery:^id(NSTimeInterval before, NSUInteger limit) { [NSException raise:@"NativeQueryFailure" format:@"unavailable"]; return nil; }
        earliestQuery:^id(NSUInteger limit) { return @[ latest ]; } diagnostics:[NSMutableDictionary dictionary]];
    [self check:history.count == 1 reason:@"入口异常不能阻断备用读取"];

    id boundary = [self message:10 conversation:@"chat-A" sender:42];
    id own = [self message:11 conversation:@"chat-A" sender:7];
    id unread = [self message:12 conversation:@"chat-A" sender:42];
    id read = [self message:9 conversation:@"chat-A" sender:42];
    incoming = [DYYYIMHistoryReader unreadIncomingMessages:@[ unread, own, boundary, read ] peerID:42 unreadCount:13 firstUnreadID:[boundary identifier]];
    [self check:incoming.count == 2 && ![incoming containsObject:own] && ![incoming containsObject:read] reason:@"只读取好友发来的未读，不能越过首条未读边界"];
    [self check:[DYYYIMHistoryReader unreadIncomingMessages:@[ unread ] peerID:42 unreadCount:0 firstUnreadID:@""].count == 0 reason:@"已读会话不能重新推送"];
    [boundary setServerMessageID:@910000000000000001LL];
    NSMutableDictionary *window = [NSMutableDictionary dictionary];
    incoming = [DYYYIMHistoryReader unreadIncomingMessages:@[unread, own, boundary, read] peerID:42
        unreadCount:59 firstUnreadID:@"910000000000000001" diagnostics:window];
    [self check:incoming.count == 2 && ![incoming containsObject:read] &&
        [window[@"unreadBoundaryMatchedBy"] isEqual:@"serverMessageID"]
        reason:@"原生边界为服务器 ID 时不能当作失配后继续凑 59 条好友旧消息"];
    for (NSString *missing in @[@"", @"0", @"missing-first-unread"]) {
        window = [NSMutableDictionary dictionary];
        incoming = [DYYYIMHistoryReader unreadIncomingMessages:history peerID:42 unreadCount:59
            firstUnreadID:missing diagnostics:window];
        [self check:incoming.count == 0 && ![window[@"unreadSelection"] isEqual:@"verified_boundary"]
            reason:@"边界缺失/找不到时不能按未读数量从整份历史回捞旧分享"];
    }
    incoming = [DYYYIMHistoryReader unreadIncomingMessages:@[unread, own, boundary, read] peerID:42
        unreadCount:59 firstUnreadID:[own identifier]];
    [self check:incoming.count == 1 && incoming.firstObject == unread reason:@"边界即使对应本账户消息也必须停止，不能越界扫描"];
    [self check:[DYYYIMHistoryReader unreadIncomingMessages:@[unread, boundary] peerID:42 unreadCount:0
        firstUnreadID:[boundary identifier]].count == 0 reason:@"已读后残留的边界不能复活历史分享"];
    diagnostics = [NSMutableDictionary dictionary];
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest firstUnreadID:[all[1000] identifier]
        observedResult:recent recentQuery:nil earliestQuery:^id(NSUInteger limit) {
            return [all subarrayWithRange:NSMakeRange(0, MIN(limit, all.count))];
        } diagnostics:diagnostics];
    [self check:history.count == all.count && [diagnostics[@"earliestLimit"] unsignedIntegerValue] == 4000
        reason:@"近期窗口含末条但未覆盖首条未读时，还需扩展，不能把未读窗口截丢"];

    // 同一时间戳的消息仍沿原生会话顺序定位边界。
    [unread setCreatedAt:[boundary createdAt]];
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:unread observedResult:@[ boundary, unread ]
        recentQuery:nil earliestQuery:nil diagnostics:[NSMutableDictionary dictionary]];
    [self check:history.firstObject == unread reason:@"同时间戳必须使用会话序号排序"];
    [self check:[DYYYIMHistoryReader messageArray:@"invalid"] == nil reason:@"未知返回值不能冒充消息列表"];
    // 39.5 真机 unreadCount=2、firstUnreadMessageID=nil：专用 unread 查询提供独立依据。
    window = [NSMutableDictionary dictionary];
    incoming = [DYYYIMHistoryReader nativeUnreadIncomingMessages:@{@"messages": @[unread, boundary]}
        conversation:@"chat-A" peerID:42 unreadCount:2 diagnostics:window];
    [self check:incoming.count == 2 && [window[@"unreadSelection"] isEqual:@"native_unread_query"]
        reason:@"原生未读结果不需要 firstUnreadMessageID，也不要求包含会话末条"];
    incoming = [DYYYIMHistoryReader nativeUnreadIncomingMessages:@[unread, unread, boundary]
        conversation:@"chat-A" peerID:42 unreadCount:2 diagnostics:window];
    [self check:incoming.count == 2 reason:@"同一未读回执只交付一次"];
    incoming = [DYYYIMHistoryReader nativeUnreadIncomingMessages:@[] conversation:@"chat-A" peerID:42 unreadCount:2 diagnostics:window];
    [self check:incoming != nil && incoming.count == 0 reason:@"原生查询确认空列表与读取失败必须区分"];
    for (id invalid in @[@[unread, own], @[foreign], @[unread, boundary, read], @"invalid", NSNull.null]) {
        incoming = [DYYYIMHistoryReader nativeUnreadIncomingMessages:invalid conversation:@"chat-A" peerID:42 unreadCount:2 diagnostics:window];
        [self check:incoming == nil reason:@"错误发送者、错误会话、历史超量和无效结果不能成为未读凭据"];
    }
    [self check:[DYYYIMHistoryReader nativeUnreadIncomingMessages:nil conversation:@"chat-A" peerID:42 unreadCount:2 diagnostics:window] == nil
        reason:@"原生返回 nil 必须保留失败状态，不能冒充没有新分享"];
    incoming = [DYYYIMHistoryReader nativeUnreadIncomingMessages:@[unread] conversation:@"chat-A" peerID:42 unreadCount:0 diagnostics:window];
    [self check:incoming.count == 0 reason:@"残留原生结果不能复活已读会话"];
    // 1.8.4 导出中会话未读数 182/1485/62，专用查询分别返回 0/1/2 条。
    // 无旧凭据需要核实时，绝不能因大计数再展开 2000..32000 条完整历史。
    __block NSUInteger scanHistoryCalls = 0;
    id (^observedQuery)(void) = ^id { scanHistoryCalls++; return @[latest]; };
    id (^recentQuery)(NSTimeInterval, NSUInteger) = ^id(NSTimeInterval time, NSUInteger limit) { scanHistoryCalls++; return @[latest]; };
    id (^oldQuery)(NSUInteger) = ^id(NSUInteger limit) { scanHistoryCalls++; return all; };
    NSArray *nativeResults = @[@[], @[unread], @[unread, boundary]];
    NSArray *nativeCounts = @[@182, @1485, @62];
    for (NSUInteger index = 0; index < nativeResults.count; index++) {
        window = [NSMutableDictionary dictionary];
        NSArray *validated = [DYYYIMHistoryReader nativeUnreadIncomingMessages:nativeResults[index]
            conversation:@"chat-A" peerID:42 unreadCount:[nativeCounts[index] unsignedIntegerValue] diagnostics:window];
        history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest firstUnreadID:@""
            nativeUnread:validated revalidating:NO observedResult:observedQuery recentQuery:recentQuery earliestQuery:oldQuery diagnostics:window];
        [self check:history == nil && scanHistoryCalls == 0 && [window[@"query"] isEqual:@"native_unread_only"]
            reason:@"已验证未读结果（包括空列表）不触发任何历史入口，也不拿完整历史凑数"];
    }
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest firstUnreadID:@""
        nativeUnread:nil revalidating:NO observedResult:observedQuery recentQuery:recentQuery earliestQuery:oldQuery diagnostics:window];
    [self check:history == nil && scanHistoryCalls == 0 reason:@"专用未读失败且边界缺失时，不能盲读旧历史"];
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest firstUnreadID:@""
        nativeUnread:@[] revalidating:YES observedResult:observedQuery recentQuery:recentQuery earliestQuery:oldQuery diagnostics:window];
    [self check:history.count == 1 && scanHistoryCalls == 1 reason:@"需撤销旧错误来源时仍保留历史反证读取"];
    scanHistoryCalls = 0;
    history = [DYYYIMHistoryReader historyForConversation:@"chat-A" latestMessage:latest firstUnreadID:[latest identifier]
        nativeUnread:nil revalidating:NO observedResult:observedQuery recentQuery:recentQuery earliestQuery:oldQuery diagnostics:window];
    [self check:history.count == 1 && scanHistoryCalls == 1 reason:@"专用未读失败但有确切边界时仍保留有界回退"];
    NSLog(@"DYYYIMHistoryReader regression tests passed");
}
@end

int main(void) {
    @autoreleasepool { [DYYYIMHistoryReaderTests run]; }
    return 0;
}
