#import "DYYYIMShareParser.h"

@implementation DYYYIMShareParser
+ (NSUInteger)validationVersion { return 2; }
+ (BOOL)isShareMessageType:(id)type {
    // 39.5.0 现场导出确认：8 为作品视频分享，77 为作品图文分享。
    // 83/105 的评论/引用正文也含顶层 itemId，不能把字段位置当作分享类型。
    if (![type isKindOfClass:NSNumber.class]) return NO;
    return [type longLongValue] == 8 || [type longLongValue] == 77;
}
+ (BOOL)isKnownContextType:(id)type {
    if (![type isKindOfClass:NSNumber.class]) return NO;
    // 同一现场中已观察到的表情、文字、图片及评论/引用类型；未知类型不据此撤销缓存。
    return [@[@5, @7, @27, @83, @105] containsObject:type];
}
+ (BOOL)isCurrentReceipt:(id)row {
    if (![row isKindOfClass:NSDictionary.class]) return NO;
    id version = row[@"shareValidationVersion"], identifier = row[@"shareMessageID"];
    return [version isKindOfClass:NSNumber.class] && [version unsignedIntegerValue] >= [self validationVersion] &&
        [self isShareMessageType:row[@"shareMessageType"]] &&
        [row[@"shareUnreadValidated"] isKindOfClass:NSNumber.class] && [row[@"shareUnreadValidated"] boolValue] &&
        [identifier isKindOfClass:NSString.class] && [identifier length] > 0;
}
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
    if (![self isShareMessageType:[self value:message key:@"messageType"]]) return @[];
    return [self directIDsInContent:[self value:message key:@"content"]];
}
+ (NSDictionary *)receiptForUnreadMessage:(id)message peerID:(NSString *)peer itemID:(NSString *)itemID {
    id identifier = [self value:message key:@"identifier"];
    id type = [self value:message key:@"messageType"];
    if (![self isShareMessageType:type] || [[self value:message key:@"sender"] longLongValue] != peer.longLongValue ||
        ![identifier isKindOfClass:NSString.class] || ![identifier length] ||
        ![[self directIDsInContent:[self value:message key:@"content"]] containsObject:itemID]) return nil;
    NSMutableDictionary *receipt = [@{ @"itemID": itemID, @"friendID": peer,
        @"shareValidationVersion": @([self validationVersion]), @"shareUnreadValidated": @YES,
        @"shareMessageType": type, @"shareMessageID": identifier } mutableCopy];
    id date = [self value:message key:@"createdAt"];
    if ([date isKindOfClass:NSDate.class]) receipt[@"shareMessageCreatedAt"] = @([date timeIntervalSince1970]);
    return receipt;
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
    return [self reconcileRows:rows history:history unreadMessages:@[] peerID:peer accountID:account];
}
+ (NSDictionary *)reconcileRows:(NSArray<NSDictionary *> *)rows history:(NSArray *)history unreadMessages:(NSArray *)unread
                         peerID:(NSString *)peer accountID:(NSString *)account {
    NSMutableDictionary *candidates = [NSMutableDictionary dictionary];
    for (NSDictionary *row in rows) {
        if (![row isKindOfClass:NSDictionary.class] || ![row[@"friendID"] isEqual:peer] ||
            [self isCurrentReceipt:row] || ![self itemID:row[@"itemID"]]) continue;
        candidates[row[@"itemID"]] = row;
    }
    NSMutableDictionary *direct = [NSMutableDictionary dictionary];
    NSMutableDictionary *eligible = [NSMutableDictionary dictionary];
    NSMutableSet *historyIDs = [NSMutableSet set];
    for (id message in history) {
        id identifier = [self value:message key:@"identifier"];
        if ([identifier isKindOfClass:NSString.class]) [historyIDs addObject:identifier];
    }
    for (id message in unread) {
        id identifier = [self value:message key:@"identifier"];
        if (![identifier isKindOfClass:NSString.class] || ![historyIDs containsObject:identifier]) continue;
        for (NSString *itemID in [self directItemIDsForMessage:message peerID:peer accountID:account]) {
            NSDictionary *receipt = [self receiptForUnreadMessage:message peerID:peer itemID:itemID];
            if (candidates[itemID] && receipt && !eligible[itemID]) eligible[itemID] = receipt;
        }
    }
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *invalidReceipts = [NSMutableDictionary dictionary];
    NSMutableSet *own = [NSMutableSet set], *referenced = [NSMutableSet set];
    if (candidates.count) for (id message in history) {
        long long sender = [[self value:message key:@"sender"] longLongValue];
        if (sender == peer.longLongValue && peer.longLongValue != account.longLongValue) {
            for (NSString *itemID in [self directItemIDsForMessage:message peerID:peer accountID:account]) {
                if (candidates[itemID]) direct[itemID] = @YES;
            }
            [referenced unionSet:[self nestedIDsInContent:[self value:message key:@"content"]]];
            if ([self isKnownContextType:[self value:message key:@"messageType"]]) {
                NSArray *contextIDs = [self directIDsInContent:[self value:message key:@"content"]];
                [referenced addObjectsFromArray:contextIDs];
                id identifier = [self value:message key:@"identifier"];
                if ([identifier isKindOfClass:NSString.class] && [identifier length]) for (NSString *itemID in contextIDs) {
                    if (!candidates[itemID]) continue;
                    if (!invalidReceipts[itemID]) invalidReceipts[itemID] = [NSMutableSet set];
                    [invalidReceipts[itemID] addObject:identifier];
                }
            }
        } else if (sender == account.longLongValue && account.longLongValue > 0) {
            if ([self isShareMessageType:[self value:message key:@"messageType"]])
                [own addObjectsFromArray:[self directIDsInContent:[self value:message key:@"content"]]];
        }
    }
    NSMutableArray *verified = [NSMutableArray array], *rejected = [NSMutableArray array];
    for (NSString *itemID in candidates) {
        if (direct[itemID]) {
            // 在全历史中找到真实分享，只证明它曾被分享过，不证明它属于本次未读。
            // 旧记录继续保存在待核实区，不能因历史命中就重新推到首页。
            if (eligible[itemID]) {
                NSMutableDictionary *row = [candidates[itemID] mutableCopy];
                [row addEntriesFromDictionary:eligible[itemID]];
                [verified addObject:row];
            }
        } else {
            id receiptID = candidates[itemID][@"shareMessageID"];
            BOOL wrongReceipt = [receiptID isKindOfClass:NSString.class] && [invalidReceipts[itemID] containsObject:receiptID];
            if (wrongReceipt || ([own containsObject:itemID] && [referenced containsObject:itemID])) {
                // 已保存的 v1 消息凭据本身是评论/引用时也要撤销，不能继续信任旧版“已验证”。
                // 必须找到明确的反证；仅查不到消息、未知类型或窗口缺失均保留待核实。
                [rejected addObject:@{ @"itemID": itemID, @"friendID": peer,
                    @"reason": wrongReceipt ? @"non_share_message_receipt" : @"reply_to_outgoing_share" }];
            }
        }
    }
    return @{ @"verifiedRows": verified, @"rejectedRows": rejected };
}
+ (NSDictionary *)diagnosticsForMessage:(id)message peerID:(NSString *)peer accountID:(NSString *)account {
    id body = [self decodedContent:[self value:message key:@"content"]];
    NSMutableArray *keys = [NSMutableArray array];
    if ([body isKindOfClass:NSDictionary.class]) for (id key in body)
        if ([key isKindOfClass:NSString.class] && keys.count < 24) [keys addObject:key];
    id type = [self value:message key:@"messageType"];
    return @{ @"parserVersion": @([self validationVersion]),
              @"messageType": type ?: @0, @"contentKeys": keys,
              @"classification": [self isShareMessageType:type] ? @"share_type" :
                  ([self isKnownContextType:type] ? @"context_type" : @"unknown_type"),
              @"topLevelVideoCount": @([self directIDsInContent:[self value:message key:@"content"]].count),
              @"directVideoCount": @([self directItemIDsForMessage:message peerID:peer accountID:account].count),
              @"ignoredNestedVideoCount": @([self nestedIDsInContent:[self value:message key:@"content"]].count) };
}
@end
