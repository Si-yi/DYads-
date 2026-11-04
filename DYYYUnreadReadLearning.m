#import "DYYYUnreadReadLearning.h"
#import "DYYYUnreadExpiryPolicy.h"
#import <math.h>

@interface DYYYUnreadReadSample : NSObject
@property (nonatomic, weak) id conversation;
@property (nonatomic, weak) id receiver;
@property (nonatomic, weak) id root;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *shape;
@property (nonatomic) Class messageClass;
@property (nonatomic) unsigned long long mode;
@property (nonatomic) NSTimeInterval time;
@end
@implementation DYYYUnreadReadSample
@end

@interface DYYYUnreadReadLearning ()
@property (nonatomic, strong) NSMutableArray<DYYYUnreadReadSample *> *pending;
@end
@implementation DYYYUnreadReadLearning
- (instancetype)init {
    if ((self = [super init])) _pending = [NSMutableArray array];
    return self;
}
- (void)pruneAt:(NSTimeInterval)time {
    NSIndexSet *expired = [self.pending indexesOfObjectsPassingTest:^BOOL(DYYYUnreadReadSample *sample, NSUInteger index, BOOL *stop) {
        return !isfinite(time) || !sample.root || !sample.conversation || !sample.receiver || time < sample.time || time - sample.time > 60;
    }];
    [self.pending removeObjectsAtIndexes:expired];
}
- (BOOL)recordConversation:(id)conversation receiver:(id)receiver root:(id)root account:(NSString *)account
                     mode:(unsigned long long)mode shape:(NSString *)shape messageClass:(Class)messageClass at:(NSTimeInterval)time {
    [self pruneAt:time];
    if (!conversation || !receiver || !root || ![account isKindOfClass:NSString.class] || !account.length || !isfinite(time) ||
        ![@[@"nil", @"void", @"object", @"objects"] containsObject:shape ?: @""] || ![DYYYUnreadExpiryPolicy isNativeMessageClass:messageClass]) return NO;
    for (DYYYUnreadReadSample *sample in self.pending) {
        if (sample.root == root && sample.conversation == conversation && sample.receiver == receiver && [sample.account isEqual:account]) {
            sample.mode = mode; sample.shape = shape; sample.messageClass = messageClass; sample.time = time;
            return YES;
        }
    }
    if (self.pending.count >= 16) [self.pending removeObjectAtIndex:0];
    DYYYUnreadReadSample *sample = [DYYYUnreadReadSample new];
    sample.conversation = conversation; sample.receiver = receiver; sample.root = root; sample.account = account;
    sample.mode = mode; sample.shape = shape; sample.messageClass = messageClass; sample.time = time;
    [self.pending addObject:sample];
    return YES;
}
- (NSArray<NSDictionary *> *)takeForRoot:(id)root account:(NSString *)account at:(NSTimeInterval)time {
    [self pruneAt:time];
    if (!root || !account.length) return @[];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableIndexSet *taken = [NSMutableIndexSet indexSet];
    [self.pending enumerateObjectsUsingBlock:^(DYYYUnreadReadSample *sample, NSUInteger index, BOOL *stop) {
        if (sample.root != root) return;
        // 同一 SDK root 被重新配置到其他账号时，旧样本直接丢弃，不能改绑新账号。
        [taken addIndex:index];
        if (![sample.account isEqual:account]) return;
        id conversation = sample.conversation, receiver = sample.receiver;
        if (!conversation || !receiver) return;
        [result addObject:@{@"conversation": conversation, @"receiver": receiver, @"root": root, @"account": account,
            @"mode": @(sample.mode), @"shape": sample.shape, @"messageClass": NSStringFromClass(sample.messageClass)}];
    }];
    [self.pending removeObjectsAtIndexes:taken];
    return result;
}
- (NSUInteger)pendingCountAt:(NSTimeInterval)time { [self pruneAt:time]; return self.pending.count; }
@end
