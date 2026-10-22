#import "DYYYDebugInspector.h"
#import "DKDebugCapture.h"
#import "DKClassDump.h"
#import "DKZipWriter.h"
#import "DYYYConstants.h"
#import <objc/runtime.h>
#include <string.h>

static char kDYYYDebugButtonKey;
static char kDYYYDebugDragKey;
static void DYYYDebugShowActions(UIWindow *window);

// 钩子只观测调用，原方法始终执行；关闭记录后不再保存事件。
static BOOL DYYYDebugRecording;
static NSMutableArray *DYYYDebugEvents;
static NSDate *DYYYDebugStartedAt;
static NSDate *DYYYDebugStoppedAt;
static NSUInteger DYYYDebugDroppedEvents;
static NSTimer *DYYYDebugRecordTimer;
static DKDebugExportContext *DYYYDebugStartContext;
static NSString *DYYYDebugLastPageState;
static NSMutableSet *DYYYDebugInstalledHooks;
static NSMutableArray *DYYYDebugHookStatus;

static void DYYYDebugRecordEvent(NSString *name, NSDictionary *details, BOOL stack) {
    @synchronized (DYYYDebugInstalledHooks) {
        if (!DYYYDebugRecording) return;
        if (DYYYDebugEvents.count >= 12000) { DYYYDebugDroppedEvents++; return; }
        NSMutableDictionary *event = [@{
            @"event": name, @"elapsedSeconds": @(-[DYYYDebugStartedAt timeIntervalSinceNow]),
            @"mainThread": @(NSThread.isMainThread), @"details": details ?: @{}
        } mutableCopy];
        if (stack) {
            NSArray *symbols = NSThread.callStackSymbols;
            event[@"callStack"] = [symbols subarrayWithRange:NSMakeRange(0, MIN(symbols.count, 24))];
        }
        [DYYYDebugEvents addObject:event];
    }
}

static void DYYYDebugObserveMethod(NSString *className, NSString *methodName, BOOL objectArgument) {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(methodName);
    NSString *key = [NSString stringWithFormat:@"%@.%@", className, methodName];
    if ([DYYYDebugInstalledHooks containsObject:key]) return;
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    // 精确校验签名，避免把未知版本的方法按错误 ABI 调用。
    char result[32] = {0};
    if (method) method_getReturnType(method, result, sizeof(result));
    if (!method || strcmp(result, "v") || method_getNumberOfArguments(method) != (objectArgument ? 3 : 2)) return;
    if (objectArgument) {
        char argument[32] = {0};
        method_getArgumentType(method, 2, argument, sizeof(argument));
        if (argument[0] != '@') return;
    }
    IMP original = method_getImplementation(method);
    IMP replacement;
    if (objectArgument) {
        replacement = imp_implementationWithBlock(^(id receiver, id model) {
            DYYYDebugRecordEvent(key, @{ @"receiver": [NSString stringWithFormat:@"%p", receiver],
                @"modelClass": model ? NSStringFromClass([model class]) : @"nil",
                @"modelAddress": [NSString stringWithFormat:@"%p", model] }, YES);
            ((void (*)(id, SEL, id))original)(receiver, selector, model);
        });
    } else {
        replacement = imp_implementationWithBlock(^(id receiver) {
            DYYYDebugRecordEvent(key, @{ @"receiver": [NSString stringWithFormat:@"%p", receiver] }, YES);
            ((void (*)(id, SEL))original)(receiver, selector);
        });
    }
    // 先在目标类新增覆盖，避免修改继承方法影响其他类。
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
        method_setImplementation(class_getInstanceMethod(cls, selector), replacement);
    }
    [DYYYDebugInstalledHooks addObject:key];
}

