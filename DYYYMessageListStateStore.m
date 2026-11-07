#import "DYYYMessageListStateStore.h"
#import <objc/runtime.h>
static char kDYYYMessageListViewportKey;
static char kDYYYMessageListSeparatorKey;
@implementation DYYYMessageListStateStore
+ (id)viewportForObject:(id)object {return objc_getAssociatedObject(object,&kDYYYMessageListViewportKey);}
+ (void)setViewport:(id)viewport forObject:(id)object {if(object)objc_setAssociatedObject(object,&kDYYYMessageListViewportKey,viewport,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
+ (NSNumber *)separatorForObject:(id)object {id value=objc_getAssociatedObject(object,&kDYYYMessageListSeparatorKey);return [value isKindOfClass:NSNumber.class]?value:nil;}
+ (void)setSeparator:(NSNumber *)separator forObject:(id)object {if(object && (!separator || [separator isKindOfClass:NSNumber.class]))objc_setAssociatedObject(object,&kDYYYMessageListSeparatorKey,separator,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
@end
