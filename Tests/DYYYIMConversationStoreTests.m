#import <Foundation/Foundation.h>
#import "DYYYIMConversationStore.h"

int main(void) {
    @autoreleasepool {
        NSObject *rootA = [NSObject new], *rootB = [NSObject new];
        NSObject *a = [NSObject new], *b = [NSObject new];
        NSCAssert([DYYYIMConversationStore conversationForRoot:rootA identifier:@"same-chat"] == nil, @"缺失模型不能主动创建");
        [DYYYIMConversationStore capture:a root:rootA identifier:@"same-chat"];
        [DYYYIMConversationStore capture:b root:rootB identifier:@"same-chat"];
        NSCAssert([DYYYIMConversationStore conversationForRoot:rootA identifier:@"same-chat"] == a, @"不能串账户根");
        NSCAssert([DYYYIMConversationStore conversationForRoot:rootB identifier:@"same-chat"] == b, @"相同会话键也要隔离");
        __weak NSObject *weakModel;
        @autoreleasepool {
            NSObject *ephemeral = [NSObject new]; weakModel = ephemeral;
            [DYYYIMConversationStore capture:ephemeral root:rootA identifier:@"gone"];
        }
        NSCAssert(!weakModel && ![DYYYIMConversationStore conversationForRoot:rootA identifier:@"gone"], @"不能保活已释放的旧会话");
        [DYYYIMConversationStore observeCount:1 conversation:a source:@"test"];
        [DYYYIMConversationStore observeCount:159 conversation:a source:@"test"];
        [DYYYIMConversationStore observeCount:159 conversation:a source:@"test"];
        NSArray *events = [DYYYIMConversationStore diagnostics][@"unreadEvents"];
        NSCAssert(events.count == 1 && [events.lastObject[@"previous"] isEqual:@1] && [events.lastObject[@"count"] isEqual:@159], @"记录真实上涨，不把重复getter当新上涨");
        [DYYYIMConversationStore observeCount:159 conversation:b source:@"test"];
        events = [DYYYIMConversationStore diagnostics][@"unreadEvents"];
        NSCAssert([events.lastObject[@"kind"] isEqual:@"first_observed_large_count"], @"首次看到大数不能冒充记录到上涨");
        for (NSUInteger index = 0; index < 100; index++)
            [DYYYIMConversationStore observeCount:200 + index * 40 conversation:a source:@"test"];
        NSCAssert([[DYYYIMConversationStore diagnostics][@"unreadEvents"] count] == 32, @"异常记录必须有界");
        NSLog(@"DYYYIMConversationStore regression tests passed");
    }
    return 0;
}