static void DYYYDebugPrepareRecordingHooks(void) {
    for (NSString *name in @[@"beginRefresh", @"_refreshWithoutAnimation", @"awe_refreshForceRequestWithoutAnimation", @"_triggerToRefreshIfNeeded", @"cancelAutoPlay"]) {
        DYYYDebugObserveMethod(@"AWEFeedTableViewController", name, NO);
    }
    for (NSString *cls in @[@"AWEFeedCellViewController", @"AWEDPlayerViewController_Merge", @"AWEPlayVideoViewController"]) {
        DYYYDebugObserveMethod(cls, @"setAwemeModel:", YES);
    }
    Class feedClass = NSClassFromString(@"AWEFeedTableViewController");
    SEL refreshSelector = NSSelectorFromString(@"_refresh:refreshType:");
    Method refreshMethod = feedClass ? class_getInstanceMethod(feedClass, refreshSelector) : NULL;
    NSString *refreshKey = @"AWEFeedTableViewController._refresh:refreshType:";
    if (refreshMethod && ![DYYYDebugInstalledHooks containsObject:refreshKey] && method_getNumberOfArguments(refreshMethod) == 4) {
        char ret[16] = {0}, flag[16] = {0}, kind[16] = {0};
        method_getReturnType(refreshMethod, ret, sizeof(ret));
        method_getArgumentType(refreshMethod, 2, flag, sizeof(flag));
        method_getArgumentType(refreshMethod, 3, kind, sizeof(kind));
        if (!strcmp(ret, "v") && !strcmp(flag, @encode(BOOL)) && !strcmp(kind, @encode(long long))) {
            IMP original = method_getImplementation(refreshMethod);
            IMP replacement = imp_implementationWithBlock(^(id receiver, BOOL animated, long long type) {
                DYYYDebugRecordEvent(refreshKey, @{ @"animated": @(animated), @"refreshType": @(type),
                    @"receiver": [NSString stringWithFormat:@"%p", receiver] }, YES);
                ((void (*)(id, SEL, BOOL, long long))original)(receiver, refreshSelector, animated, type);
            });
            if (!class_addMethod(feedClass, refreshSelector, replacement, method_getTypeEncoding(refreshMethod))) {
                method_setImplementation(class_getInstanceMethod(feedClass, refreshSelector), replacement);
            }
            [DYYYDebugInstalledHooks addObject:refreshKey];
        }
    }
    [DYYYDebugHookStatus removeAllObjects];
    [DYYYDebugHookStatus addObjectsFromArray:[[DYYYDebugInstalledHooks allObjects] sortedArrayUsingSelector:@selector(compare:)]];
}

static void DYYYDebugSamplePage(void) {
    NSMutableArray *state = [NSMutableArray array];
    for (UIWindow *window in DKDebugActiveWindows()) {
        UIViewController *top = DKDebugTopPresenter(window);
        [state addObject:@{ @"window": NSStringFromClass(window.class), @"presenter": top ? NSStringFromClass(top.class) : @"nil" }];
        NSMutableArray *pending = [NSMutableArray arrayWithObject:window];
        NSUInteger visited = 0;
        while (pending.count && visited++ < 1200) {
            UIView *view = pending.lastObject;
            [pending removeLastObject];
            if ([view isKindOfClass:UITableView.class] && [NSStringFromClass(view.class) containsString:@"Feed"]) {
                UITableView *table = (UITableView *)view;
                [state addObject:@{ @"table": NSStringFromClass(table.class), @"address": [NSString stringWithFormat:@"%p", table],
                    @"offsetY": @(table.contentOffset.y), @"contentHeight": @(table.contentSize.height),
                    @"dragging": @(table.dragging), @"decelerating": @(table.decelerating),
                    @"visibleRows": table.indexPathsForVisibleRows.description ?: @"" }];
            }
            [pending addObjectsFromArray:view.subviews];
        }
    }
    NSString *signature = state.description;
    if (![signature isEqualToString:DYYYDebugLastPageState]) {
        DYYYDebugLastPageState = signature;
        DYYYDebugRecordEvent(@"pageStateChanged", @{ @"windowsAndFeeds": state }, NO);
    }
}

