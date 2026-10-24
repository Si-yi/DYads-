#import "DYYYFriendShareDelivery.h"
#include <string.h>

@implementation DYYYFriendShareDelivery
+ (NSString *)itemID:(id)model {
    @try {
        id value = [model valueForKey:@"itemID"];
        return [value isKindOfClass:NSString.class] ? value : ([value isKindOfClass:NSNumber.class] ? [value stringValue] : nil);
    } @catch (__unused NSException *exception) { return nil; }
}
+ (NSArray *)feedWithOriginal:(NSArray *)original sharedModels:(NSDictionary *)models orderedIDs:(NSArray<NSString *> *)orderedIDs {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *itemID in orderedIDs) {
        id model = models[itemID];
        if (!model || ![[self itemID:model] isEqual:itemID] || [seen containsObject:itemID]) continue;
        [result addObject:model]; [seen addObject:itemID];
    }
    for (id model in original) {
        NSString *itemID = [self itemID:model];
        if (itemID.length && [seen containsObject:itemID]) continue;
        [result addObject:model]; if (itemID.length) [seen addObject:itemID];
    }
    return result;
}
+ (BOOL)prepareAndPlayCell:(id)cell itemID:(NSString *)itemID allowed:(BOOL)allowed {
    if (!allowed || !cell || !itemID.length) return NO;
    @try {
        if (![[self itemID:[cell valueForKey:@"model"]] isEqual:itemID]) return NO;
        // 39.5.0 AWEFeedCellViewController 的两个入口均为 void、无参数。
        // 两个签名先一起确认，不能只调用到准备的一半。
        NSArray *names = @[ @"prepareForDisplay", @"play" ];
        for (NSString *name in names) {
            NSMethodSignature *signature = [cell methodSignatureForSelector:NSSelectorFromString(name)];
            if (!signature || signature.numberOfArguments != 2 || strcmp(signature.methodReturnType, "v") != 0) return NO;
        }
        for (NSString *name in names) {
            SEL selector = NSSelectorFromString(name);
            NSInvocation *call = [NSInvocation invocationWithMethodSignature:[cell methodSignatureForSelector:selector]];
            call.target = cell; call.selector = selector;
            [call invoke];
        }
        return YES;
    } @catch (__unused NSException *exception) { return NO; }
}
@end
