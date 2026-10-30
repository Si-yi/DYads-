#import "DYYYHomeDailyFilter.h"
#import <objc/runtime.h>

static char kDYYYHomeDailyScopeKey;

@interface DYYYHomeDailyScope : NSObject
@property (atomic, weak) id feed;
@property (atomic, assign) BOOL home;
@property (atomic, assign) BOOL enabled;
@end
@implementation DYYYHomeDailyScope
@end

@implementation DYYYHomeDailyFilter

+ (BOOL)isDailyModel:(id)model {
    Class aweme = NSClassFromString(@"AWEAwemeModel");
    if (!aweme || ![model isKindOfClass:aweme]) return NO;
    // 39.5 完整导出的原生日常标记。RichContent / Story 容器也承载普通图文，不能按类名过滤。
    for (NSString *key in @[ @"is24Story", @"is25Story", @"isStory", @"isMomentStory" ]) {
        if (![model respondsToSelector:NSSelectorFromString(key)]) continue;
        @try {
            id value = [model valueForKey:key];
            if ([value isKindOfClass:NSNumber.class] && [value longLongValue] > 0) return YES;
        } @catch (__unused NSException *exception) {
            // 未知版本的不可读标记不猜测，继续检查其余已确认字段。
        }
    }
    return NO;
}

+ (NSArray *)filterArray:(id)array enabled:(BOOL)enabled home:(BOOL)home {
    if (!enabled || !home || ![array isKindOfClass:NSArray.class]) return array;
    NSMutableArray *filtered = nil;
    NSUInteger index = 0;
    for (id model in (NSArray *)array) {
        if ([self isDailyModel:model]) {
            if (!filtered) filtered = [[array subarrayWithRange:NSMakeRange(0, index)] mutableCopy];
        } else if (filtered) {
            [filtered addObject:model];
        }
        index++;
    }
    if (!filtered) return array;
    return [array isKindOfClass:NSMutableArray.class] ? filtered : filtered.copy;
}

+ (BOOL)bindFeed:(id)feed controller:(id)controller {
    if (!NSThread.isMainThread || !feed || !controller) return NO;
    BOOL home = NO;
    Class root = NSClassFromString(@"AWEFeedRootViewController");
    id parent = feed;
    for (NSUInteger depth = 0; parent && depth < 24; depth++) {
        if (root && [parent isKindOfClass:root]) { home = YES; break; }
        if (![parent respondsToSelector:NSSelectorFromString(@"parentViewController")]) break;
        @try { parent = [parent valueForKey:@"parentViewController"]; }
        @catch (__unused NSException *exception) { break; }
    }
    DYYYHomeDailyScope *scope = objc_getAssociatedObject(controller, &kDYYYHomeDailyScopeKey);
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYHideHomeDaily"];
    BOOL changed = !scope || scope.feed != feed || scope.home != home || scope.enabled != enabled;
    BOOL shouldRecalculate = changed && ((home && enabled) || (scope.home && scope.enabled));
    if (!scope) {
        scope = [DYYYHomeDailyScope new];
        objc_setAssociatedObject(controller, &kDYYYHomeDailyScopeKey, scope, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    scope.feed = feed; scope.home = home; scope.enabled = enabled;
    return shouldRecalculate;
}

+ (NSArray *)filterArray:(id)array controller:(id)controller {
    DYYYHomeDailyScope *scope = objc_getAssociatedObject(controller, &kDYYYHomeDailyScopeKey);
    return [self filterArray:array enabled:scope.enabled home:scope.home && scope.feed != nil];
}

+ (NSDictionary *)diagnostics {
    return @{ @"enabled": @([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYHideHomeDaily"]),
        @"policy": @"home_native_daily_flags_filtered_list_only" };
}
@end