static void DYYYDebugStartRecording(UIWindow *window) {
    DYYYDebugPrepareRecordingHooks();
    @synchronized (DYYYDebugInstalledHooks) {
        DYYYDebugEvents = [NSMutableArray array];
        DYYYDebugDroppedEvents = 0;
        DYYYDebugStartedAt = NSDate.date;
        DYYYDebugStoppedAt = nil;
        DYYYDebugLastPageState = nil;
        DYYYDebugRecording = YES;
    }
    DYYYDebugStartContext = DKDebugCaptureContext(window, CGPointZero, nil);
    DYYYDebugRecordEvent(@"recordingStarted", @{ @"installedHooks": DYYYDebugHookStatus }, NO);
    DYYYDebugSamplePage();
    [DYYYDebugRecordTimer invalidate];
    DYYYDebugRecordTimer = [NSTimer timerWithTimeInterval:0.75 repeats:YES block:^(__unused NSTimer *timer) { DYYYDebugSamplePage(); }];
    [NSRunLoop.mainRunLoop addTimer:DYYYDebugRecordTimer forMode:NSRunLoopCommonModes];
    DYYYDebugInspectorRefreshOverlay();
}

static void DYYYDebugStopRecording(void) {
    DYYYDebugSamplePage();
    DYYYDebugRecordEvent(@"recordingStopped", nil, NO);
    @synchronized (DYYYDebugInstalledHooks) {
        DYYYDebugRecording = NO;
        DYYYDebugStoppedAt = NSDate.date;
    }
    [DYYYDebugRecordTimer invalidate];
    DYYYDebugRecordTimer = nil;
    DYYYDebugInspectorRefreshOverlay();
}

@interface DYYYDebugDrag : NSObject
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, weak) UIButton *button;
- (void)handleTap;
@end

@implementation DYYYDebugDrag
- (void)handleTap {
    DYYYDebugShowActions(self.window);
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIButton *button = self.button;
    UIWindow *window = self.window;
    if (!button || !window) return;
    CGPoint delta = [gesture translationInView:window];
    button.center = CGPointMake(button.center.x + delta.x, button.center.y + delta.y);
    [gesture setTranslation:CGPointZero inView:window];
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat margin = 12.0;
        CGFloat x = MIN(MAX(button.center.x, margin + button.bounds.size.width / 2), window.bounds.size.width - margin - button.bounds.size.width / 2);
        CGFloat y = MIN(MAX(button.center.y, window.safeAreaInsets.top + margin + button.bounds.size.height / 2), window.bounds.size.height - window.safeAreaInsets.bottom - margin - button.bounds.size.height / 2);
        [UIView animateWithDuration:0.18 animations:^{ button.center = CGPointMake(x, y); }];
    }
}
@end

