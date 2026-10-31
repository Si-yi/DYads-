#import <Foundation/Foundation.h>
#import "DYYYUnreadExpiryPolicy.h"

@interface DYYYUnreadExpiryPolicyTests : NSObject
+ (void)run;
@end
@implementation DYYYUnreadExpiryPolicyTests
+ (void)check:(BOOL)value reason:(NSString *)reason {
    if (!value) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (NSDictionary *)fact:(NSString *)identifier order:(NSInteger)order date:(id)date {
    return @{ @"id":identifier, @"conversation":@"100", @"order":@(order), @"date":date };
}
+ (NSDictionary *)plan:(NSArray *)facts count:(NSUInteger)count cutoff:(NSDate *)cutoff {
    return [DYYYUnreadExpiryPolicy planForFacts:facts nativeCount:count conversation:@"100" cutoff:cutoff];
}
+ (void)run {
    [self check:[[DYYYUnreadExpiryPolicy daysFromText:@" 7 "] isEqual:@7] reason:@"填写7保留最近7天"];
    [self check:[[DYYYUnreadExpiryPolicy daysFromText:@"0.5"] isEqual:@0.5] reason:@"小数天数可表达小时范围"];
    for (id value in @[@"", @" ", @"0", @"-1", @"NaN", @"inf", @"1e2", @"7天", @"1,5", @"36501", @7, NSNull.null])
        [self check:![DYYYUnreadExpiryPolicy daysFromText:value] reason:@"空值使用原生，非法时限不得开启清理"];
    NSDate *cutoff = [NSDate dateWithTimeIntervalSince1970:1800000000];
    NSDate *old = [cutoff dateByAddingTimeInterval:-100], *fresh = [cutoff dateByAddingTimeInterval:100];
    NSDictionary *a = [self fact:@"a" order:1 date:old], *b = [self fact:@"b" order:2 date:old], *c = [self fact:@"c" order:3 date:fresh];
    NSArray *facts = @[c, a, b]; NSArray *prior = facts.copy;
    NSDictionary *plan = [self plan:facts count:3 cutoff:cutoff];
    [self check:[plan[@"boundary"] isEqual:@"b"] && [plan[@"expiredPrefixCount"] intValue] == 2 reason:@"按原生顺序选择最后一条超时消息，近期消息不纳入边界"];
    [self check:[facts isEqual:prior] reason:@"输入事实不改写"];
    [self check:![[self plan:@[a,c] count:3 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"部分未读明细不能拿来清理"];
    [self check:![[self plan:@[a,a,c] count:3 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"重复消息不能伪装完整集合"];
    [self check:[[self plan:@[a,b,c,b] count:3 cutoff:cutoff][@"boundary"] isEqual:@"b"] reason:@"不同提示类型重叠消息去重"];
    [self check:![[self plan:@[[self fact:@"a" order:1 date:fresh],b] count:2 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"时间乱序不能跨过近期未读清理后方旧消息"];
    [self check:![[self plan:@[[self fact:@"a" order:1 date:NSNull.null],b] count:2 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"未知时间阻断前缀"];
    [self check:![[self plan:@[[self fact:@"a" order:1 date:cutoff]] count:1 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"截止时间恰好相等仍保留"];
    [self check:![[self plan:@[[self fact:@"a" order:1 date:[NSDate dateWithTimeIntervalSince1970:0]]] count:1 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"无效零时间不能当作旧消息"];
    [self check:![[self plan:@[a,[self fact:@"b" order:1 date:old]] count:2 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"原生顺序相同但ID不同不能确定边界"];
    NSMutableDictionary *foreign = b.mutableCopy; foreign[@"conversation"] = @"200";
    [self check:![[self plan:@[a,foreign] count:2 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"不串会话"];
    [self check:![[self plan:facts count:5000 cutoff:cutoff][@"status"] isEqual:@"ready"] reason:@"大未读会话不上无限查询"];
    [self check:[[DYYYUnreadExpiryPolicy completionShape:nil] isEqual:@"nil"] reason:@"只接受真实观察到的空回调"];
    [self check:[[DYYYUnreadExpiryPolicy completionShape:^{ }] isEqual:@"void"] reason:@"确认无参数回调ABI"];
    [self check:[[DYYYUnreadExpiryPolicy completionShape:^(id object) { }] isEqual:@"object"] reason:@"确认一个对象参数回调ABI"];
    [self check:[[DYYYUnreadExpiryPolicy completionShape:^(id first, id second) { }] isEqual:@"objects"] reason:@"确认两个对象参数回调ABI"];
    [self check:![DYYYUnreadExpiryPolicy completionShape:^(BOOL value) { }] reason:@"标量回调不可当对象调用"];
    [self check:![DYYYUnreadExpiryPolicy completionShape:[NSObject new]] reason:@"普通对象不可按block内存读取"];
    NSLog(@"DYYYUnreadExpiryPolicy regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYUnreadExpiryPolicyTests run]; } return 0; }
