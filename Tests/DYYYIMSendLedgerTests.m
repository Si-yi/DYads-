#import <Foundation/Foundation.h>
#import "DYYYIMSendLedger.h"

@interface DYYYIMSendLedgerTests : NSObject
+ (void)run;
@end
@implementation DYYYIMSendLedgerTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *parts = [NSDateComponents new];
    parts.year = 2026; parts.month = 10; parts.day = 30; parts.hour = 12;
    NSDate *now = [calendar dateFromComponents:parts];
    NSDate *yesterday = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:now options:0];
    NSDictionary *sent = @{ @"confirmed": @YES, @"manualTest": @NO, @"senderID": @"100", @"sentAt": now };
    NSString *key = [DYYYIMSendLedger keyForAccount:@"100" peer:@"200" date:now calendar:calendar];
    [self check:[key isEqual:@"100/2026-10-30/200"] reason:@"账户、日期、好友共同确定记录"];
    NSDictionary *prior = @{ @"100/2026-10-29/200": @YES, @"300/2026-10-30/200": @YES, @"broken": @YES };
    NSDictionary *records = [DYYYIMSendLedger recordsByObservingOutgoing:sent account:@"100" peer:@"200" now:now calendar:calendar records:prior];
    [self check:[records[key] boolValue] && [records[@"300/2026-10-30/200"] boolValue] reason:@"记录成功回执，保留其他账户当天记录"];
    [self check:!records[@"100/2026-10-29/200"] && !records[@"broken"] reason:@"过期与非法记录清理"];
    [self check:prior.count == 3 reason:@"原始记录不改写"];
    for (NSDictionary *change in @[ @{ @"manualTest": @YES }, @{ @"confirmed": @NO }, @{ @"senderID": @"200" }, @{ @"sentAt": yesterday }, @{ @"sentAt": NSNull.null }, @{ @"manualTest": NSNull.null } ]) {
        NSMutableDictionary *facts = sent.mutableCopy;
        [facts addEntriesFromDictionary:change];
        [self check:[DYYYIMSendLedger recordsByObservingOutgoing:facts account:@"100" peer:@"200" now:now calendar:calendar records:records] == records reason:@"测试发送、失败、收到的消息或旧消息均不新增记录"];
    }
    [self check:[DYYYIMSendLedger recordsByObservingOutgoing:sent account:@"300" peer:@"200" now:now calendar:calendar records:records] == records reason:@"账户不匹配不串账"];
    [self check:[DYYYIMSendLedger keyForAccount:@"100" peer:@"100" date:now calendar:calendar] == nil reason:@"自己与非法ID拒绝"];
    [self check:[DYYYIMSendLedger keyForAccount:@"100" peer:@"20/0" date:now calendar:calendar] == nil reason:@"不能向记录键注入分隔符"];
    [self check:![[DYYYIMSendLedger keyForAccount:@"100" peer:@"200" date:yesterday calendar:calendar] isEqual:key] reason:@"跨天不复用当天键"];
    NSCalendar *local = calendar.copy;
    local.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:8 * 3600];
    NSMutableDictionary *localFacts = sent.mutableCopy;
    localFacts[@"sentAt"] = [calendar dateByAddingUnit:NSCalendarUnitHour value:-17 toDate:now options:0];
    NSDictionary *localRecords = [DYYYIMSendLedger recordsByObservingOutgoing:localFacts account:@"100" peer:@"200" now:now calendar:local records:@{}];
    [self check:[localRecords[@"100/2026-10-30/200"] boolValue] reason:@"当地日期决定当天，不能误用UTC切日"];
    NSDictionary *again = [DYYYIMSendLedger recordsByObservingOutgoing:sent account:@"100" peer:@"200" now:now calendar:calendar records:records];
    [self check:[again isEqual:records] reason:@"重复回执不重复增加记录"];
    // 仅本机回执事实，无任何历史 provider 或 SDK 依赖。
    NSLog(@"DYYYIMSendLedger regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYIMSendLedgerTests run]; } return 0; }
