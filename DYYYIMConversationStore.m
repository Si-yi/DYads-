#import "DYYYIMConversationStore.h"

@implementation DYYYIMConversationStore
+ (NSMapTable *)roots {
    static NSMapTable *map; static dispatch_once_t once;
    dispatch_once(&once, ^{ map = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsOpaquePersonality
            valueOptions:NSPointerFunctionsStrongMemory]; });
    return map;
}
+ (void)observeNativeConversation:(id)conversation root:(id)root identifier:(NSString *)identifier {
    if (!conversation || !root) return;
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.dyyy.observed-conversations", DISPATCH_QUEUE_SERIAL); });
    __weak id weakConversation = conversation, weakRoot = root;
    NSString *key = [identifier isKindOfClass:NSString.class] ? [identifier copy] : nil;
    // 原生工厂/SDK 锁内不访问模型、不取栈、不争用插件缓存锁；返回后异步补充弱缓存。
    dispatch_async(queue, ^{
        id model = weakConversation, owner = weakRoot;
        if (!model || !owner) return;
        NSString *resolved = key;
        if (!resolved) {
            @try { resolved = [model valueForKey:@"identifier"]; }
            @catch (__unused NSException *exception) { return; }
        }
        [self capture:model root:owner identifier:resolved];
    });
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
+ (NSDictionary *)diagnostics {
    @synchronized(self) {
        NSUInteger count = 0;
        for (NSMapTable *map in [self roots].objectEnumerator) count += map.count;
        return @{ @"lookup": @"passively_observed_async", @"cachedSlots": @(count),
            @"unreadObserverEnabled": @NO };
    }
}
@end
