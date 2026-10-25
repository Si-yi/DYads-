#import "DYYYIMShareParser.h"

@implementation DYYYIMShareParser
+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}
+ (id)decodedContent:(id)content {
    if ([content isKindOfClass:NSString.class] && [content length] <= 65536) {
        NSString *text = [content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (![text hasPrefix:@"{"] && ![text hasPrefix:@"["]) return nil;
        NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
        return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    }
    return content;
}
+ (NSString *)itemID:(id)value {
    NSString *text = [value isKindOfClass:NSString.class] ? value :
        ([value isKindOfClass:NSNumber.class] ? [value stringValue] : nil);
    if (text.length < 8 || text.length > 22) return nil;
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    return [text rangeOfCharacterFromSet:digits.invertedSet].location == NSNotFound ? text : nil;
}
+ (BOOL)isItemKey:(id)key {
    if (![key isKindOfClass:NSString.class]) return NO;
    NSString *normalized = [[key lowercaseString] stringByReplacingOccurrencesOfString:@"_" withString:@""];
    return [normalized isEqual:@"itemid"] || [normalized isEqual:@"awemeid"];
}
+ (NSArray<NSString *> *)directIDsInContent:(id)content {
    id body = [self decodedContent:content];
    if (![body isKindOfClass:NSDictionary.class]) return @[];
    NSMutableOrderedSet *ids = [NSMutableOrderedSet orderedSet];
    // TIMXOMessage.content 是当前消息正文；只接受直接字段，不递归进引用、表情、卡片或扩展。
    for (id key in body) if ([self isItemKey:key]) {
        NSString *itemID = [self itemID:body[key]];
        if (itemID) [ids addObject:itemID];
    }
    // 同一消息的两个 ID 字段若相互冲突，不能猜哪一个才是当前分享。
    return ids.count == 1 ? ids.array : @[];
}
+ (NSArray<NSString *> *)directItemIDsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account {
    if (peer.longLongValue <= 0 || account.longLongValue <= 0 || peer.longLongValue == account.longLongValue ||
        [[self value:message key:@"sender"] longLongValue] != peer.longLongValue) return @[];
    return [self directIDsInContent:[self value:message key:@"content"]];
}
+ (NSDictionary *)receiptForMessage:(id)message peerID:(NSString *)peer itemID:(NSString *)itemID {
    id identifier = [self value:message key:@"identifier"];
    return @{ @"itemID": itemID, @"friendID": peer, @"shareValidationVersion": @1,
              @"shareMessageID": [identifier isKindOfClass:NSString.class] ? identifier : @"" };
}

// 仅用于核对旧版本误入队的证据，结果绝不能作为新的分享入队。
+ (void)collectLegacyIDs:(id)object into:(NSMutableSet *)ids depth:(NSUInteger)depth budget:(NSUInteger *)budget {
    if (!object || depth > 7 || !*budget) return;
    (*budget)--;
    if ([object isKindOfClass:NSDictionary.class]) {
        for (id key in object) {
            if ([self isItemKey:key]) {
                NSString *itemID = [self itemID:object[key]];
                if (itemID) [ids addObject:itemID];
            } else [self collectLegacyIDs:object[key] into:ids depth:depth + 1 budget:budget];
        }
    } else if ([object isKindOfClass:NSArray.class]) {
        for (id child in object) [self collectLegacyIDs:child into:ids depth:depth + 1 budget:budget];
    } else if ([object isKindOfClass:NSString.class] && [object length] <= 65536) {
        id decoded = [self decodedContent:object];
        if (decoded) [self collectLegacyIDs:decoded into:ids depth:depth + 1 budget:budget];
    }
}
+ (NSSet<NSString *> *)nestedIDsInContent:(id)content {
    NSMutableSet *ids = [NSMutableSet set];
    NSUInteger budget = 500;
    id body = [self decodedContent:content];
    if ([body isKindOfClass:NSDictionary.class]) {
        for (id key in body) if (![self isItemKey:key])
            [self collectLegacyIDs:body[key] into:ids depth:1 budget:&budget];
    } else [self collectLegacyIDs:body into:ids depth:0 budget:&budget];
    return ids;
}
+ (NSDictionary *)reconcileRows:(NSArray<NSDictionary *> *)rows history:(NSArray *)history
                         peerID:(NSString *)peer accountID:(NSString *)account {
    NSMutableDictionary *candidates = [NSMutableDictionary dictionary];
    for (NSDictionary *row in rows) {
        if (![row isKindOfClass:NSDictionary.class] || ![row[@"friendID"] isEqual:peer] ||
            [row[@"shareValidationVersion"] unsignedIntegerValue] >= 1 || ![self itemID:row[@"itemID"]]) continue;
        candidates[row[@"itemID"]] = row;
    }
    NSMutableDictionary *direct = [NSMutableDictionary dictionary];
    NSMutableSet *own = [NSMutableSet set], *referenced = [NSMutableSet set];
    if (candidates.count) for (id message in history) {
        long long sender = [[self value:message key:@"sender"] longLongValue];
        if (sender == peer.longLongValue && peer.longLongValue != account.longLongValue) {
            for (NSString *itemID in [self directItemIDsForMessage:message peerID:peer accountID:account])
                if (candidates[itemID]) direct[itemID] = [self receiptForMessage:message peerID:peer itemID:itemID];
            [referenced unionSet:[self nestedIDsInContent:[self value:message key:@"content"]]];
        } else if (sender == account.longLongValue && account.longLongValue > 0) {
            [own addObjectsFromArray:[self directIDsInContent:[self value:message key:@"content"]]];
        }
    }
    NSMutableArray *verified = [NSMutableArray array], *rejected = [NSMutableArray array];
    for (NSString *itemID in candidates) {
        if (direct[itemID]) {
            NSMutableDictionary *row = [candidates[itemID] mutableCopy];
            [row addEntriesFromDictionary:direct[itemID]];
            [verified addObject:row];
        } else if ([own containsObject:itemID] && [referenced containsObject:itemID]) {
            // 必须同时有本账户发出和好友引用的证据，不能凭历史窗口内没找到就删除。
            [rejected addObject:@{ @"itemID": itemID, @"friendID": peer, @"reason": @"reply_to_outgoing_share" }];
        }
    }
    return @{ @"verifiedRows": verified, @"rejectedRows": rejected };
}
+ (NSDictionary *)diagnosticsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account {
    id body = [self decodedContent:[self value:message key:@"content"]];
    NSMutableArray *keys = [NSMutableArray array];
    if ([body isKindOfClass:NSDictionary.class]) for (id key in body)
        if ([key isKindOfClass:NSString.class] && keys.count < 24) [keys addObject:key];
    return @{ @"messageType": [self value:message key:@"messageType"] ?: @0, @"contentKeys": keys,
              @"directVideoCount": @([self directItemIDsForMessage:message peerID:peer accountID:account].count),
              @"ignoredNestedVideoCount": @([self nestedIDsInContent:[self value:message key:@"content"]].count) };
}
@end
