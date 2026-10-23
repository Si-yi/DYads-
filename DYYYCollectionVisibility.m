#import "DYYYCollectionVisibility.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

static char kDYYYCollectionNativeHiddenKey;
static char kDYYYCollectionManagedKey;
static char kDYYYCollectionMutationKey;

@implementation DYYYCollectionVisibility

+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *exception) { return nil; }
}
+ (NSUInteger)flags {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return ([defaults boolForKey:@"DYYYHideTemplateVideo"] ? 1 : 0) | ([defaults boolForKey:@"DYYYHideTemplatePlaylet"] ? 2 : 0);
}
+ (NSHashTable<UIView *> *)stacks {
    static NSHashTable *stacks;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stacks = [NSHashTable weakObjectsHashTable];
        __block NSUInteger previous = [self flags];
        [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            NSUInteger current = [self flags];
            if (previous == current) return;
            previous = current;
            for (UIView *stack in stacks.allObjects) {
                [self applyStack:stack];
                [stack setNeedsLayout];
            }
        }];
    });
    return stacks;
}
+ (BOOL)bottomStack:(UIView *)stack {
    if (!stack) return NO;
    if (![NSStringFromClass(stack.class) isEqual:@"AWEElementStackView"]) return NO;
    if ([stack.accessibilityLabel isEqual:@"bottom"]) return YES;
    UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:stack];
    return stack && [self value:controller key:@"bottomContainerView"] == stack;
}
+ (UIView *)rowForView:(UIView *)view {
    Class rowClass = NSClassFromString(@"AWEBaseElementView");
    for (NSUInteger depth = 0; view && depth < 6; depth++, view = view.superview) {
        if (rowClass && [view isKindOfClass:rowClass]) return view;
    }
    return nil;
}
+ (NSString *)collectionKeyForRow:(UIView *)row {
    if (![self bottomStack:row.superview]) return nil;
    id element = [self value:row key:@"element"];
    NSString *elementClass = NSStringFromClass([element class]);
    id identifier = [self value:element key:@"identifier"];
    BOOL mixElement = [elementClass isEqual:@"AWEPlayInteractionNewMixVideoInfoElement"] || [identifier isEqual:@"compilation_detail"];
    BOOL templateElement = [elementClass isEqual:@"AWETemplateNewBottomElement"] && [identifier isEqual:@"playlet_bar"];
    BOOL mixLabel = NO, playletLabel = NO;
    // 同一个 AWEAntiAddictedNoticeBarView 也用于声明、风险提示等业务，不能仅凭视图类隐藏。
    NSMutableArray *queue = [NSMutableArray arrayWithObject:row];
    for (NSUInteger index = 0; index < queue.count && index < 32; index++) {
        UIView *view = queue[index];
        if ([NSStringFromClass(view.class) isEqual:@"AWEAntiAddictedNoticeBarView"]) {
            for (UIView *child in view.subviews) {
                if (![child isKindOfClass:UILabel.class]) continue;
                NSString *text = [((UILabel *)child).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if ([text isEqual:@"合集"]) mixLabel = YES;
                if ([text isEqual:@"短剧"] || [text isEqual:@"短剧合集"]) playletLabel = YES;
            }
        } else if (queue.count < 32) [queue addObjectsFromArray:view.subviews];
    }
    if (!mixElement && !templateElement && !mixLabel && !playletLabel) return nil;
    UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:row];
    id model = [self value:controller key:@"model"];
    // 保留原生模型的合集/剧集信息，只在播放页收拢入口，不破坏选集、连播和博主页数据。
    id playlet = [self value:model key:@"playletInfoModel"];
    if ((playlet && playlet != NSNull.null) || playletLabel) return @"DYYYHideTemplatePlaylet";
    return @"DYYYHideTemplateVideo";
}
+ (BOOL)shouldHideRow:(UIView *)row {
    if (![self flags]) return NO;
    NSString *key = [self collectionKeyForRow:row];
    return key && [NSUserDefaults.standardUserDefaults boolForKey:key];
}
+ (BOOL)hiddenForRow:(UIView *)row requested:(BOOL)hidden {
    if (!NSThread.isMainThread || objc_getAssociatedObject(row, &kDYYYCollectionMutationKey)) return hidden;
    BOOL managed = objc_getAssociatedObject(row, &kDYYYCollectionManagedKey) != nil;
    BOOL remove = [self shouldHideRow:row];
    if (!managed && !remove) return hidden;
    objc_setAssociatedObject(row, &kDYYYCollectionNativeHiddenKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(row, &kDYYYCollectionManagedKey, remove ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!remove) objc_setAssociatedObject(row, &kDYYYCollectionNativeHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return hidden || remove;
}
+ (void)applyRow:(UIView *)row {
    if (!row || !NSThread.isMainThread || objc_getAssociatedObject(row, &kDYYYCollectionMutationKey)) return;
    BOOL managed = objc_getAssociatedObject(row, &kDYYYCollectionManagedKey) != nil;
    BOOL remove = [self shouldHideRow:row];
    if (!managed && !remove) return;
    NSNumber *native = objc_getAssociatedObject(row, &kDYYYCollectionNativeHiddenKey);
    if (!native) native = @(row.hidden);
    BOOL target = native.boolValue || remove;
    objc_setAssociatedObject(row, &kDYYYCollectionNativeHiddenKey, remove ? native : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(row, &kDYYYCollectionManagedKey, remove ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (row.hidden != target) {
        objc_setAssociatedObject(row, &kDYYYCollectionMutationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        row.hidden = target;
        objc_setAssociatedObject(row, &kDYYYCollectionMutationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [row.superview setNeedsLayout];
    }
}
+ (void)applyBar:(UIView *)bar {
    UIView *row = [self rowForView:bar];
    if ([self bottomStack:row.superview]) [[self stacks] addObject:row.superview];
    [self applyRow:row];
}
+ (void)applyStack:(UIView *)stack {
    if (!NSThread.isMainThread || ![self bottomStack:stack]) return;
    [[self stacks] addObject:stack];
    for (UIView *row in stack.subviews) {
        if ([row isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) [self applyRow:row];
    }
}
@end
