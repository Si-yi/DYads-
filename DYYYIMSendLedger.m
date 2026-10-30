#import "DYYYIMSendLedger.h"

@implementation DYYYIMSendLedger
+ (BOOL)validID:(NSString *)value {
    return [value isKindOfClass:NSString.class] && value.length && value.longLongValue > 0 &&
        [value rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
}
+ (NSString *)keyForAccount:(NSString *)account peer:(NSString *)peer date:(NSDate *)date calendar:(NSCalendar *)calendar {
    if (![self validID:account] || ![self validID:peer] || account.longLongValue == peer.longLongValue || ![date isKindOfClass:NSDate.class] || !calendar) return nil;
    NSDateComponents *day = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    return [NSString stringWithFormat:@"%@/%04ld-%02ld-%02ld/%@", account, (long)day.year, (long)day.month, (long)day.day, peer];
}
+ (NSDictionary *)recordsByObservingOutgoing:(NSDictionary *)facts account:(NSString *)account peer:(NSString *)peer
                                        now:(NSDate *)now calendar:(NSCalendar *)calendar records:(NSDictionary *)records {
    NSDictionary *original = [records isKindOfClass:NSDictionary.class] ? records : @{};
    if (![facts isKindOfClass:NSDictionary.class] || ![facts[@"confirmed"] isKindOfClass:NSNumber.class] || ![facts[@"confirmed"] boolValue] ||
        (facts[@"manualTest"] && ![facts[@"manualTest"] isKindOfClass:NSNumber.class]) || [facts[@"manualTest"] boolValue] ||
        ![facts[@"senderID"] isKindOfClass:NSString.class] || ![facts[@"senderID"] isEqual:account] ||
        ![facts[@"sentAt"] isKindOfClass:NSDate.class] || ![now isKindOfClass:NSDate.class] || !calendar ||
        ![calendar isDate:facts[@"sentAt"] inSameDayAsDate:now]) return original;
    NSString *key = [self keyForAccount:account peer:peer date:now calendar:calendar];
    if (!key) return original;
    NSString *today = [key componentsSeparatedByString:@"/"][1];
    NSMutableDictionary *updated = [NSMutableDictionary dictionary];
    for (id old in original) {
        if (![old isKindOfClass:NSString.class]) continue;
        NSArray *parts = [old componentsSeparatedByString:@"/"];
        if (parts.count == 3 && [parts[1] isEqual:today] && [self validID:parts[0]] && [self validID:parts[2]] &&
            [original[old] isKindOfClass:NSNumber.class] && [original[old] boolValue]) updated[old] = @YES;
    }
    updated[key] = @YES;
    return updated.copy;
}
@end
