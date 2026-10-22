//
//  DYYYVideoFeedTable.xm
//  视频表撑高与 HUD 钉位，移植自 DYKiller 的 DKVideoFeedTable.xm / DKVideoDetailTable.xm。
//
//  · 首页表、详情页（别人主页里的视频）表在「启用首页全屏」开启时撑到整屏高，撑高前的高度记在表上。
//  · HUD（文案、昵称、右侧按钮、进度条）被钉在撑高前的高度上，底部控件保持原位。
//  · 详情页在建行和分页计算之前先把表撑高，让原生行位置与 Cell 使用相同高度。
//

#import "AwemeHeaders.h"
#import "DYYYVideoFeedTable.h"
#import <math.h>
#import <objc/runtime.h>

#define DYYY_FS_KEY @"DYYYEnableFullScreen"

// 覆盖 @3x 像素对齐带来的亚像素漂移。
static const CGFloat kFeedTolerance = 0.5;
// 表高至少要到容器的这个比例才认作「已排好、只差一个底栏」，排除布局早期的半成品尺寸。
static const CGFloat kFeedMinHeightRatio = 0.5;
// 从 HUD 往上找视频表的最大层数（图文内容多两层容器，取 8 有余量）。
static const NSUInteger kFeedAncestorLimit = 8;

// 撑高前的表高。挂在表上，既是还原依据，也是 HUD 的钉位目标。
static char kFeedOriginalHeightKey;

static BOOL FullscreenOn(void) {
    return DYYYGetBool(DYYY_FS_KEY);
}

static id SafeValue(id object, NSString *key) {
    if (!object) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

#pragma mark - 目标判定

static Class FeedTableClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = NSClassFromString(@"AWEFeedDataSafeTableView"); });
    return cls;
}

static UIView *FeedTableForView(UIView *view) {
    Class tableCls = FeedTableClass();
    if (!tableCls) return nil;
    UIView *ancestor = view.superview;
    for (NSUInteger i = 0; ancestor && i < kFeedAncestorLimit; i++, ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:tableCls]) return ancestor;
    }
    return nil;
}

static NSNumber *FeedTableOriginalHeight(UIView *table) {
    return table ? objc_getAssociatedObject(table, &kFeedOriginalHeightKey) : nil;
}

#pragma mark - 撑高视频表

