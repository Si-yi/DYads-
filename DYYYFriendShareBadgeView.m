#import "DYYYFriendShareBadgeView.h"
#import "DYYYFriendShareService.h"
#import "DYYYFriendShareBadgeMetrics.h"
#import "DYYYFeedTagGlass.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYFriendShareBadgeKey;

@interface DYYYFriendShareBadgeView ()
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *suffixLabel;
@property (nonatomic, weak) UIView *anchor;
@property (nonatomic, strong) NSMapTable<UIView *, NSValue *> *nativeTagFrames;
@property (nonatomic, assign) BOOL layoutPending;
@property (nonatomic, assign) NSUInteger occupiedTagCount;
@property (nonatomic, assign) CGFloat captionTop;
@property (nonatomic, copy) NSString *avatarURL;
@property (nonatomic, strong) NSURLSessionDataTask *avatarTask;
@end

@implementation DYYYFriendShareBadgeView

+ (NSHashTable<UIViewController *> *)controllers {
    static NSHashTable *controllers; static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}

+ (NSCache<NSString *, UIImage *> *)avatarCache {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 64; cache.totalCostLimit = 1024 * 1024; });
    return cache;
}
- (instancetype)init {
    // 固定使用深色薄磨砂，视频明暗变化时白字仍有对比度，不绘制白色实底。
    self = [super initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    if (self) {
        self.nativeTagFrames = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsOpaquePersonality valueOptions:NSPointerFunctionsStrongMemory];
        self.userInteractionEnabled = NO;
        self.layer.cornerRadius = 8;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
        self.clipsToBounds = YES;
        self.accessibilityIdentifier = @"DYads.FriendShareSource";
        self.isAccessibilityElement = YES;
        self.avatarView = [UIImageView new];
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.layer.cornerRadius = 10;
        self.avatarView.clipsToBounds = YES;
        self.avatarView.tintColor = UIColor.whiteColor;
        [self.contentView addSubview:self.avatarView];
        self.nameLabel = [UILabel new];
        self.nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        self.nameLabel.textColor = UIColor.whiteColor;
        self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:self.nameLabel];
        self.suffixLabel = [UILabel new];
        self.suffixLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        self.suffixLabel.textColor = UIColor.whiteColor;
        self.suffixLabel.text = @"分享给你";
        [self.contentView addSubview:self.suffixLabel];
    }
    return self;
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat nameWidth = ceil([self.nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20)].width);
    CGFloat suffixWidth = ceil([self.suffixLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20)].width);
    return CGSizeMake(MIN(size.width, 6 + 20 + 6 + nameWidth + 5 + suffixWidth + 8), 30);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarView.frame = CGRectMake(6, 5, 20, 20);
    CGFloat suffix = ceil([self.suffixLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20)].width);
    CGFloat name = MAX(0, CGRectGetWidth(self.bounds) - 32 - 5 - suffix - 8);
    self.nameLabel.frame = CGRectMake(32, 5, name, 20);
    self.suffixLabel.frame = CGRectMake(32 + name + 5, 5, suffix, 20);
}
- (void)setSource:(NSDictionary *)source {
    self.nameLabel.text = source[@"name"];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@分享给你", self.nameLabel.text ?: @"好友"];
    NSString *url = [source[@"avatar"] isKindOfClass:NSString.class] ? source[@"avatar"] : @"";
    if ([self.avatarURL isEqual:url]) return;
    [self.avatarTask cancel]; self.avatarTask = nil; self.avatarURL = url;
    self.avatarView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    UIImage *cached = url.length ? [[self.class avatarCache] objectForKey:url] : nil;
    if (cached) { self.avatarView.image = cached; return; }
    NSURL *address = [NSURL URLWithString:url];
    if (!([address.scheme.lowercaseString isEqual:@"https"] || [address.scheme.lowercaseString isEqual:@"http"])) return;
    __weak typeof(self) weakSelf = self;
    self.avatarTask = [NSURLSession.sharedSession dataTaskWithURL:address completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data.length || data.length > 5 * 1024 * 1024) return;
        UIImage *image = [UIImage imageWithData:data];
        if (!image) return;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20, 20)];
        UIImage *thumbnail = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [image drawInRect:CGRectMake(0, 0, 20, 20)]; }];
        [[DYYYFriendShareBadgeView avatarCache] setObject:thumbnail forKey:url cost:(NSUInteger)(thumbnail.size.width * thumbnail.size.height * thumbnail.scale * thumbnail.scale * 4)];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([weakSelf.avatarURL isEqual:url]) weakSelf.avatarView.image = thumbnail;
        });
    }];
    [self.avatarTask resume];
}
+ (UIView *)captionStackInView:(UIView *)root {
    // 只在交互层内部找一次左侧文案栈，避免每次布局遍历整个窗口。
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger i = 0; i < queue.count && i < 180; i++) {
        UIView *view = queue[i];
        if ([NSStringFromClass(view.class) isEqual:@"AWEElementStackView"] && !view.hidden && view.alpha > 0.01) {
            CGRect frame = [view convertRect:view.bounds toView:root];
            if (frame.origin.x < CGRectGetWidth(root.bounds) * 0.25 && frame.size.width > CGRectGetWidth(root.bounds) * 0.4 && frame.size.height > 0) return view;
        }
        if (!view.hidden && view.alpha > 0.01 && queue.count < 180) [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}
+ (UIView *)authorRowInStack:(UIView *)stack {
    // 按原生作者协议识别昵称行，不能把上方分享/标签行的预留高度算进间距。
    Protocol *authorProtocol = NSProtocolFromString(@"AWEPlayInteractionAuthorElementProtocol");
    Class rowClass = NSClassFromString(@"AWEBaseElementView");
    if (!authorProtocol || !rowClass) return nil;
    for (UIView *row in stack.subviews) {
        if (![row isKindOfClass:rowClass] || row.hidden || row.alpha <= 0.01 || CGRectIsEmpty(row.bounds)) continue;
        id element = nil;
        @try { element = [row valueForKey:@"element"]; } @catch (__unused NSException *exception) { continue; }
        if ([element conformsToProtocol:authorProtocol]) return row;
    }
    return nil;
}
+ (void)resetForController:(UIViewController *)controller {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self resetForController:controller]; }); return; }
    DYYYFriendShareBadgeView *badge = objc_getAssociatedObject(controller, &kDYYYFriendShareBadgeKey);
    [badge.avatarTask cancel]; badge.avatarTask = nil; badge.avatarURL = nil;
    [badge removeFromSuperview];
    [[self controllers] removeObject:controller];
    objc_setAssociatedObject(controller, &kDYYYFriendShareBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (BOOL)visibleAnchor:(UIView *)anchor root:(UIView *)root {
    for (UIView *view = anchor; view && view != root; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
    }
    return YES;
}
#pragma mark - 原生标签避让
+ (CGRect)visibleFrameForView:(UIView *)view root:(UIView *)root {
    if (!view || !root || ![view isDescendantOfView:root] || CGRectIsEmpty(view.bounds)) return CGRectNull;
    CGRect frame = [view convertRect:view.bounds toView:root];
    for (UIView *parent = view; parent; parent = parent.superview) {
        if (parent.hidden || parent.alpha <= 0.01) return CGRectNull;
        if (parent.clipsToBounds || parent == root) frame = CGRectIntersection(frame, [parent convertRect:parent.bounds toView:root]);
        if (CGRectIsNull(frame) || CGRectIsEmpty(frame)) return CGRectNull;
        if (parent == root) return frame;
    }
    return CGRectNull;
}
+ (NSArray<NSDictionary<NSString *, NSNumber *> *> *)occupiedTagFramesInStack:(UIView *)stack root:(UIView *)root {
    NSMutableArray *frames = [NSMutableArray array];
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:stack];
    for (NSUInteger i = 0; i < queue.count && i < 160; i++) {
        UIView *view = queue[i];
        if (view.hidden || view.alpha <= 0.01) continue;
        if ([DYYYFeedTagGlass isLabelView:view]) {
            CGRect frame = [self visibleFrameForView:view root:root];
            if (!CGRectIsNull(frame) && !CGRectIsEmpty(frame)) [frames addObject:@{ @"x":@(CGRectGetMinX(frame)), @"y":@(CGRectGetMinY(frame)), @"width":@(CGRectGetWidth(frame)), @"height":@(CGRectGetHeight(frame)) }];
            continue; // 原生标签自己的文字/头像/玻璃不重复计入。
        }
        if ([view isKindOfClass:UILabel.class] || [view isKindOfClass:UIImageView.class] ||
            [view isKindOfClass:UIVisualEffectView.class] || [view isKindOfClass:UIScrollView.class]) continue;
        for (UIView *child in view.subviews) { if (queue.count >= 160) break; [queue addObject:child]; }
    }
    return frames;
}
+ (void)nativeTagUpdated:(UIView *)tag {
    if (!NSThread.isMainThread || !tag || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYFriendShareFeedEnabled"]) return;
    UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:tag];
    Class interaction = NSClassFromString(@"AWEPlayInteractionViewController");
    for (NSUInteger i = 0; controller && i < 8; i++, controller = controller.parentViewController) {
        if (![controller isKindOfClass:interaction]) continue;
        DYYYFriendShareBadgeView *badge = objc_getAssociatedObject(controller, &kDYYYFriendShareBadgeKey);
        if (!badge || !badge.anchor || ![tag isDescendantOfView:badge.anchor]) return;
        CGRect frame = [self visibleFrameForView:tag root:controller.view];
        NSValue *old = [badge.nativeTagFrames objectForKey:tag];
        if (old && CGRectEqualToRect(old.CGRectValue, frame)) return;
        if (badge.nativeTagFrames.count >= 128) return;
        [badge.nativeTagFrames setObject:[NSValue valueWithCGRect:frame] forKey:tag];
        if (badge.layoutPending) return;
        badge.layoutPending = YES;
        __weak UIViewController *weakController = controller;
        __weak DYYYFriendShareBadgeView *weakBadge = badge;
        dispatch_async(dispatch_get_main_queue(), ^{
            DYYYFriendShareBadgeView *current = weakBadge;
            UIViewController *owner = weakController;
            if (!current) return;
            current.layoutPending = NO;
            if (!owner || objc_getAssociatedObject(owner, &kDYYYFriendShareBadgeKey) != current || !owner.view.window) return;
            [self updateForController:owner];
        });
        return;
    }
}
+ (NSDictionary *)diagnosticsForController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller) return @{};
    DYYYFriendShareBadgeView *badge = objc_getAssociatedObject(controller, &kDYYYFriendShareBadgeKey);
    if (!badge) return @{ @"present":@NO };
    return @{ @"present":@YES, @"hidden":@(badge.hidden), @"frame":NSStringFromCGRect(badge.frame),
        @"captionTop":@(badge.captionTop), @"nativeTagCount":@(badge.occupiedTagCount), @"layoutPending":@(badge.layoutPending),
        @"policy":@"above_visible_native_tags" };
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSMutableArray *visible = [NSMutableArray array];
    NSUInteger inspected = 0;
    for (UIViewController *controller in [self controllers]) {
        if (++inspected > 32 || visible.count >= 8) break;
        if (!controller.isViewLoaded || !controller.view.window) continue;
        CGRect frame = [controller.view convertRect:controller.view.bounds toView:controller.view.window];
        if (!CGRectIntersectsRect(frame, controller.view.window.bounds)) continue;
        [visible addObject:[self diagnosticsForController:controller]];
    }
    return @{ @"visible":visible, @"policy":@"above_visible_native_tags" };
}
+ (void)updateForController:(UIViewController *)controller {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self updateForController:controller]; }); return; }
    if (!controller.isViewLoaded) return;
    AWEPlayInteractionViewController *interaction = (id)controller;
    NSString *itemID = [interaction.model.itemID isKindOfClass:NSString.class] ? interaction.model.itemID : nil;
    NSDictionary *source = [DYYYFriendShareService shareSourceForItemID:itemID controller:controller];
    DYYYFriendShareBadgeView *badge = objc_getAssociatedObject(controller, &kDYYYFriendShareBadgeKey);
    if (!source || controller.view.hidden || !controller.view.window) { if (badge) [self resetForController:controller]; return; }
    UIView *anchor = badge.anchor;
    if (!anchor || ![anchor isDescendantOfView:controller.view]) anchor = [self captionStackInView:controller.view];
    if (!anchor || ![self visibleAnchor:anchor root:controller.view]) { badge.hidden = YES; return; }
    if (!badge) {
        badge = [self new];
        objc_setAssociatedObject(controller, &kDYYYFriendShareBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller.view addSubview:badge];
        [[self controllers] addObject:controller];
    }
    badge.anchor = anchor;
    [badge setSource:source];
    UIView *authorRow = [self authorRowInStack:anchor];
    UIView *captionAnchor = authorRow ?: anchor;
    CGRect caption = [captionAnchor convertRect:captionAnchor.bounds toView:controller.view];
    CGFloat x = MAX(12, CGRectGetMinX(caption));
    CGFloat maxWidth = MIN(300, CGRectGetWidth(controller.view.bounds) - x - 84);
    CGSize size = [badge sizeThatFits:CGSizeMake(MAX(0, maxWidth), 30)];
    NSArray *occupied = [self occupiedTagFramesInStack:anchor root:controller.view];
    CGFloat top = [DYYYFriendShareBadgeMetrics topForCaptionTop:CGRectGetMinY(caption) badgeX:x width:size.width height:size.height occupiedFrames:occupied];
    badge.captionTop = CGRectGetMinY(caption);
    badge.occupiedTagCount = occupied.count;
    if (!isfinite(top)) { badge.hidden = YES; return; }
    CGRect frame = CGRectMake(x, top, size.width, size.height);
    badge.hidden = size.width < 105 || CGRectGetMinY(frame) < controller.view.safeAreaInsets.top;
    if (!CGRectEqualToRect(badge.frame, frame)) badge.frame = frame;
    badge.alpha = anchor.alpha;
}
- (void)dealloc { [self.avatarTask cancel]; }
@end
