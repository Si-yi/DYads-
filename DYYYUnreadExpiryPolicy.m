#import "DYYYUnreadExpiryPolicy.h"
#import <objc/runtime.h>
#include <math.h>
#include <string.h>
#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#endif

struct DYYYExpiryBlockLayout { void *isa; int flags; int reserved; void *invoke; void *descriptor; };

@implementation DYYYUnreadExpiryPolicy
+ (NSNumber *)daysFromText:(id)text {
    if (![text isKindOfClass:NSString.class]) return nil;
    NSString *value = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!value.length) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)$" options:0 error:nil];
    if (![regex firstMatchInString:value options:0 range:NSMakeRange(0, value.length)]) return nil;
    double days = value.doubleValue;
    return isfinite(days) && days > 0 && days <= 36500 ? @(days) : nil;
}
+ (NSString *)completionShape:(id)block {
    if (!block) return @"nil";
    BOOL isBlock = NO;
    for (Class cls = object_getClass(block); cls; cls = class_getSuperclass(cls)) {
        if ([NSStringFromClass(cls) isEqualToString:@"NSBlock"]) { isBlock = YES; break; }
    }
    if (!isBlock) return nil;
    struct DYYYExpiryBlockLayout *layout = (__bridge struct DYYYExpiryBlockLayout *)block;
    if (!(layout->flags & (1 << 30)) || !layout->descriptor) return nil;
    void *descriptor = layout->descriptor;
#if __has_feature(ptrauth_calls)
    descriptor = ptrauth_strip(descriptor, ptrauth_key_process_independent_data);
#endif
    char *position = (char *)descriptor + 2 * sizeof(unsigned long);
    if (layout->flags & (1 << 25)) position += 2 * sizeof(void *);
    const char *encoding = NULL;
    memcpy(&encoding, position, sizeof(encoding));
#if __has_feature(ptrauth_calls)
    encoding = ptrauth_strip(encoding, ptrauth_key_process_independent_data);
#endif
    if (!encoding) return nil;
    @try {
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:encoding];
        if (strcmp(signature.methodReturnType, "v") || signature.numberOfArguments < 1 || signature.numberOfArguments > 3) return nil;
        if (strcmp([signature getArgumentTypeAtIndex:0], "@?")) return nil;
        for (NSUInteger index = 1; index < signature.numberOfArguments; index++)
            if ([signature getArgumentTypeAtIndex:index][0] != '@') return nil;
        return @[@"void", @"object", @"objects"][signature.numberOfArguments - 1];
    } @catch (__unused NSException *exception) { return nil; }
}
+ (NSDictionary *)planForFacts:(NSArray<NSDictionary *> *)facts nativeCount:(NSUInteger)count
                 conversation:(NSString *)conversation cutoff:(NSDate *)cutoff {
    NSDictionary *(^stop)(NSString *) = ^NSDictionary *(NSString *reason) { return @{ @"status":reason }; };
    if (![cutoff isKindOfClass:NSDate.class] || !conversation.length || !count || count > 4096 || ![facts isKindOfClass:NSArray.class]) return stop(@"invalid_or_oversized");
    NSMutableDictionary *unique = [NSMutableDictionary dictionary];
    for (id object in facts) {
        if (![object isKindOfClass:NSDictionary.class]) return stop(@"invalid_facts");
        NSDictionary *fact = object;
        NSString *identifier = fact[@"id"];
        if (![identifier isKindOfClass:NSString.class] || !identifier.length || ![fact[@"conversation"] isEqual:conversation]) return stop(@"wrong_conversation");
        NSNumber *order = fact[@"order"];
        if (![order isKindOfClass:NSNumber.class] || order.longLongValue <= 0) return stop(@"unknown_order");
        if (unique[identifier] && ![unique[identifier] isEqual:fact]) return stop(@"conflicting_message");
        unique[identifier] = fact;
    }
    if (unique.count != count) return stop(@"incomplete_native_unread");
    NSArray *ordered = [unique.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"order"] compare:b[@"order"]]; }];
    NSNumber *previous = nil;
    NSString *boundary = nil;
    NSUInteger expired = 0;
    for (NSDictionary *fact in ordered) {
        NSNumber *order = fact[@"order"];
        if (previous && [previous isEqual:order]) return stop(@"ambiguous_order");
        previous = order;
    }
    for (NSDictionary *fact in ordered) {
        NSDate *date = fact[@"date"];
        // 未知日期或近期消息阻断整个前缀，不允许越过它清理后面看似较旧的消息。
        if (![date isKindOfClass:NSDate.class] || !isfinite(date.timeIntervalSince1970) || date.timeIntervalSince1970 <= 0 || [date compare:cutoff] != NSOrderedAscending) break;
        boundary = fact[@"id"]; expired++;
    }
    return boundary ? @{ @"status":@"ready", @"boundary":boundary, @"expiredPrefixCount":@(expired), @"nativeCount":@(count) } : stop(@"no_safe_expired_prefix");
}
@end
