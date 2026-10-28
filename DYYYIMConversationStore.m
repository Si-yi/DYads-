#import "DYYYIMConversationStore.h"

@implementation DYYYIMConversationStore
+ (NSMapTable *)roots {
    static NSMapTable *map; static dispatch_once_t once;
    dispatch_once(&once, ^{ map = [NSMapTable weakToStrongObjectsMapTable]; });
    return map;
}
+ (NSMapTable *)counts {
    static NSMapTable *map; static dispatch_once_t once;
    dispatch_once(&once, ^{ map = [NSMapTable weakToStrongObjectsMapTable]; });
    return map;
}
+ (NSMutableArray *)events {
    static NSMutableArray *events; static dispatch_once_t once;
    dispatch_once(&once, ^{ events = [NSMutableArray array]; });
    return events;
}
+ (void)capture:(id)conversation root:(id)root identifier:(NSString *)identifier {
    if (!conversation || !root || ![identifier isKindOfClass:NSString.class] || !identifier.length) return;
    @synchronized(self) {
        NSMapTable *map = [[self roots] objectForKey:root];
        if (!map) {
            map = [NSMapTable strongToWeakObjectsMapTable];
            [[self roots] setObject:map forKey:root];
        }
        // 限制每个账户根的键数量，不保留所有历史会话的 ID。
        if (map.count >= 1024 && ![map objectForKey:identifier]) {
            for (id key in map.keyEnumerator.allObjects) if (![map objectForKey:key]) [map removeObjectForKey:key];
            if (map.count >= 1024) return;
        }
        [map setObject:conversation forKey:identifier];
    }
}
+ (id)conversationForRoot:(id)root identifier:(NSString *)identifier {
    if (!root || !identifier.length) return nil;
    @synchronized(self) { return [[[self roots] objectForKey:root] objectForKey:identifier]; }
}
+ (void)observeCount:(unsigned long long)count conversation:(id)conversation source:(NSString *)source {
    if (!conversation) return;
    @synchronized(self) {
        NSNumber *previous = [[self counts] objectForKey:conversation];
        if (previous && previous.unsignedLongLongValue == count) return;
        [[self counts] setObject:@(count) forKey:conversation];
        BOOL rise = previous && count > previous.unsignedLongLongValue && count - previous.unsignedLongLongValue >= 32;
        if (!rise && (previous || count < 32)) return;
        // 仅异常上涨/首次看到大计数才取栈。只记计数、SDK 调用位置，不记聊天内容或账户 ID。
        NSArray *stack = NSThread.callStackSymbols;
        NSMutableArray *events = [self events];
        [events addObject:@{ @"kind": rise ? @"observed_rise" : @"first_observed_large_count",
            @"previous": previous ?: NSNull.null, @"count": @(count), @"source": source ?: @"",
            @"uptime": @(NSProcessInfo.processInfo.systemUptime),
            @"stack": [stack subarrayWithRange:NSMakeRange(0, MIN(stack.count, 14))] }];
        if (events.count > 32) [events removeObjectsInRange:NSMakeRange(0, events.count - 32)];
    }
}
+ (NSDictionary *)diagnostics {
    @synchronized(self) {
        NSUInteger count = 0;
        for (NSMapTable *map in [self roots].objectEnumerator) count += map.objectEnumerator.allObjects.count;
        return @{ @"lookup": @"passively_observed_only", @"liveConversations": @(count), @"unreadEvents": [[self events] copy] };
    }
}
@end
