#import "DYYYPlaybackCatalogStore.h"

@interface DYYYPlaybackCatalogStore ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray *> *catalogs;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableSet *> *identifiers;
@end

@implementation DYYYPlaybackCatalogStore
+ (instancetype)sharedStore {
    static DYYYPlaybackCatalogStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [[self alloc] initWithDefaults:NSUserDefaults.standardUserDefaults]; });
    return store;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    if ((self = [super init])) { _defaults = defaults; [self reload]; }
    return self;
}
+ (NSInteger)modeFromValue:(id)value {
    if ([value isKindOfClass:NSString.class]) return [@[@"显示", @"隐藏", @"移除"] containsObject:value] ? [@[@"显示", @"隐藏", @"移除"] indexOfObject:value] : 0;
    return [value isKindOfClass:NSNumber.class] && [value integerValue] >= 0 && [value integerValue] <= 2 ? [value integerValue] : 0;
}
+ (NSString *)masterKey:(NSUInteger)kind { return kind == 0 ? @"DYYYPlaybackAnchorsMode" : @"DYYYPlaybackBottomMode"; }
+ (NSString *)storageKey:(NSUInteger)kind { return kind == 0 ? @"DYYYPlaybackAnchorCatalog" : @"DYYYPlaybackBottomCatalog"; }
+ (NSString *)itemKey:(NSUInteger)kind identifier:(NSString *)identifier {
    NSString *encoded = [identifier stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    return [NSString stringWithFormat:@"DYYYPlaybackItem.%lu.%@", (unsigned long)kind, encoded ?: @""];
}
+ (NSDictionary *)legacyTypes {
    return @{
        @"0:poi_poi": @[@"地理定位", @"DYYYHideLocation"],
        @"1:related_search_anchor": @[@"相关搜索", @"DYYYHideInteractionSearch"],
        @"1:trending_page": @[@"热点提示", @"DYYYHideHotspot"],
        @"1:video_collection": @[@"视频合集", @"DYYYHideTemplateVideo"],
        @"1:short_play_collection": @[@"短剧合集", @"DYYYHideTemplatePlaylet"],
        @"1:AWEPlayInteractionRelatedVideoNewBottomElement": @[@"底部相关视频", @"DYYYHideBottomRelated"]
    };
}
+ (NSDictionary *)descriptorWithKind:(NSUInteger)kind identifier:(NSString *)identifier title:(NSString *)title {
    if (kind > 1 || ![identifier isKindOfClass:NSString.class]) return nil;
    identifier = [identifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!identifier.length || identifier.length > 128 || [identifier isEqual:@"openplatform_anchor"]) return nil;
    NSArray *legacy = [self legacyTypes][[NSString stringWithFormat:@"%lu:%@", (unsigned long)kind, identifier]];
    title = [title isKindOfClass:NSString.class] ? [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
    title = legacy ? legacy[0] : title;
    if (!title.length) return nil;
    if (title.length > 24) title = [title substringWithRange:[title rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 24)]];
    NSMutableDictionary *entry = [@{@"kind": @(kind), @"id": identifier, @"title": title} mutableCopy];
    if (legacy) entry[@"legacy"] = legacy[1];
    return entry;
}
- (void)reload {
    self.catalogs = [NSMutableDictionary dictionary];
    self.identifiers = [NSMutableDictionary dictionary];
    // 旧“隐藏视频锚点”是总开关；只在新档位不存在时迁移，用户的新选择优先。
    NSString *key = [self.class masterKey:0];
    if (![self.defaults objectForKey:key] && [self.defaults boolForKey:@"DYYYHideFeedAnchorContainer"]) [self.defaults setObject:@"移除" forKey:key];
}
- (NSArray<NSDictionary *> *)entries:(NSUInteger)kind {
    if (kind > 1) return @[];
    if (!self.catalogs[@(kind)]) {
        NSMutableArray *entries = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        // 旧项目常驻目录，即使已经隐藏，也能恢复和调整档位。
        for (NSString *identity in [[self.class legacyTypes].allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if (![identity hasPrefix:[NSString stringWithFormat:@"%lu:", (unsigned long)kind]]) continue;
            NSDictionary *entry = [self.class descriptorWithKind:kind identifier:[identity substringFromIndex:2] title:nil];
            [entries addObject:entry]; [seen addObject:entry[@"id"]];
        }
        id stored = [self.defaults objectForKey:[self.class storageKey:kind]];
        if ([stored isKindOfClass:NSArray.class]) for (id raw in stored) {
            if (entries.count >= 512) break;
            if (![raw isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *entry = [self.class descriptorWithKind:kind identifier:raw[@"id"] title:raw[@"title"]];
            if (!entry || [seen containsObject:entry[@"id"]]) continue;
            [entries addObject:entry]; [seen addObject:entry[@"id"]];
        }
        self.catalogs[@(kind)] = entries;
        self.identifiers[@(kind)] = seen;
    }
    return [self.catalogs[@(kind)] copy];
}
- (BOOL)record:(NSDictionary *)raw {
    if (![raw isKindOfClass:NSDictionary.class] || ![raw[@"kind"] isKindOfClass:NSNumber.class]) return NO;
    NSUInteger kind = [raw[@"kind"] unsignedIntegerValue];
    NSDictionary *entry = [self.class descriptorWithKind:kind identifier:raw[@"id"] title:raw[@"title"]];
    if (!entry) return NO;
    if (!self.catalogs[@(kind)]) [self entries:kind];
    if ([self.identifiers[@(kind)] containsObject:entry[@"id"]] || self.catalogs[@(kind)].count >= 512) return NO;
    [self.catalogs[@(kind)] addObject:entry];
    [self.identifiers[@(kind)] addObject:entry[@"id"]];
    [self.defaults setObject:self.catalogs[@(kind)] forKey:[self.class storageKey:kind]];
    return YES;
}
- (NSInteger)masterMode:(NSUInteger)kind { return [self.class modeFromValue:[self.defaults objectForKey:[self.class masterKey:kind]]]; }
- (NSInteger)modeForEntry:(NSDictionary *)entry {
    NSUInteger kind = [entry[@"kind"] unsignedIntegerValue];
    NSInteger master = [self masterMode:kind];
    if (master) return master;
    id value = [self.defaults objectForKey:[self.class itemKey:kind identifier:entry[@"id"]]];
    if (value) return [self.class modeFromValue:value];
    NSString *legacy = entry[@"legacy"];
    return legacy && [self.defaults boolForKey:legacy] ? 2 : 0;
}
@end