// 共享撑高规则：表写入与控制器布局入口都走这里；已达到目标高度的写入直接放行。
static CGRect FeedTableAdjustFrameToHeight(UITableView *table, CGRect frame, CGFloat target) {
    if (!FullscreenOn()) {
        // 关闭后一律放行；标记清掉以免 HUD 继续被钉。
        objc_setAssociatedObject(table, &kFeedOriginalHeightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return CGRectNull;
    }

    CGFloat current = CGRectGetHeight(frame);
    // 容器不比来意的高度更高 → 这张表没被底栏压缩过（搜索页、好友聊天页就是这种），不在作用域内；
    // 高度不到容器一半 → 布局早期的半成品，记下它会把 HUD 钉到错误的位置。
    if (!isfinite(target) || !isfinite(current) || target <= 0.0 ||
        current >= target - kFeedTolerance || current < target * kFeedMinHeightRatio) {
        return CGRectNull;
    }

    if (!objc_getAssociatedObject(table, &kFeedOriginalHeightKey)) {
        objc_setAssociatedObject(table, &kFeedOriginalHeightKey, @(current), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    frame.size.height = target;
    return frame;
}

static CGRect FeedTableAdjustFrame(UITableView *table, CGRect frame) {
    return FeedTableAdjustFrameToHeight(table, frame, CGRectGetHeight(table.superview.bounds));
}

// 详情表在建行前可能尚未挂入父视图，此时取已加载控制器根视图的高度。
static BOOL FeedTablePrepareForController(UIViewController *controller, UITableView *table) {
    if (!FullscreenOn() || !NSThread.isMainThread || !table) return NO;
    Class tableClass = FeedTableClass();
    UIView *root = controller.viewIfLoaded;
    if (!tableClass || ![table isKindOfClass:tableClass] || !root) return NO;
    UIWindow *window = table.window ?: root.window;
    if (window && window.windowLevel != UIWindowLevelNormal) return NO;
    if (table.superview && ![table isDescendantOfView:root]) return NO;
    if (!CGAffineTransformIsIdentity(table.transform)) return NO;

    CGFloat target = table.superview ? CGRectGetHeight(table.superview.bounds) : CGRectGetHeight(root.bounds);
    CGRect adjusted = FeedTableAdjustFrameToHeight(table, table.frame, target);
    if (CGRectIsNull(adjusted)) return NO;
    table.frame = adjusted;
    return YES;
}

// 在写入时就改成满高：抖音把表高改回原值（如关闭评论区）的那一刻即被顶回去，不留「切一下才恢复」的空窗。
%hook AWEFeedDataSafeTableView

- (void)setFrame:(CGRect)frame {
    CGRect adjusted = FeedTableAdjustFrame((UITableView *)self, frame);
    if (CGRectIsNull(adjusted)) {
        %orig;
        return;
    }
    %orig(adjusted);
}

%end

%hook AWEFeedTableView

- (void)setFrame:(CGRect)frame {
    CGRect adjusted = FeedTableAdjustFrame((UITableView *)self, frame);
    if (CGRectIsNull(adjusted)) {
        %orig;
        return;
    }
    %orig(adjusted);
}

%end

// 原生布局前后各统一一次表高，使尺寸适配器按同一高度计算行高与滚动锚点。
static void SyncFeedTableLayout(UITableView *table) {
    if (!table) return;
    CGRect adjusted = FeedTableAdjustFrame(table, table.frame);
    if (CGRectIsNull(adjusted)) return;
    table.frame = adjusted;
}

%hook AWEFeedTableViewController

- (void)viewDidLayoutSubviews {
    if (FullscreenOn()) SyncFeedTableLayout(SafeValue(self, @"tableView"));
    %orig;
    if (FullscreenOn()) SyncFeedTableLayout(SafeValue(self, @"tableView"));
}

%end

#pragma mark - 详情页（别人主页里的视频）

static const CGFloat kDetailHeightTolerance = 0.5;

static void PrepareDetailTable(UIViewController *controller) {
    if (!FullscreenOn()) return;
    FeedTablePrepareForController(controller, SafeValue(controller, @"tableView"));
}

// 仅统一已接管表中的整页行高；原生特殊行、自动尺寸和未就绪尺寸继续使用原返回值。
static double DetailRowHeight(UITableView *table, double nativeHeight) {
    if (!FullscreenOn() || !NSThread.isMainThread) return nativeHeight;
    NSNumber *original = FeedTableOriginalHeight(table);
    CGFloat target = CGRectGetHeight(table.bounds);
    if (!original || !isfinite(nativeHeight) || !isfinite(target) || nativeHeight <= 0.0 ||
        target <= original.doubleValue + kDetailHeightTolerance) {
        return nativeHeight;
    }
    if (fabs(nativeHeight - original.doubleValue) > kDetailHeightTolerance &&
        fabs(nativeHeight - target) > kDetailHeightTolerance) {
        return nativeHeight;
    }
    return target;
}

%group DYYYVideoDetailTableHooks

%hook AWEAwemeDetailTableViewController

- (void)setupDetailTableView {
    %orig;
    PrepareDetailTable(self);
}

- (void)viewWillLayoutSubviews {
    PrepareDetailTable(self);
    %orig;
    PrepareDetailTable(self);
}

- (void)viewDidLayoutSubviews {
    if (FullscreenOn()) SyncFeedTableLayout(SafeValue(self, @"tableView"));
    %orig;
    if (FullscreenOn()) SyncFeedTableLayout(SafeValue(self, @"tableView"));
}

- (double)fixedCellHeight {
    if (!FullscreenOn()) return %orig;
    PrepareDetailTable(self);
    double nativeHeight = %orig;
    return DetailRowHeight(SafeValue(self, @"tableView"), nativeHeight);
}

- (double)cellHeightAtIndex:(long long)index {
    if (!FullscreenOn()) return %orig;
    PrepareDetailTable(self);
    double nativeHeight = %orig;
    return DetailRowHeight(SafeValue(self, @"tableView"), nativeHeight);
}

- (double)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!FullscreenOn()) return %orig;
    PrepareDetailTable(self);
    double nativeHeight = %orig;
    return DetailRowHeight(table, nativeHeight);
}

- (double)contentOffsetYForCellAtIndex:(long long)index {
    PrepareDetailTable(self);
    return %orig;
}

- (void)adjustTableViewHeightForTargetIndex:(long long)index {
    PrepareDetailTable(self);
    %orig;
    PrepareDetailTable(self);
}

%end

%end

#pragma mark - HUD 钉位

// 不在已撑高的表内就放行——那种页面的 HUD 本来就该跟着页面走（搜索页、好友聊天页）。
static CGFloat HUDPinnedHeight(UIView *view, CGFloat tabBarDelta) {
    if (!FullscreenOn()) return 0.0;
    NSNumber *original = FeedTableOriginalHeight(FeedTableForView(view));
    if (!original) return 0.0;
    CGFloat pinned = original.doubleValue - tabBarDelta;
    return pinned > 0.0 ? pinned : 0.0;
}

CGRect DYYYFeedHUDAdjustFrame(UIView *view, CGRect frame, CGFloat tabBarDelta) {
    CGFloat pinned = HUDPinnedHeight(view, tabBarDelta);
    if (pinned <= 0.0) return CGRectNull;
    // 只拦「被设成撑高后的满高」这一种写入；缩小态（如评论展开）一律放行。
    if (CGRectGetHeight(frame) <= pinned + kFeedTolerance) return CGRectNull;
    frame.size.height = pinned;
    return frame;
}

BOOL DYYYFeedHUDApplyPin(UIView *hudView, CGFloat tabBarDelta) {
    if (!hudView) return NO;
    CGFloat pinned = HUDPinnedHeight(hudView, tabBarDelta);
    if (pinned <= 0.0) return NO;

    CGRect frame = hudView.frame;
    if (fabs(CGRectGetMinY(frame)) <= kFeedTolerance && CGRectGetHeight(frame) <= pinned + kFeedTolerance) {
        return YES;
    }
    hudView.frame = CGRectMake(CGRectGetMinX(frame), 0.0, CGRectGetWidth(frame), pinned);
    return YES;
}

%ctor {
    Class controllerClass = NSClassFromString(@"AWEAwemeDetailTableViewController");
    if (!controllerClass) return;
    SEL selectors[] = {
        @selector(setupDetailTableView), @selector(viewWillLayoutSubviews),
        @selector(fixedCellHeight), @selector(cellHeightAtIndex:),
        @selector(tableView:heightForRowAtIndexPath:),
        @selector(contentOffsetYForCellAtIndex:),
        @selector(adjustTableViewHeightForTargetIndex:)
    };
    for (SEL selector : selectors) {
        if (!class_getInstanceMethod(controllerClass, selector)) return;
    }
    %init(DYYYVideoDetailTableHooks);
}
