#import "DYYYAutoMessageBatch.h"

@implementation DYYYAutoMessageBatch
+ (NSArray<NSDictionary *> *)configuredFriends:(NSArray<NSDictionary *> *)configs ownerID:(NSString *)ownerID contacts:(NSArray<NSDictionary *> *)contacts {
    if (!ownerID.length) return @[];
    NSMutableDictionary *byID = [NSMutableDictionary dictionary];
    for (id contact in contacts) if ([contact isKindOfClass:NSDictionary.class] && [contact[@"userID"] isKindOfClass:NSString.class]) byID[contact[@"userID"]] = contact;
    NSMutableArray *friends = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *config in configs) {
        NSString *uid = config[@"userID"];
        if (![config[@"ownerID"] isEqual:ownerID] || ![uid isKindOfClass:NSString.class] || !uid.length || [seen containsObject:uid]) continue;
        [seen addObject:uid];
        NSMutableDictionary *friend = [byID[uid] mutableCopy] ?: [NSMutableDictionary dictionary];
        friend[@"userID"] = uid;
        if (![friend[@"name"] isKindOfClass:NSString.class] || ![friend[@"name"] length])
            friend[@"name"] = [config[@"name"] isKindOfClass:NSString.class] && [config[@"name"] length] ? config[@"name"] : uid;
        NSMutableOrderedSet *aliases = [NSMutableOrderedSet orderedSet];
        id values = friend[@"aliases"];
        if ([values isKindOfClass:NSArray.class]) for (id alias in values)
            if ([alias isKindOfClass:NSString.class] && [alias length]) [aliases addObject:alias];
        if ([config[@"name"] isKindOfClass:NSString.class] && [config[@"name"] length]) [aliases addObject:config[@"name"]];
        friend[@"aliases"] = aliases.array;
        [friends addObject:friend];
    }
    return friends;
}
+ (NSArray<NSDictionary *> *)configsByUpdatingText:(NSString *)text randomText:(BOOL)randomText
                                        configs:(NSArray<NSDictionary *> *)configs ownerID:(NSString *)ownerID selectedUserIDs:(NSSet<NSString *> *)selectedIDs {
    if (!ownerID.length || !selectedIDs.count || ![text isKindOfClass:NSString.class] ||
        ![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) return configs;
    NSMutableArray *updated = [NSMutableArray arrayWithCapacity:configs.count];
    for (NSDictionary *config in configs) {
        if ([config[@"ownerID"] isEqual:ownerID] && [selectedIDs containsObject:config[@"userID"] ?: @""]) {
            NSMutableDictionary *row = [config mutableCopy];
            row[@"message"] = text;
            row[@"randomText"] = @(randomText);
            [updated addObject:row];
        } else [updated addObject:config];
    }
    return updated;
}
@end
