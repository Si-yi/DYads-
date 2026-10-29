#import <Foundation/Foundation.h>
#import "DYYYIMConversationStore.h"

// SDK 根可能实现需要进入内部队列的 hash/isEqual:，缓存不能调用它们。
@interface DYYYStoreLockSensitiveRoot : NSObject
@end
@implementation DYYYStoreLockSensitiveRoot
- (NSUInteger)hash { [NSException raise:@"SDKHashCalled" format:@"不得在缓存锁内调用 SDK hash"]; return 0; }
- (BOOL)isEqual:(id)object { [NSException raise:@"SDKEqualityCalled" format:@"不得调用 SDK equality"]; return NO; }
@end

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
        DYYYStoreLockSensitiveRoot *sensitiveRoot = [DYYYStoreLockSensitiveRoot new];
        [DYYYIMConversationStore capture:a root:sensitiveRoot identifier:@"safe-key"];
        NSCAssert([DYYYIMConversationStore conversationForRoot:sensitiveRoot identifier:@"safe-key"] == a, @"根按指针身份匹配，不进入SDK对象锁");
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
        for (NSUInteger index = 0; index < 100; index++) {
            dispatch_group_async(group, queue, ^{
                [DYYYIMConversationStore capture:a root:sensitiveRoot identifier:@"parallel"];
                NSCAssert([DYYYIMConversationStore conversationForRoot:sensitiveRoot identifier:@"parallel"] == a, @"并发读写保持同一模型");
                [DYYYIMConversationStore diagnostics];
            });
        }
        NSCAssert(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, @"并发缓存操作不能互锁");
        NSLog(@"DYYYIMConversationStore regression tests passed");
    }
    return 0;
}