static void DYYYDebugPresentAlert(UIViewController *presenter, NSString *title, NSString *message) {
    if (!presenter) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static NSData *DYYYDebugJSONData(id value) {
    if (!value) return nil;
    return [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
}

static NSDictionary *DYYYDebugMetadata(void) {
    return @{
        @"plugin": @"DYYY",
        @"pluginVersion": DYYY_VERSION,
        @"generatedAt": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier ?: @"",
        @"appVersion": NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",
        @"buildVersion": NSBundle.mainBundle.infoDictionary[(NSString *)kCFBundleVersionKey] ?: @"",
        @"systemName": UIDevice.currentDevice.systemName ?: @"",
        @"systemVersion": UIDevice.currentDevice.systemVersion ?: @"",
        @"deviceModel": UIDevice.currentDevice.model ?: @""
    };
}

static void DYYYDebugExportCurrentPage(UIViewController *presenter, UIWindow *window) {
    if (!presenter || !window) return;
    DKDebugExportContext *context = DKDebugCaptureContext(window, CGPointZero, nil);
    NSString *base = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"DYYY_Debug_%@", NSUUID.UUID.UUIDString]];
    NSString *zipPath = [base stringByAppendingPathExtension:@"zip"];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSError *fileError = nil;
    [manager createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:&fileError];
    if (fileError) { DYYYDebugPresentAlert(presenter, @"调试导出失败", fileError.localizedDescription); return; }

    NSMutableArray<NSString *> *files = [NSMutableArray array];
    void (^writeJSON)(NSString *, id) = ^(NSString *name, id object) {
      NSData *data = DYYYDebugJSONData(object ?: @{});
      NSString *path = [base stringByAppendingPathComponent:name];
      [manager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
      if (data && [data writeToFile:path atomically:YES]) [files addObject:path];
    };
    writeJSON(@"metadata.json", DYYYDebugMetadata());
    if (DYYYDebugStartedAt && !DYYYDebugRecording) {
        NSDictionary *session;
        @synchronized (DYYYDebugInstalledHooks) {
            session = @{ @"startedAt": @([DYYYDebugStartedAt timeIntervalSince1970]),
                @"stoppedAt": @([DYYYDebugStoppedAt timeIntervalSince1970]),
                @"droppedEvents": @(DYYYDebugDroppedEvents), @"eventLimit": @12000,
                @"sampleIntervalSeconds": @0.75, @"installedHooks": [DYYYDebugHookStatus copy],
                @"events": [DYYYDebugEvents copy] };
        }
        writeJSON(@"recording/session.json", session);
        writeJSON(@"recording/start-view-tree.json", DYYYDebugStartContext.viewTreeJSON ?: @[]);
        NSData *startPNG = DYYYDebugStartContext.screenshotPNG;
        NSString *startPath = [base stringByAppendingPathComponent:@"recording/start-screenshot.png"];
        if (startPNG && [startPNG writeToFile:startPath atomically:YES]) [files addObject:startPath];
    }
    writeJSON(@"windows.json", context.windowsJSON ?: @[]);
    writeJSON(@"view_tree.json", context.viewTreeJSON ?: @[]);
    writeJSON(@"selected_view.json", context.selectedViewJSON ?: @{});
    writeJSON(@"layers.json", context.layersJSON ?: @[]);
    if (context.viewTreeText.length) {
        NSString *path = [base stringByAppendingPathComponent:@"view_tree.txt"];
        if ([context.viewTreeText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) [files addObject:path];
    }
    if (context.viewControllersText.length) {
        NSString *path = [base stringByAppendingPathComponent:@"view_controllers.txt"];
        if ([context.viewControllersText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) [files addObject:path];
    }
    if (context.screenshotPNG.length) {
        NSString *path = [base stringByAppendingPathComponent:@"screenshot.png"];
        if ([context.screenshotPNG writeToFile:path atomically:YES]) [files addObject:path];
    }
    NSMutableArray<NSString *> *classNames = [NSMutableArray array];
    for (NSString *name in context.pageClassNames) {
        if (name.length && classNames.count < 200) [classNames addObject:name];
    }
    NSString *classPath = [base stringByAppendingPathComponent:@"classes"];
    [manager createDirectoryAtPath:classPath withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in classNames) {
        Class cls = NSClassFromString(name);
        NSString *header = cls ? DKClassDumpHeaderForClass(cls) : nil;
        if (!header.length) continue;
        NSString *safeName = [[name componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."] invertedSet]] componentsJoinedByString:@"_"];
        NSString *path = [classPath stringByAppendingPathComponent:[safeName stringByAppendingPathExtension:@"h"]];
        if ([header writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) [files addObject:path];
    }
    if (files.count == 0) { DYYYDebugPresentAlert(presenter, @"调试导出失败", @"没有可写入的页面信息"); return; }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      NSError *zipError = nil;
      BOOL success = [DKZipWriter createZipAtPath:zipPath rootDir:base files:files progress:nil error:&zipError];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (!success) { DYYYDebugPresentAlert(presenter, @"调试导出失败", zipError.localizedDescription ?: @"无法创建 ZIP"); return; }
        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:zipPath]] applicationActivities:nil];
        UIPopoverPresentationController *popover = share.popoverPresentationController;
        if (popover) { popover.sourceView = presenter.view; popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1); }
        [presenter presentViewController:share animated:YES completion:nil];
      });
    });
}

