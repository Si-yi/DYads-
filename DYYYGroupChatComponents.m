#import "DYYYGroupChatComponents.h"
#import <objc/runtime.h>

@implementation DYYYGroupChatComponents
+ (id)navigationComponents:(id)components enabled:(BOOL)enabled {
    if (!enabled || ![components isKindOfClass:NSArray.class]) return components;
    NSString *toggle = @"AWEIMMessageListNaviBarGroupZoneToggleComponent";
    NSString *detail = @"AWEIMMessageListNaviBarChatDetailComponent";
    if (![(NSArray *)components containsObject:toggle]) return components;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[components count]];
    BOOL hasDetail = [(NSArray *)components containsObject:detail];
    for (id entry in components) {
        if ([entry isKindOfClass:NSString.class] && [entry isEqual:toggle]) {
            if (!hasDetail) { [result addObject:detail]; hasDetail = YES; }
        } else [result addObject:entry];
    }
    @synchronized (self) {
        objc_setAssociatedObject(self, @selector(diagnostics), @{ @"nativeDetailRequested": @YES }, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return result.copy;
}
+ (NSDictionary *)diagnostics {
    @synchronized (self) { return objc_getAssociatedObject(self, _cmd) ?: @{ @"nativeDetailRequested": @NO }; }
}
@end
