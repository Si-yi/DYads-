#import "DYYYDebugMenuView.h"
#import "DYYYDebugAppearance.h"
#import "DYYYUtils.h"
#import <math.h>

@implementation DYYYDebugMenuItem
+ (instancetype)itemWithTitle:(NSString *)title handler:(void (^)(void))handler {
    DYYYDebugMenuItem *item = [self new];
    item.title = title;
    item.handler = handler;
    return item;
}
@end

@interface DYYYDebugMenuView ()
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, strong) UIControl *backdrop;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, copy) NSArray<DYYYDebugMenuItem *> *items;
@property (nonatomic, strong) NSMutableArray<UIButton *> *buttons;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, assign) UIUserInterfaceStyle appliedStyle;
@property (nonatomic, assign) BOOL closing;
@end

@implementation DYYYDebugMenuView

+ (void)presentFromController:(UIViewController *)presenter window:(UIWindow *)window title:(NSString *)title message:(NSString *)message items:(NSArray<DYYYDebugMenuItem *> *)items {
    if (!NSThread.isMainThread || !presenter) return;
    UIViewController *controller = [UIViewController new];
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    DYYYDebugMenuView *view = [[self alloc] initWithFrame:window.bounds];
    view.controller = controller;
    view.items = items;
    view.titleLabel.text = title;
    view.messageLabel.text = message;
    for (NSUInteger index = 0; index < items.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.layer.cornerRadius = 14;
        button.tag = index;
        [button setTitle:items[index].title forState:UIControlStateNormal];
        [button addTarget:view action:@selector(selectItem:) forControlEvents:UIControlEventTouchUpInside];
        [view.scroll addSubview:button];
        [view.buttons addObject:button];
    }
    controller.view = view;
    [DYYYDebugAppearance prepareController:controller sourceWindow:window];
    [view applyStyle];
    [presenter presentViewController:controller animated:YES completion:nil];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.buttons = [NSMutableArray array];
        self.backdrop = [UIControl new];
        self.backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.30];
        [self.backdrop addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.backdrop];
        self.panel = [UIView new];
        self.panel.backgroundColor = UIColor.clearColor;
        self.panel.layer.cornerRadius = 24;
        self.panel.layer.cornerCurve = kCACornerCurveContinuous;
        self.panel.clipsToBounds = YES;
        [self addSubview:self.panel];
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
        self.blurView.userInteractionEnabled = NO;
        self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.panel addSubview:self.blurView];
        self.scroll = [UIScrollView new];
        [self.panel addSubview:self.scroll];
        self.titleLabel = [UILabel new];
        self.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
        self.titleLabel.numberOfLines = 0;
        [self.scroll addSubview:self.titleLabel];
        self.messageLabel = [UILabel new];
        self.messageLabel.font = [UIFont systemFontOfSize:14];
        self.messageLabel.numberOfLines = 0;
        [self.scroll addSubview:self.messageLabel];
        self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:16];
        [self.cancelButton setTitle:@"关闭" forState:UIControlStateNormal];
        [self.cancelButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [self.scroll addSubview:self.cancelButton];
    }
    return self;
}

- (void)applyStyle {
    UIUserInterfaceStyle style = self.controller.overrideUserInterfaceStyle;
    if (style == UIUserInterfaceStyleUnspecified) style = self.traitCollection.userInterfaceStyle;
    // 默认一直有毛玻璃；透明度只作用于背景，按钮和文字不随之变淡。
    self.blurView.alpha = [DYYYUtils sharedBlurTransparency];
    if (self.appliedStyle == style && self.blurView.effect) return;
    BOOL dark = style == UIUserInterfaceStyleDark;
    // 等材质视图有实际尺寸后再建立效果，避免先在零尺寸视图上初始化。
    if (!CGRectIsEmpty(self.blurView.bounds)) {
        self.blurView.effect = [UIBlurEffect effectWithStyle:dark ? UIBlurEffectStyleDark : UIBlurEffectStyleLight];
        self.appliedStyle = style;
    }
    self.blurView.contentView.backgroundColor = [UIColor colorWithWhite:dark ? 0 : 1 alpha:dark ? 0.12 : 0.08];
    UIColor *text = dark ? UIColor.whiteColor : UIColor.blackColor;
    self.titleLabel.textColor = text;
    self.messageLabel.textColor = dark ? [UIColor colorWithWhite:0.82 alpha:1] : [UIColor colorWithWhite:0.25 alpha:1];
    for (UIButton *button in self.buttons) {
        button.backgroundColor = [UIColor colorWithWhite:dark ? 1 : 0 alpha:dark ? 0.10 : 0.05];
        [button setTitleColor:text forState:UIControlStateNormal];
    }
    [self.cancelButton setTitleColor:text forState:UIControlStateNormal];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self applyStyle];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.backdrop.frame = self.bounds;
    CGFloat width = MIN(380, MAX(0, self.bounds.size.width - 32));
    CGFloat inner = MAX(0, width - 40);
    CGFloat titleHeight = ceil([self.titleLabel sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
    CGFloat messageHeight = ceil([self.messageLabel sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
    CGFloat y = 22;
    self.titleLabel.frame = CGRectMake(20, y, inner, titleHeight); y += titleHeight + 10;
    self.messageLabel.frame = CGRectMake(20, y, inner, messageHeight); y += messageHeight + 18;
    for (UIButton *button in self.buttons) { button.frame = CGRectMake(16, y, width - 32, 50); y += 58; }
    self.cancelButton.frame = CGRectMake(16, y, width - 32, 42); y += 52;
    CGFloat available = MAX(0, self.bounds.size.height - self.safeAreaInsets.top - self.safeAreaInsets.bottom - 32);
    CGFloat height = MIN(y, available);
    CGFloat top = self.safeAreaInsets.top + 16 + (available - height) / 2;
    self.panel.frame = CGRectMake((self.bounds.size.width - width) / 2, top, width, height);
    self.blurView.frame = self.panel.bounds;
    self.scroll.frame = self.panel.bounds;
    self.scroll.contentSize = CGSizeMake(width, y);
    [self applyStyle];
}

- (void)selectItem:(UIButton *)button {
    if (self.closing || button.tag < 0 || (NSUInteger)button.tag >= self.items.count) return;
    self.closing = YES;
    void (^handler)(void) = self.items[button.tag].handler;
    [self.controller dismissViewControllerAnimated:YES completion:^{ if (handler) handler(); }];
}
- (void)cancel {
    if (self.closing) return;
    self.closing = YES;
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}
@end