static void DYYYDebugShowActions(UIWindow *window) {
    UIViewController *presenter = DKDebugTopPresenter(window);
    if (!presenter) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"DYYY 调试工具" message:DYYYDebugRecording ? @"正在记录首页刷新、模型切换和页面状态。出现问题后停止并导出。" : @"手动开始记录，复现问题后停止并导出。每段最多保存 12000 个事件，超出数量会写入报告。" preferredStyle:UIAlertControllerStyleActionSheet];
    if (DYYYDebugRecording) {
        [menu addAction:[UIAlertAction actionWithTitle:@"停止记录并导出" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            DYYYDebugStopRecording();
            DYYYDebugExportCurrentPage(presenter, window);
        }]];
    } else {
        [menu addAction:[UIAlertAction actionWithTitle:@"开始记录（覆盖上一段）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugStartRecording(window); }]];
        if (DYYYDebugStoppedAt) {
            [menu addAction:[UIAlertAction actionWithTitle:@"重新导出上次记录" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugExportCurrentPage(presenter, window); }]];
        }
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"导出当前页 ZIP" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugExportCurrentPage(presenter, window); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) { popover.sourceView = presenter.view; popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1); }
    [presenter presentViewController:menu animated:YES completion:nil];
}

static void DYYYDebugInstallOnWindow(UIWindow *window) {
    if (!window || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"]) return;
    UIButton *existing = objc_getAssociatedObject(window, &kDYYYDebugButtonKey);
    if (existing) return;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(window.bounds.size.width - 74, window.bounds.size.height * 0.68, 56, 56);
    button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    button.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    button.layer.cornerRadius = 28;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    UIImage *image = [UIImage systemImageNamed:@"wrench.and.screwdriver"] ?: [UIImage systemImageNamed:@"wrench"];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = DYYYDebugRecording ? UIColor.systemRedColor : UIColor.whiteColor;
    button.accessibilityLabel = @"DYYY 调试工具";
    DYYYDebugDrag *drag = [DYYYDebugDrag new];
    drag.window = window;
    drag.button = button;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:drag action:@selector(handlePan:)];
    [button addGestureRecognizer:pan];
    [button addTarget:drag action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(window, &kDYYYDebugDragKey, drag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [window addSubview:button];
    objc_setAssociatedObject(window, &kDYYYDebugButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void DYYYDebugInspectorRefreshOverlay(void) {
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"];
    for (UIWindow *window in DKDebugActiveWindows()) {
        UIButton *button = objc_getAssociatedObject(window, &kDYYYDebugButtonKey);
        button.tintColor = DYYYDebugRecording ? UIColor.systemRedColor : UIColor.whiteColor;
        button.accessibilityLabel = DYYYDebugRecording ? @"DYYY 调试工具：正在记录" : @"DYYY 调试工具";
        if (!enabled) {
            [button removeFromSuperview];
            objc_setAssociatedObject(window, &kDYYYDebugButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(window, &kDYYYDebugDragKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            DYYYDebugInstallOnWindow(window);
        }
    }
}

void DYYYDebugInspectorInstall(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      DYYYDebugInstalledHooks = [NSMutableSet set];
      DYYYDebugHookStatus = [NSMutableArray array];
      for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification, UIApplicationWillEnterForegroundNotification ]) {
          [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DYYYDebugRecordEvent(note.name, nil, NO); }];
      }
      [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { DYYYDebugInspectorRefreshOverlay(); }];
    });
    dispatch_async(dispatch_get_main_queue(), ^{ DYYYDebugInspectorRefreshOverlay(); });
}
