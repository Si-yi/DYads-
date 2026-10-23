#import "DYYYFriendShareBadgeView.h"
#import "DYYYFriendShareService.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYFriendShareBadgeKey;

@interface DYYYFriendShareBadgeView ()
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *suffixLabel;
@property (nonatomic, weak) UIView *anchor;
@property (nonatomic, copy) NSString *avatarURL;
@property (nonatomic, strong) NSURLSessionDataTask *avatarTask;
@end

@implementation DYYYFriendShareBadgeView

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
    objc_setAssociatedObject(controller, &kDYYYFriendShareBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (BOOL)visibleAnchor:(UIView *)anchor root:(UIView *)root {
    for (UIView *view = anchor; view && view != root; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
    }
    return YES;
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
    }
    badge.anchor = anchor;
    [badge setSource:source];
    UIView *authorRow = [self authorRowInStack:anchor];
    UIView *captionAnchor = authorRow ?: anchor;
    CGRect caption = [captionAnchor convertRect:captionAnchor.bounds toView:controller.view];
    CGFloat x = MAX(12, CGRectGetMinX(caption));
    CGFloat maxWidth = MIN(300, CGRectGetWidth(controller.view.bounds) - x - 84);
    CGSize size = [badge sizeThatFits:CGSizeMake(MAX(0, maxWidth), 30)];
    CGRect frame = CGRectMake(x, CGRectGetMinY(caption) - size.height - 6, size.width, size.height);
    badge.hidden = size.width < 105 || CGRectGetMinY(frame) < controller.view.safeAreaInsets.top;
    if (!CGRectEqualToRect(badge.frame, frame)) badge.frame = frame;
    badge.alpha = anchor.alpha;
}
- (void)dealloc { [self.avatarTask cancel]; }
@end
