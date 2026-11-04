#import <Foundation/Foundation.h>
#import "DYYYUnreadReadLearning.h"

@interface TIMXOMessage : NSObject
@end
@implementation TIMXOMessage
@end
@interface AWEIMMessage : NSObject
@end
@implementation AWEIMMessage
@end
@interface DYYYUnreadReadLearningTests : NSObject
@end
@implementation DYYYUnreadReadLearningTests
+ (void)check:(BOOL)condition reason:(NSString *)reason { if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason]; }
+ (void)run {
    DYYYUnreadReadLearning *learning = [DYYYUnreadReadLearning new];
    NSObject *root = [NSObject new], *conversation = [NSObject new], *receiver = [NSObject new];
    BOOL (^record)(NSString *, double) = ^BOOL(NSString *account, double time) {
        return [learning recordConversation:conversation receiver:receiver root:root account:account mode:17 shape:@"object" messageClass:TIMXOMessage.class at:time];
    };
    [self check:record(@"old", 100) && [learning pendingCountAt:101] == 1 reason:@"服务尚未绑定时保留真实原生调用事实"];
    [self check:[learning takeForRoot:[NSObject new] account:@"old" at:101].count == 0 reason:@"其他 SDK root 不得消费样本"];
    NSArray *samples = [learning takeForRoot:root account:@"old" at:102];
    [self check:samples.count == 1 && [samples[0][@"mode"] intValue] == 17 && [samples[0][@"shape"] isEqual:@"object"] reason:@"服务就绪后只回放同根同账号的实测参数"];
    [self check:[learning takeForRoot:root account:@"old" at:103].count == 0 reason:@"同一样本只消费一次"];
    record(@"old", 104);
    [self check:[learning takeForRoot:root account:@"new" at:105].count == 0 && [learning pendingCountAt:106] == 0 reason:@"同根切账号时丢弃旧账号，不误绑定新账号"];
    record(@"old", 110); record(@"old", 111);
    [self check:[learning pendingCountAt:111] == 1 reason:@"重复自然调用合并，容量不按调用次数增长"];
    [self check:[learning pendingCountAt:172] == 0 reason:@"60秒后过期，不永久保存陈旧调用"];
    [self check:![learning recordConversation:conversation receiver:receiver root:root account:@"old" mode:0 shape:@"object" messageClass:AWEIMMessage.class at:180] reason:@"UI 消息包装不能学习为 SDK 消息"];
    [self check:![learning recordConversation:conversation receiver:receiver root:root account:@"old" mode:0 shape:@"scalar" messageClass:TIMXOMessage.class at:180] reason:@"未知回调 ABI 不接受"];
    [self check:![learning recordConversation:conversation receiver:receiver root:nil account:@"old" mode:0 shape:@"object" messageClass:TIMXOMessage.class at:180] reason:@"根不明不得留样本"];
    [self check:![learning recordConversation:conversation receiver:receiver root:root account:nil mode:0 shape:@"object" messageClass:TIMXOMessage.class at:180] reason:@"账号不明不得跨启动推测"];
    NSMutableArray *owners = [NSMutableArray array];
    @autoreleasepool {
        for (NSUInteger i = 0; i < 30; i++) {
            NSObject *other = [NSObject new]; [owners addObject:other];
            [learning recordConversation:other receiver:receiver root:root account:@"old" mode:i shape:@"nil" messageClass:TIMXOMessage.class at:200];
        }
        [self check:[learning pendingCountAt:200] == 16 reason:@"最多16份待验证样本"];
        [owners removeAllObjects];
    }
    [self check:[learning pendingCountAt:201] == 0 reason:@"弱原生对象释放后自动淘汰，不延长 SDK 生命周期"];
    NSLog(@"DYYYUnreadReadLearning regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYUnreadReadLearningTests run]; } return 0; }
