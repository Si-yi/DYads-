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
    return [self feedWithOriginal:original sharedModels:models orderedIDs:orderedIDs watchedIDs:[NSSet set] currentItemID:nil];
}
+ (NSArray *)feedWithOriginal:(NSArray *)original sharedModels:(NSDictionary *)models orderedIDs:(NSArray<NSString *> *)orderedIDs
                  watchedIDs:(NSSet<NSString *> *)watchedIDs currentItemID:(NSString *)currentItemID {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *itemID in orderedIDs) {
        if ([watchedIDs containsObject:itemID] && ![itemID isEqual:currentItemID]) continue;
        id model = models[itemID];
        if (!model || ![[self itemID:model] isEqual:itemID] || [seen containsObject:itemID]) continue;
        [result addObject:model]; [seen addObject:itemID];
    }
    for (id model in original) {
        NSString *itemID = [self itemID:model];
        if (itemID.length && [watchedIDs containsObject:itemID] && ![itemID isEqual:currentItemID]) continue;
        if (itemID.length && [seen containsObject:itemID]) continue;
        [result addObject:model]; if (itemID.length) [seen addObject:itemID];
    }
    return result;
}
+ (BOOL)replaceFeed:(NSArray *)feed controller:(id)controller {
    if (![feed isKindOfClass:NSArray.class] || !controller) return NO;
    @try {
        // updateAwemeList: 在 39.5 实测不会把新的 ID 加入数据源，不能用作整表替换。
        // 必须先验证两个入口，避免只更新 dataSource 而留下旧 filteredDataSource。
        SEL setter = NSSelectorFromString(@"setDataSource:");
        SEL calculate = NSSelectorFromString(@"calculateFilteredDataSource");
        NSMethodSignature *setSignature = [controller methodSignatureForSelector:setter];
        NSMethodSignature *calculateSignature = [controller methodSignatureForSelector:calculate];
        if (!setSignature || setSignature.numberOfArguments != 3 || strcmp(setSignature.methodReturnType, "v") != 0 ||
            strcmp([setSignature getArgumentTypeAtIndex:2], "@") != 0 || !calculateSignature ||
            calculateSignature.numberOfArguments != 2 || strcmp(calculateSignature.methodReturnType, "v") != 0) return NO;
        NSMutableArray *replacement = [feed mutableCopy];
        NSInvocation *setCall = [NSInvocation invocationWithMethodSignature:setSignature];
        setCall.target = controller; setCall.selector = setter;
        [setCall setArgument:&replacement atIndex:2]; [setCall invoke];
        NSInvocation *calculateCall = [NSInvocation invocationWithMethodSignature:calculateSignature];
        calculateCall.target = controller; calculateCall.selector = calculate;
        [calculateCall invoke];
        // YES 仅表示完成调用；服务仍必须回读两个列表，逐 ID 确认。
        return YES;
    } @catch (__unused NSException *exception) { return NO; }
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
