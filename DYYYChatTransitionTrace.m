#import "DYYYChatTransitionTrace.h"

@interface DYYYChatTransitionTrace ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSURL *file;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *events;
@property (atomic, copy) NSDictionary *snapshot;
@end

@implementation DYYYChatTransitionTrace
+ (instancetype)shared {
    static DYYYChatTransitionTrace *trace;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        trace = [DYYYChatTransitionTrace new];
        trace.queue = dispatch_queue_create("com.dyads.chat.transition.trace", DISPATCH_QUEUE_SERIAL);
        trace.events = [NSMutableArray array];
        trace.snapshot = @{};
        dispatch_async(trace.queue, ^{
            NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
            NSURL *directory = [base URLByAppendingPathComponent:@"DYads/Diagnostics" isDirectory:YES];
            [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
            trace.file = [directory URLByAppendingPathComponent:@"chat-transition.json"];
            if ([[NSFileManager.defaultManager attributesOfItemAtPath:trace.file.path error:nil] fileSize] <= 65536) {
                NSData *data = [NSData dataWithContentsOfURL:trace.file];
                id previous = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                if ([previous isKindOfClass:NSArray.class])
                    for (id event in previous) if ([event isKindOfClass:NSDictionary.class] && trace.events.count < 32) [trace.events addObject:event];
            }
            trace.snapshot = @{@"events":trace.events.copy, @"source":@"persisted_transition_events"};
        });
    });
    return trace;
}
+ (void)append:(NSDictionary *)event {
    DYYYChatTransitionTrace *trace = [self shared];
    dispatch_async(trace.queue, ^{
        [trace.events addObject:event];
        while (trace.events.count > 32) [trace.events removeObjectAtIndex:0];
        trace.snapshot = @{@"events":trace.events.copy, @"source":@"persisted_transition_events"};
        NSData *data = [NSJSONSerialization dataWithJSONObject:trace.events options:0 error:nil];
        if (data.length && data.length <= 65536 && trace.file) {
            [data writeToURL:trace.file options:NSDataWritingAtomic error:nil];
            [trace.file setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
            [NSFileManager.defaultManager setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:trace.file.path error:nil];
        }
    });
}
+ (BOOL)enabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"];
}
+ (NSDictionary *)factsForController:(UIViewController *)controller phase:(NSString *)phase {
    UIView *view = controller.viewIfLoaded;
    UIWindow *window = view.window;
    UIViewController *presenter = controller.presentedViewController;
    UIViewController *ancestor = controller;
    for (NSUInteger depth = 0; !presenter && ancestor && depth < 16; depth++, ancestor = ancestor.parentViewController)
        presenter = ancestor.presentedViewController;
    return @{@"phase":phase, @"time":@(NSDate.date.timeIntervalSince1970),
        @"controller":NSStringFromClass(controller.class) ?: @"", @"window":window ? NSStringFromClass(window.class) : @"",
        @"viewInteraction":@(view.userInteractionEnabled), @"windowInteraction":@(window.userInteractionEnabled),
        @"applicationIgnoringInteraction":@(UIApplication.sharedApplication.isIgnoringInteractionEvents),
        @"applicationState":@(UIApplication.sharedApplication.applicationState),
        @"presented":presenter ? NSStringFromClass(presenter.class) : @"",
        @"transitionInProgress":@(controller.transitionCoordinator != nil)};
}
+ (void)recordController:(UIViewController *)controller phase:(NSString *)phase {
    if (!NSThread.isMainThread || !controller || ![self enabled]) return;
    [self append:[self factsForController:controller phase:phase]];
}
+ (void)watchController:(UIViewController *)controller phase:(NSString *)phase {
    if (!NSThread.isMainThread || !controller || ![self enabled]) return;
    NSDictionary *facts = [self factsForController:controller phase:phase];
    [self append:facts];
    __weak UIViewController *weakController = controller;
    // 每次真实进入事件只探测一次，不轮询，不抓取/挂起线程，不触碰 SDK。
    DYYYChatTransitionTrace *trace = [self shared];
    __block BOOL acknowledged = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        BOOL foreground = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
        UIViewController *current = weakController;
        NSDictionary *response = current ? [self factsForController:current phase:[phase stringByAppendingString:@"_main_responsive"]] : nil;
        dispatch_async(trace.queue, ^{
            acknowledged = YES;
            if (foreground && response) [self append:response];
        });
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), trace.queue, ^{
        if (acknowledged) return;
        NSMutableDictionary *timeout = [facts mutableCopy];
        timeout[@"phase"] = [phase stringByAppendingString:@"_main_probe_unanswered"];
        timeout[@"time"] = @(NSDate.date.timeIntervalSince1970);
        timeout[@"note"] = @"一次主队列响应探测超时，不能单独证明死锁";
        [self append:timeout];
    });
}
+ (NSDictionary *)diagnostics { return [self shared].snapshot; }
@end
