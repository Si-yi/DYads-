#import <Foundation/Foundation.h>
#import "DYYYFriendShareHistory.h"

@interface DYYYFriendShareHistoryTests : NSObject
+ (void)run;
@end
@implementation DYYYFriendShareHistoryTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (NSArray *)rowsFrom:(NSUInteger)start count:(NSUInteger)count {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSUInteger i = start; i < start + count; i++) [rows addObject:@{
        @"itemID": [NSString stringWithFormat:@"video-%lu", (unsigned long)i], @"friendID": @"friend-A",
        @"name": @"好友", @"avatar": @"", @"collectedAt": @(i) }];
    return rows;
}
+ (void)play:(NSString *)itemID in:(DYYYFriendShareHistory *)history {
    [history recordPlaybackForItemID:itemID time:0.1];
    [history recordPlaybackForItemID:itemID time:0.3];
}
+ (void)run {
    NSString *suite = [@"com.dyyy.share-history-tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    @try {
        DYYYFriendShareHistory *history = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"A"];
        [history mergeRows:[self rowsFrom:0 count:10]];
        [self check:history.pendingRows.count == 10 && history.watchedItemIDs.count == 0 reason:@"获取或推送十条不等于刷过十条"];
        // 用户实际刷走前三条，离开应用后只应恢复后七条。
        for (NSUInteger i = 0; i < 3; i++) {
            NSString *itemID = [NSString stringWithFormat:@"video-%lu", (unsigned long)i];
            [self play:itemID in:history];
            [history beginDraggingFromItemID:itemID];
            [self check:[[history finishDraggingToItemID:[NSString stringWithFormat:@"video-%lu", (unsigned long)(i + 1)]] isEqual:itemID] reason:@"真实播放后垂直滑走才消费"];
        }
        [history resetPlayback];
        history = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"A"];
        [self check:history.pendingRows.count == 7 && history.watchedItemIDs.count == 3 reason:@"重建实例必须恢复七条未刷"];
        [self check:[history.pendingRows.firstObject[@"itemID"] isEqual:@"video-3"] reason:@"保留未刷的原顺序"];
        [history mergeRows:[self rowsFrom:10 count:2]];
        [history mergeRows:[self rowsFrom:0 count:12]];
        [self check:history.pendingRows.count == 9 reason:@"七条未刷加两条新分享，重复扫描不能复活已刷或生成重复项"];
        // 只搜索/退后台、单个缓存进度、卡在首帧、取消滑动均不能消费。
        [history recordPlaybackForItemID:@"video-3" time:0];
        [history recordPlaybackForItemID:@"video-3" time:0];
        [history beginDraggingFromItemID:@"video-3"];
        [self check:[history finishDraggingToItemID:@"video-4"] == nil reason:@"卡首帧后切走仍保留"];
        [history resetPlayback];
        [history recordPlaybackForItemID:@"video-3" time:5];
        [self check:![history completeLoopForItemID:@"video-3"] reason:@"单个缓存时间不能伪装完成播放"];
        [history resetPlayback];
        [self play:@"video-3" in:history];
        [history beginDraggingFromItemID:@"video-3"];
        [self check:[history finishDraggingToItemID:@"video-3"] == nil reason:@"取消滑动仍是同一条，不能消费"];
        [history resetPlayback];
        [self check:![history completeLoopForItemID:@"video-3"] && history.pendingRows.count == 9 reason:@"导航去搜索或退出不能沿用旧播放证明"];
        // 播完最后一条后直接退出，也必须保存已刷，不要求再滑一下。
        [self play:@"video-3" in:history];
        [self check:[history completeLoopForItemID:@"video-3"] reason:@"真实播放完成一轮可直接消费"];
        history = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"A"];
        [self check:history.pendingRows.count == 8 && [history.watchedItemIDs containsObject:@"video-3"] reason:@"播放完成结果必须跨实例保存"];
        for (NSDictionary *row in [history.pendingRows copy]) {
            [self play:row[@"itemID"] in:history];
            [history completeLoopForItemID:row[@"itemID"]];
        }
        [self check:history.pendingRows.count == 0 reason:@"本轮刷完后下次不能重复推送"];
        [history mergeRows:[self rowsFrom:0 count:12]];
        [self check:history.pendingRows.count == 0 reason:@"聊天仍未读不等于首页没刷过"];
        // 切账户隔离；模型加载失败不触碰持久待刷队列。
        DYYYFriendShareHistory *other = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"B"];
        [other mergeRows:[self rowsFrom:0 count:10]];
        [self check:other.pendingRows.count == 10 && other.watchedItemIDs.count == 0 reason:@"账户 B 不能继承账户 A 的已刷"];
        other = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"B"];
        [self check:other.pendingRows.count == 10 reason:@"未加载/未插入的项目也要恢复"];
        // 升级时从旧来源缓存恢复未刷，不要求聊天还未读。
        [defaults setObject:@[ @"video-0", @"video-1", @"video-2" ] forKey:@"DYYYFriendShareWatchedItemIDs.C"];
        NSMutableDictionary *legacy = [NSMutableDictionary dictionary];
        for (NSDictionary *row in [self rowsFrom:0 count:10]) legacy[row[@"itemID"]] = row;
        DYYYFriendShareHistory *migrated = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"C"];
        [migrated importLegacySources:legacy];
        [self check:migrated.pendingRows.count == 7 reason:@"迁移旧版本来源时恢复七条，排除已刷三条"];
        [migrated mergeRows:[self rowsFrom:10 count:300]];
        migrated = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"C"];
        [self check:migrated.pendingRows.count == 307 reason:@"待刷不能随 256 条来源缓存上限丢失"];
        NSLog(@"DYYYFriendShareHistory regression tests passed");
    } @finally { [defaults removePersistentDomainForName:suite]; }
}
@end
int main(void) {
    @autoreleasepool { [DYYYFriendShareHistoryTests run]; }
    return 0;
}
