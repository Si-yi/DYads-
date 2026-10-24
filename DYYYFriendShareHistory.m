#import "DYYYFriendShareHistory.h"
#include <math.h>

@interface DYYYFriendShareHistory ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, copy) NSString *pendingKey;
@property (nonatomic, copy) NSString *watchedKey;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *order;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *rows;
@property (nonatomic, strong) NSMutableSet<NSString *> *watched;
@property (nonatomic, copy) NSString *playingID;
@property (nonatomic) NSTimeInterval lastTime;
@property (nonatomic) BOOL progressed;
@property (nonatomic, copy) NSString *draggedID;
@property (nonatomic) BOOL draggedProgressed;
@end

@implementation DYYYFriendShareHistory
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults account:(NSString *)account {
    if (!(self = [super init])) return nil;
    if (!account.length) return nil;
    _defaults = defaults;
    _pendingKey = [@"DYYYFriendSharePendingItems." stringByAppendingString:account];
    _watchedKey = [@"DYYYFriendShareWatchedItemIDs." stringByAppendingString:account];
    _order = [NSMutableOrderedSet orderedSet];
    _rows = [NSMutableDictionary dictionary];
    _watched = [NSMutableSet set];
    id watched = [defaults objectForKey:_watchedKey];
    if ([watched isKindOfClass:NSArray.class]) for (id itemID in watched)
        if ([itemID isKindOfClass:NSString.class] && [itemID length]) [_watched addObject:itemID];
    id pending = [defaults objectForKey:_pendingKey];
    if ([pending isKindOfClass:NSArray.class]) [self mergeRows:pending];
    return self;
}
- (NSArray<NSDictionary *> *)pendingRows {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.order.count];
    for (NSString *itemID in self.order) if (self.rows[itemID]) [result addObject:self.rows[itemID]];
    return result;
}
- (NSSet<NSString *> *)watchedItemIDs { return [self.watched copy]; }
- (NSDictionary *)diagnostics {
    return @{ @"pendingCount": @(self.order.count), @"watchedCount": @(self.watched.count),
              @"playingID": self.playingID ?: @"", @"lastTime": @(self.lastTime), @"progressed": @(self.progressed),
              @"draggedID": self.draggedID ?: @"", @"draggedProgressed": @(self.draggedProgressed) };
}
- (void)savePending { [self.defaults setObject:self.pendingRows forKey:self.pendingKey]; }
- (void)mergeRows:(NSArray<NSDictionary *> *)rows {
    BOOL changed = NO;
    for (id value in rows) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        NSString *itemID = value[@"itemID"];
        if (![itemID isKindOfClass:NSString.class] || !itemID.length || [self.watched containsObject:itemID]) continue;
        NSMutableDictionary *row = [self.rows[itemID] mutableCopy] ?: [@{ @"itemID": itemID } mutableCopy];
        for (NSString *key in @[ @"friendID", @"name", @"avatar" ])
            if ([value[key] isKindOfClass:NSString.class] && [value[key] length]) row[key] = value[key];
        if (!row[@"collectedAt"] && [value[@"collectedAt"] isKindOfClass:NSNumber.class]) row[@"collectedAt"] = value[@"collectedAt"];
        if ([self.rows[itemID] isEqual:row]) continue;
        self.rows[itemID] = row;
        [self.order addObject:itemID];
        changed = YES;
    }
    if (changed) [self savePending];
}
- (void)importLegacySources:(NSDictionary *)sources {
    NSMutableArray *legacy = [NSMutableArray array];
    for (id itemID in sources) {
        if (![itemID isKindOfClass:NSString.class] || ![sources[itemID] isKindOfClass:NSDictionary.class]) continue;
        NSMutableDictionary *row = [sources[itemID] mutableCopy];
        row[@"itemID"] = itemID;
        [legacy addObject:row];
    }
    [legacy sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSNumber *ta = [a[@"collectedAt"] isKindOfClass:NSNumber.class] ? a[@"collectedAt"] : @0;
        NSNumber *tb = [b[@"collectedAt"] isKindOfClass:NSNumber.class] ? b[@"collectedAt"] : @0;
        NSComparisonResult order = [ta compare:tb];
        return order == NSOrderedSame ? [a[@"itemID"] compare:b[@"itemID"]] : order;
    }];
    [self mergeRows:legacy];
}
- (void)consumeItemID:(NSString *)itemID {
    if (!self.rows[itemID] || [self.watched containsObject:itemID]) return;
    [self.watched addObject:itemID];
    // 先写已刷，再删待刷；中断后恢复时也不会把已刷项目重新入队。
    [self.defaults setObject:self.watched.allObjects forKey:self.watchedKey];
    [self.order removeObject:itemID];
    [self.rows removeObjectForKey:itemID];
    [self savePending];
}
- (void)clearWatched {
    [self.watched removeAllObjects];
    [self.defaults removeObjectForKey:self.watchedKey];
    [self resetPlayback];
}
- (void)recordPlaybackForItemID:(NSString *)itemID time:(NSTimeInterval)time {
    if (!itemID.length || !isfinite(time) || time < 0) return;
    if (![itemID isEqual:self.playingID]) {
        self.playingID = itemID;
        self.lastTime = time;
        self.progressed = NO;
        return;
    }
    // 至少观察到两次递增的时间，单次缓存时间、首帧或播放请求不能算刷过。
    if (time > self.lastTime + 0.02) self.progressed = YES;
    self.lastTime = time;
}
- (void)beginDraggingFromItemID:(NSString *)itemID {
    self.draggedID = itemID;
    self.draggedProgressed = [itemID isEqual:self.playingID] && self.progressed;
}
- (NSString *)finishDraggingToItemID:(NSString *)itemID {
    NSString *finished = self.draggedID;
    BOOL consumed = finished.length && itemID.length && ![finished isEqual:itemID] && self.draggedProgressed && self.rows[finished];
    self.draggedID = nil;
    self.draggedProgressed = NO;
    if (consumed) { [self consumeItemID:finished]; return finished; }
    return nil;
}
- (BOOL)completeLoopForItemID:(NSString *)itemID {
    if (!itemID.length || ![itemID isEqual:self.playingID] || !self.progressed || !self.rows[itemID]) return NO;
    [self consumeItemID:itemID];
    return YES;
}
- (void)resetPlayback {
    self.playingID = nil; self.lastTime = 0; self.progressed = NO;
    self.draggedID = nil; self.draggedProgressed = NO;
}
@end
