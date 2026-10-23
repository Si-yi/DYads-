#import "DYYYDebugInspector.h"
#import "DKDebugCapture.h"
#import "DKClassDump.h"
#import "DKZipWriter.h"
#import "DYYYConstants.h"
#import <objc/runtime.h>
#include <string.h>
#include <math.h>
#import <mach-o/dyld.h>

static char kDYYYDebugButtonKey;
static char kDYYYDebugDragKey;
static void DYYYDebugShowActions(UIWindow *window);
static NSString *const DYYYDebugOverlayIdentifier = @"DYYY.DebugInspector.SingleOverlay.r2";

// 进程内共享键，避免不同编译单元或重复加载时各自认领一个按钮。
static const void *DYYYDebugSharedButtonKey(void) {
    return (const void *)sel_registerName("DYYYDebugInspector.sharedOverlayButton");
}

static BOOL DYYYDebugIsOverlay(UIView *view) {
    return [view isKindOfClass:UIButton.class] &&
        ([view.accessibilityIdentifier isEqualToString:DYYYDebugOverlayIdentifier] ||
         [view.accessibilityLabel hasPrefix:@"DYYY 调试工具"]);
}

static void DYYYDebugKeepOnlyOverlay(UIWindow *window, UIButton *keep) {
    for (UIView *view in [window.subviews copy]) {
        if (view != keep && DYYYDebugIsOverlay(view)) [view removeFromSuperview];
    }
    objc_setAssociatedObject(window, DYYYDebugSharedButtonKey(), keep, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 独立的非 key 透明窗口：按钮始终高于应用设置页、插件弹窗，空白位置透传触摸。
@interface DYYYDebugOverlayWindow : UIWindow
@end
@implementation DYYYDebugOverlayWindow
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self || hit == self.rootViewController.view ? nil : hit;
}
@end

@interface DYYYDebugOverlayRootController : UIViewController
@end
@implementation DYYYDebugOverlayRootController
- (void)loadView {
    self.view = [UIView new];
    self.view.backgroundColor = UIColor.clearColor;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    DYYYDebugInspectorRefreshOverlay();
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
@end

static DYYYDebugOverlayWindow *DYYYDebugFloatingWindow;
static __weak UIWindow *DYYYDebugContentWindow;
static BOOL DYYYDebugOverlayRefreshing;

static UIWindow *DYYYDebugCurrentContentWindow(void) {
    UIWindow *window = DYYYDebugContentWindow;
    if (window && !window.hidden && window.alpha > 0.01) return window;
    return DKDebugTargetWindow();
}


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
            NSString *className = NSStringFromClass(view.class);
            if ([className containsString:@"CommentInputContainerView"] || [className containsString:@"CommentInputViewMiddleContainer"] ||
                [view.accessibilityIdentifier hasPrefix:@"DYYY.AdaptiveCommentInput"]) {
                [state addObject:@{ @"inputView": className, @"frame": NSStringFromCGRect(view.frame),
                    @"bounds": NSStringFromCGRect(view.bounds), @"hidden": @(view.hidden),
                    @"implementation": view.accessibilityIdentifier ?: @"" }];
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

@interface DYYYDebugOverlayDragR2 : NSObject
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, weak) UIButton *button;
- (void)handleTap;
@end

@implementation DYYYDebugOverlayDragR2
- (void)handleTap {
    DYYYDebugShowActions(DYYYDebugCurrentContentWindow());
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIButton *button = self.button;
    UIWindow *window = self.window;
    if (!button || !window) return;
    // 拖动只移动当前对象，同时清理历史重复按钮。
    DYYYDebugKeepOnlyOverlay(window, button);
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
    return [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
}

static NSDictionary *DYYYDebugMetadata(void) {
    NSMutableArray *pluginImages = [NSMutableArray array];
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        const char *path = _dyld_get_image_name(index);
        NSString *name = path ? [NSString stringWithUTF8String:path] : nil;
        if (name && ([name rangeOfString:@"DYYY" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                     [name rangeOfString:@"AutoMessage" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                     [name rangeOfString:@"DYKiller" options:NSCaseInsensitiveSearch].location != NSNotFound)) [pluginImages addObject:name];
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return @{
        @"plugin": @"DYYY",
        @"pluginVersion": DYYY_VERSION,
        @"generatedAt": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier ?: @"",
        @"appVersion": NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",
        @"buildVersion": NSBundle.mainBundle.infoDictionary[(NSString *)kCFBundleVersionKey] ?: @"",
        @"systemName": UIDevice.currentDevice.systemName ?: @"",
        @"systemVersion": UIDevice.currentDevice.systemVersion ?: @"",
        @"deviceModel": UIDevice.currentDevice.model ?: @"",
        @"debugImplementation": @"global-overlay-r4-keyboard-theme",
        @"loadedPluginImages": pluginImages,
        @"inputSettings": @{
            @"DYYYEnableFloatingCommentInput": [defaults objectForKey:@"DYYYEnableFloatingCommentInput"] ?: NSNull.null,
            @"DYYYEnableFullScreen": [defaults objectForKey:@"DYYYEnableFullScreen"] ?: NSNull.null,
            @"DYYYEnableCommentBlur": [defaults objectForKey:@"DYYYEnableCommentBlur"] ?: NSNull.null
        }
    };
}

static NSData *DYYYDebugLightScreenshot(NSData *png) {
    if (!png.length) return nil;
    UIImage *source = [UIImage imageWithData:png];
    if (!source || source.size.width <= 0 || source.size.height <= 0) return nil;
    CGFloat ratio = MIN(1, 1280.0 / MAX(source.size.width, source.size.height));
    CGSize size = CGSizeMake(MAX(1, round(source.size.width * ratio)), MAX(1, round(source.size.height * ratio)));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        [source drawInRect:(CGRect){CGPointZero, size}];
    }];
    return UIImageJPEGRepresentation(image, 0.70);
}

static void DYYYDebugExportCurrentPage(UIViewController *presenter, UIWindow *window, BOOL detailed, BOOL messageInterfaces) {
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
    NSMutableDictionary *metadata = [DYYYDebugMetadata() mutableCopy];
    metadata[@"exportMode"] = messageInterfaces ? @"message-interfaces" : (detailed ? @"complete" : @"lightweight");
    writeJSON(@"metadata.json", metadata);
    if (messageInterfaces) {
        // 仅导出抖音自身的运行时声明，不执行联系人查询、消息读取或发送方法。
        // 独立实现需要真实参数签名；普通页面树不包含底层 IM 服务接口。
        NSArray<NSString *> *priority = @[
            @"AWEIMUserDBManager", @"AWEIMUserManager", @"AWEIMSDKManager", @"AWEIMService",
            @"TIMXOSendMessage", @"TIMXSenderMessageTemplate", @"TIMXOMessageManager",
            @"TIMXOConversationManager", @"TIMXOConversation", @"TIMXOMessage", @"TIMXOUser",
            @"IESIMSendMessageModel", @"IESIMMessageSender", @"IESIMConversationDataManager",
            @"IESIMService", @"AWEUserModel", @"AWEUser", @"AWEAwemeModel"
        ];
        NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
        NSMutableArray<NSString *> *missing = [NSMutableArray array];
        for (NSString *name in priority) {
            if (NSClassFromString(name)) [names addObject:name]; else [missing addObject:name];
        }
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        NSArray<NSString *> *terms = @[@"message", @"conversation", @"contact", @"user", @"sender", @"sdk", @"session", @"account"];
        for (unsigned int index = 0; index < classCount; index++) {
            NSString *name = NSStringFromClass(classes[index]);
            if (![name hasPrefix:@"TIMX"] && ![name hasPrefix:@"IESIM"] && ![name hasPrefix:@"AWEIM"]) continue;
            if (DKClassNameIsRuntimeGenerated(name)) continue;
            if ([name containsString:@"View"] || [name containsString:@"Controller"] || [name containsString:@"Cell"]) continue;
            NSString *lower = name.lowercaseString;
            for (NSString *term in terms) {
                if ([lower containsString:term]) { [candidates addObject:name]; break; }
            }
        }
        free(classes);
        [candidates sortUsingSelector:@selector(compare:)];
        NSUInteger matchingCount = candidates.count;
        for (NSString *name in candidates) {
            if (names.count >= 120) break;
            [names addObject:name];
        }
        NSString *folder = [base stringByAppendingPathComponent:@"im-interfaces"];
        [manager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSMutableArray *written = [NSMutableArray array];
        NSMutableArray *unavailable = [NSMutableArray array];
        for (NSString *name in names) {
            Class cls = NSClassFromString(name);
            NSString *header = cls ? DKClassDumpHeaderForClass(cls) : nil;
            NSString *path = [folder stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"h"]];
            if (header.length && [header writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
                [files addObject:path];
                const char *imageName = class_getImageName(cls);
                [written addObject:@{ @"name":name, @"image":imageName ? [[NSString stringWithUTF8String:imageName] lastPathComponent] : @"" }];
            } else [unavailable addObject:name];
        }
        writeJSON(@"im-interfaces/index.json", @{ @"formatVersion":@1, @"classes":written,
            @"missingPriorityClasses":missing, @"unavailableClasses":unavailable,
            @"matchingClassCount":@(matchingCount), @"classLimit":@120,
            @"collection":@"runtime-declarations-only" });
    }
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
        NSData *startImage = detailed ? DYYYDebugStartContext.screenshotPNG : DYYYDebugLightScreenshot(DYYYDebugStartContext.screenshotPNG);
        NSString *startPath = [base stringByAppendingPathComponent:detailed ? @"recording/start-screenshot.png" : @"recording/start-screenshot.jpg"];
        if (startImage && [startImage writeToFile:startPath atomically:YES]) [files addObject:startPath];
    }
    writeJSON(@"windows.json", context.windowsJSON ?: @[]);
    writeJSON(@"view_tree.json", context.viewTreeJSON ?: @[]);
    writeJSON(@"selected_view.json", context.selectedViewJSON ?: @{});
    if (detailed) writeJSON(@"layers.json", context.layersJSON ?: @[]);
    if (context.viewTreeText.length) {
        NSString *path = [base stringByAppendingPathComponent:@"view_tree.txt"];
        if ([context.viewTreeText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) [files addObject:path];
    }
    if (context.viewControllersText.length) {
        NSString *path = [base stringByAppendingPathComponent:@"view_controllers.txt"];
        if ([context.viewControllersText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) [files addObject:path];
    }
    if (context.screenshotPNG.length) {
        NSString *path = [base stringByAppendingPathComponent:detailed ? @"screenshot.png" : @"screenshot.jpg"];
        NSData *screenshot = detailed ? context.screenshotPNG : DYYYDebugLightScreenshot(context.screenshotPNG);
        if (screenshot && [screenshot writeToFile:path atomically:YES]) [files addObject:path];
    }
    NSMutableArray<NSString *> *classNames = [NSMutableArray array];
    for (NSString *name in context.pageClassNames) {
        if (name.length && classNames.count < 200) [classNames addObject:name];
    }
    NSString *classPath = [base stringByAppendingPathComponent:@"classes"];
    [manager createDirectoryAtPath:classPath withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in (detailed ? classNames : @[])) {
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
        [menu addAction:[UIAlertAction actionWithTitle:@"停止记录并导出（轻量）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            DYYYDebugStopRecording();
            DYYYDebugExportCurrentPage(presenter, window, NO, NO);
        }]];
    } else {
        [menu addAction:[UIAlertAction actionWithTitle:@"开始记录（覆盖上一段）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugStartRecording(window); }]];
        if (DYYYDebugStoppedAt) {
            [menu addAction:[UIAlertAction actionWithTitle:@"重新导出上次记录（轻量）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugExportCurrentPage(presenter, window, NO, NO); }]];
        }
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"导出当前页（轻量）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugExportCurrentPage(presenter, window, NO, NO); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"导出消息接口（独立开发）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugExportCurrentPage(presenter, window, NO, YES); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"完整导出（含图层和类头文件）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { DYYYDebugExportCurrentPage(presenter, window, YES, NO); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) { popover.sourceView = presenter.view; popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1); }
    [presenter presentViewController:menu animated:YES completion:nil];
}

static void DYYYDebugInstallOnWindow(UIWindow *window) {
    if (!window || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"]) return;
    UIButton *existing = objc_getAssociatedObject(window, DYYYDebugSharedButtonKey());
    if (existing.superview == window && [existing.accessibilityIdentifier isEqualToString:DYYYDebugOverlayIdentifier]) {
        DYYYDebugKeepOnlyOverlay(window, existing);
        UIColor *color = DYYYDebugRecording ? UIColor.systemRedColor : UIColor.whiteColor;
        if (![existing.tintColor isEqual:color]) existing.tintColor = color;
        NSString *label = DYYYDebugRecording ? @"DYYY 调试工具：正在记录" : @"DYYY 调试工具";
        if (![existing.accessibilityLabel isEqualToString:label]) existing.accessibilityLabel = label;
        return;
    }
    CGRect previousFrame = CGRectZero;
    for (UIView *view in window.subviews) {
        if (DYYYDebugIsOverlay(view)) { previousFrame = view.frame; break; }
    }
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectIsEmpty(previousFrame) ? CGRectMake(window.bounds.size.width - 74, window.bounds.size.height * 0.68, 56, 56) : previousFrame;
    button.accessibilityIdentifier = DYYYDebugOverlayIdentifier;
    button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    button.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    button.layer.cornerRadius = 28;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    UIImage *image = [UIImage systemImageNamed:@"wrench.and.screwdriver"] ?: [UIImage systemImageNamed:@"wrench"];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = DYYYDebugRecording ? UIColor.systemRedColor : UIColor.whiteColor;
    button.accessibilityLabel = @"DYYY 调试工具";
    DYYYDebugOverlayDragR2 *drag = [DYYYDebugOverlayDragR2 new];
    drag.window = window;
    drag.button = button;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:drag action:@selector(handlePan:)];
    [button addGestureRecognizer:pan];
    [button addTarget:drag action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(window, &kDYYYDebugDragKey, drag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [window addSubview:button];
    objc_setAssociatedObject(window, &kDYYYDebugButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DYYYDebugKeepOnlyOverlay(window, button);
}

void DYYYDebugInspectorRefreshOverlay(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ DYYYDebugInspectorRefreshOverlay(); });
        return;
    }
    if (DYYYDebugOverlayRefreshing) return;
    DYYYDebugOverlayRefreshing = YES;
    @try {
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            if (!DYYYDebugFloatingWindow.hidden) DYYYDebugFloatingWindow.hidden = YES;
            return;
        }
        BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"];
        NSArray<UIWindow *> *windows = DKDebugActiveWindows();
        UIWindow *target = nil;
        CGFloat highestLevel = UIWindowLevelAlert;
        for (UIWindow *window in windows) {
            NSString *name = NSStringFromClass(window.class);
            if ([name hasPrefix:@"DYYYDebug"] || [name containsString:@"TextEffects"] || [name containsString:@"Keyboard"] || !window.rootViewController) continue;
            highestLevel = MAX(highestLevel, window.windowLevel);
            if (!target || window.isKeyWindow) target = window;
        }
        // 清理以前挂在普通窗口里的旧按钮，避免进入设置页面后又产生第二个。
        for (UIWindow *window in windows) {
            if ([window isKindOfClass:DYYYDebugOverlayWindow.class]) continue;
            DYYYDebugKeepOnlyOverlay(window, nil);
            objc_setAssociatedObject(window, &kDYYYDebugButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(window, &kDYYYDebugDragKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!enabled || !target) {
            if (!DYYYDebugFloatingWindow.hidden) DYYYDebugFloatingWindow.hidden = YES;
            return;
        }
        DYYYDebugContentWindow = target;
        const void *sharedWindowKey = (const void *)sel_registerName("DYYYDebugInspector.sharedOverlayWindow");
        DYYYDebugOverlayWindow *sharedWindow = objc_getAssociatedObject(UIApplication.sharedApplication, sharedWindowKey);
        if (!DYYYDebugFloatingWindow && [sharedWindow isKindOfClass:DYYYDebugOverlayWindow.class]) DYYYDebugFloatingWindow = sharedWindow;
        if (DYYYDebugFloatingWindow && DYYYDebugFloatingWindow.windowScene != target.windowScene) {
            DYYYDebugFloatingWindow.hidden = YES;
            DYYYDebugFloatingWindow = nil;
        }
        if (!DYYYDebugFloatingWindow) {
            DYYYDebugFloatingWindow = target.windowScene ? [[DYYYDebugOverlayWindow alloc] initWithWindowScene:target.windowScene] : [[DYYYDebugOverlayWindow alloc] initWithFrame:target.bounds];
            DYYYDebugFloatingWindow.backgroundColor = UIColor.clearColor;
            DYYYDebugFloatingWindow.rootViewController = [DYYYDebugOverlayRootController new];
            objc_setAssociatedObject(UIApplication.sharedApplication, sharedWindowKey, DYYYDebugFloatingWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (DYYYDebugFloatingWindow.windowLevel != highestLevel + 1) DYYYDebugFloatingWindow.windowLevel = highestLevel + 1;
        CGRect frame = target.windowScene ? target.windowScene.coordinateSpace.bounds : target.bounds;
        if (!CGRectEqualToRect(DYYYDebugFloatingWindow.frame, frame)) DYYYDebugFloatingWindow.frame = frame;
        if (DYYYDebugFloatingWindow.hidden) DYYYDebugFloatingWindow.hidden = NO; // 不调用 makeKey，避免抢走键盘和当前页面焦点。
        DYYYDebugInstallOnWindow(DYYYDebugFloatingWindow);
        UIButton *button = objc_getAssociatedObject(DYYYDebugFloatingWindow, DYYYDebugSharedButtonKey());
        if (button) {
            if (button.hidden) button.hidden = NO;
            if (DYYYDebugFloatingWindow.subviews.lastObject != button) [DYYYDebugFloatingWindow bringSubviewToFront:button];
            CGFloat radius = CGRectGetWidth(button.bounds) / 2;
            UIEdgeInsets safe = DYYYDebugFloatingWindow.safeAreaInsets;
            CGPoint center = button.center;
            center.x = MIN(MAX(center.x, radius + 10), CGRectGetWidth(frame) - radius - 10);
            center.y = MIN(MAX(center.y, safe.top + radius + 10), CGRectGetHeight(frame) - safe.bottom - radius - 10);
            if (!CGPointEqualToPoint(button.center, center)) button.center = center;
        }
    } @finally {
        DYYYDebugOverlayRefreshing = NO;
    }
}


void DYYYDebugInspectorInstall(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      // 窗口/场景切换时迁移同一个悬浮层；普通导航 push/present 不会再遮住按钮。
      for (NSString *name in @[ UIWindowDidBecomeVisibleNotification, UIWindowDidBecomeKeyNotification, UIWindowDidBecomeHiddenNotification, UISceneDidActivateNotification, UISceneWillDeactivateNotification, UIApplicationDidEnterBackgroundNotification ]) {
          [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
              DYYYDebugInspectorRefreshOverlay();
          }];
      }
      DYYYDebugInstalledHooks = [NSMutableSet set];
      DYYYDebugHookStatus = [NSMutableArray array];
      for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification, UIApplicationWillEnterForegroundNotification ]) {
          [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DYYYDebugRecordEvent(note.name, nil, NO); }];
      }
      for (NSString *name in @[ @"DYYYCommentInputThemeDidChange", UIKeyboardWillShowNotification, UIKeyboardWillChangeFrameNotification, UIKeyboardDidChangeFrameNotification, UIKeyboardDidHideNotification,
          UITextViewTextDidBeginEditingNotification, UITextViewTextDidChangeNotification, UITextViewTextDidEndEditingNotification ]) {
          [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
              if (!DYYYDebugRecording) return;
              NSMutableDictionary *details = [NSMutableDictionary dictionary];
              if ([note.name isEqualToString:@"DYYYCommentInputThemeDidChange"]) [details addEntriesFromDictionary:note.userInfo ?: @{}];
              if ([note.object isKindOfClass:UITextView.class]) {
                  UITextView *input = (UITextView *)note.object;
                  details[@"keyboardAppearance"] = @(input.keyboardAppearance);
                  details[@"effectiveStyle"] = @(input.traitCollection.userInterfaceStyle);
                  details[@"overrideStyle"] = @(input.overrideUserInterfaceStyle);
              }

              NSValue *frame = note.userInfo[UIKeyboardFrameEndUserInfoKey];
              if (frame) details[@"keyboardFrame"] = NSStringFromCGRect(frame.CGRectValue);
              if ([note.object isKindOfClass:UITextView.class]) details[@"textLength"] = @(((UITextView *)note.object).text.length);
              DYYYDebugRecordEvent(note.name, details, NO);
              DYYYDebugSamplePage();
          }];
      }
      [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { DYYYDebugInspectorRefreshOverlay(); }];
    });
    dispatch_async(dispatch_get_main_queue(), ^{ DYYYDebugInspectorRefreshOverlay(); });
}



