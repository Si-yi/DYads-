#import "DYYYUnreadProbe.h"
#import <objc/runtime.h>

@implementation DYYYUnreadProbe
+ (NSMutableDictionary *)rows {
    static NSMutableDictionary *rows;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ rows = [NSMutableDictionary dictionary]; });
    return rows;
}
+ (NSMutableSet *)installed {
    static NSMutableSet *installed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ installed = [NSMutableSet set]; });
    return installed;
}
+ (BOOL)canObserveClass:(Class)cls selector:(SEL)selector arguments:(NSUInteger)arguments result:(char)result {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != arguments) return NO;
    char *type = method_copyReturnType(method);
    BOOL matches = type && type[0] == result;
    free(type);
    for (unsigned int index = 2; matches && index < arguments; index++) {
        char *argument = method_copyArgumentType(method, index);
        matches = argument && argument[0] == '@';
        free(argument);
    }
    return matches;
}
+ (void)didInstall:(NSString *)name {
    if (NSThread.isMainThread && name.length) [[self installed] addObject:name];
}
+ (NSString *)className:(id)object {
    // 不调用 description、模型 getter 或 SDK 方法。
    Class cls = object ? object_getClass(object) : Nil;
    return cls ? NSStringFromClass(cls) : @"";
}
+ (void)recordReceiver:(id)receiver input:(id)input result:(id)result selector:(SEL)selector {
    if (!NSThread.isMainThread || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"]) return;
    NSString *owner = [self className:receiver], *source = [self className:input], *output = [self className:result];
    NSString *method = NSStringFromSelector(selector);
    NSString *key = [@[owner, method, source, output] componentsJoinedByString:@"|"];
    NSDictionary *old = [self rows][key];
    if (!old && [self rows].count >= 32) return;
    [self rows][key] = @{ @"receiverClass":owner, @"selector":method, @"inputClass":source,
        @"resultClass":output, @"calls":@([old[@"calls"] unsignedIntegerValue] + 1) };
}
+ (NSArray<NSString *> *)observedClassNames {
    if (!NSThread.isMainThread) return @[];
    NSMutableSet *names = [NSMutableSet set];
    for (NSDictionary *row in [self rows].allValues)
        for (NSString *key in @[ @"receiverClass", @"inputClass", @"resultClass" ])
            if ([row[key] length]) [names addObject:row[key]];
    return [names.allObjects sortedArrayUsingSelector:@selector(compare:)];
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{ @"status":@"main_thread_only" };
    return @{ @"enabled":@([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"]),
        @"installed":[[self installed].allObjects sortedArrayUsingSelector:@selector(compare:)],
        @"observations":[[self rows].allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"selector"] compare:b[@"selector"]];
        }], @"recordLimit":@32, @"timeFilterActive":@NO, @"policy":@"passive_types_only_no_sdk_reads" };
}
@end
