//
//  DKIconCropper.m
//

#import "DKIconCropper.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>

// 工作图的长边上限。归一到这个尺寸后「图像点 == 像素」，裁剪换算不必再乘 image.scale，
// 也顺带把 4000px 级照片的缩放手感压下来。
static const CGFloat kDKCropWorkingMaxSide = 2048.0;
// 输出边长：上限之内按裁剪区自身的像素数取，绝不放大——放大只增体积不增细节。
static const CGFloat kDKCropOutputMaxSide = 512.0;
static const CGFloat kDKCropOutputMinSide = 128.0;
// 圆窗四周留白与底部按钮条。
static const CGFloat kDKCropWindowMargin = 32.0;
static const CGFloat kDKCropBarHeight = 56.0;
static const CGFloat kDKCropButtonWidth = 96.0;
// 最大放大倍数，相对「铺满圆窗」的那一档。
static const CGFloat kDKCropMaxZoomFactor = 6.0;

#pragma mark - 入图归一

// 转正方向 + scale 归 1 + 长边压到上限。返回图的 size 即像素数。
static UIImage *DKCropNormalize(UIImage *image) {
    CGSize pixels = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    if (pixels.width < 1.0 || pixels.height < 1.0) return nil;

    CGFloat factor = MIN(1.0, kDKCropWorkingMaxSide / MAX(pixels.width, pixels.height));
    CGSize target = CGSizeMake(floor(pixels.width * factor), floor(pixels.height * factor));
    if (target.width < 1.0 || target.height < 1.0) return nil;

    UIGraphicsImageRendererFormat *format = UIGraphicsImageRendererFormat.preferredFormat;
    format.opaque = NO;
    format.scale = 1.0;
    // drawInRect: 自带方向校正，无需另算 imageOrientation 的变换矩阵。
    return [[[UIGraphicsImageRenderer alloc] initWithSize:target format:format]
        imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            [image drawInRect:CGRectMake(0.0, 0.0, target.width, target.height)];
        }];
}

#pragma mark -

@interface DKIconCropper () <UIScrollViewDelegate>

@property (nonatomic, strong) UIImage *working;
@property (nonatomic, copy) void (^completion)(UIImage *cropped);
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) CAShapeLayer *holeLayer;
@property (nonatomic, strong) CAShapeLayer *ringLayer;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *doneButton;
/// 圆窗，view 坐标系。裁剪与滚动内缩都以它为准。
@property (nonatomic, assign) CGRect cropWindow;

@end

@implementation DKIconCropper

- (instancetype)initWithImage:(UIImage *)image completion:(void (^)(UIImage *))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    // 校验必须排在 super init 之后：在那之前 return nil 会漏掉 +alloc 出来的那块内存。
    _working = image ? DKCropNormalize(image) : nil;
    if (!_working) return nil;

    _completion = [completion copy];
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - 视图

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    self.imageView = [[UIImageView alloc] initWithImage:self.working];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.delegate = self;
    // 系统会把安全区加进 contentInset，与我们自己算的圆窗内缩叠加，取景就永远对不准。
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.bouncesZoom = YES;
    [self.scrollView addSubview:self.imageView];
    [self.view addSubview:self.scrollView];

    // 挖孔遮罩：矩形叠圆形按 even-odd 填充，圆内即透出下方取景。
    self.holeLayer = [CAShapeLayer layer];
    self.holeLayer.fillRule = kCAFillRuleEvenOdd;
    self.dimView = [[UIView alloc] init];
    self.dimView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.62];
    self.dimView.userInteractionEnabled = NO;
    self.dimView.layer.mask = self.holeLayer;
    [self.view addSubview:self.dimView];

    // 描边不能挂在 dimView 上：它整层被遮罩裁掉，而描边正压在遮罩边界上。
    self.ringLayer = [CAShapeLayer layer];
    self.ringLayer.fillColor = UIColor.clearColor.CGColor;
    self.ringLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
    self.ringLayer.lineWidth = 1.0;
    [self.view.layer addSublayer:self.ringLayer];

    self.cancelButton = [self makeButtonWithTitle:@"取消" weight:UIFontWeightRegular
                                           action:@selector(cancelTapped)];
    self.doneButton = [self makeButtonWithTitle:@"完成" weight:UIFontWeightSemibold
                                         action:@selector(doneTapped)];
    [self.view addSubview:self.cancelButton];
    [self.view addSubview:self.doneButton];
}

- (UIButton *)makeButtonWithTitle:(NSString *)title weight:(UIFontWeight)weight action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:weight];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat barTop = CGRectGetMaxY(bounds) - safe.bottom - kDKCropBarHeight;

    self.cancelButton.frame = CGRectMake(kDKCropWindowMargin, barTop, kDKCropButtonWidth, kDKCropBarHeight);
    self.doneButton.frame = CGRectMake(CGRectGetMaxX(bounds) - kDKCropWindowMargin - kDKCropButtonWidth,
                                       barTop, kDKCropButtonWidth, kDKCropBarHeight);

    CGFloat available = barTop - safe.top;
    CGFloat diameter = MIN(CGRectGetWidth(bounds), available) - kDKCropWindowMargin * 2.0;
    if (diameter < 1.0) return;

    CGRect window = CGRectMake(floor((CGRectGetWidth(bounds) - diameter) / 2.0),
                               floor(safe.top + (available - diameter) / 2.0),
                               diameter, diameter);

    self.dimView.frame = bounds;
    self.holeLayer.frame = bounds;
    self.ringLayer.frame = bounds;
    UIBezierPath *hole = [UIBezierPath bezierPathWithRect:bounds];
    [hole appendPath:[UIBezierPath bezierPathWithOvalInRect:window]];
    self.holeLayer.path = hole.CGPath;
    self.ringLayer.path = [UIBezierPath bezierPathWithOvalInRect:window].CGPath;
    self.scrollView.frame = bounds;

    // 圆窗没变就不要重置取景，否则任何一次重新布局都会把用户拖好的位置打回原位。
    if (CGRectEqualToRect(window, self.cropWindow)) return;
    self.cropWindow = window;
    [self resetFraming];
}

// 圆窗四周的留白交给 contentInset：可滚动范围因此恰好等于「图始终盖满圆窗」的范围，
// 既不用自己夹 contentOffset，也不会出现内容比 bounds 小时被系统推到角落。
- (void)resetFraming {
    CGRect window = self.cropWindow;
    CGRect bounds = self.view.bounds;
    CGSize image = self.working.size;

    self.scrollView.contentInset = UIEdgeInsetsMake(CGRectGetMinY(window),
                                                    CGRectGetMinX(window),
                                                    CGRectGetHeight(bounds) - CGRectGetMaxY(window),
                                                    CGRectGetWidth(bounds) - CGRectGetMaxX(window));

    CGFloat minimum = MAX(CGRectGetWidth(window) / image.width,
                          CGRectGetHeight(window) / image.height);
    self.imageView.frame = CGRectMake(0.0, 0.0, image.width, image.height);
    self.scrollView.contentSize = image;
    self.scrollView.minimumZoomScale = minimum;
    self.scrollView.maximumZoomScale = minimum * kDKCropMaxZoomFactor;
    self.scrollView.zoomScale = minimum;
    self.scrollView.contentOffset = CGPointMake(image.width * minimum / 2.0 - CGRectGetMidX(window),
                                                image.height * minimum / 2.0 - CGRectGetMidY(window));
}

- (UIView *)viewForZoomingInScrollView:(__unused UIScrollView *)scrollView {
    return self.imageView;
}

#pragma mark - 裁剪

// 工作图已归一到 scale 1，故「内容坐标 ÷ 缩放」直接就是像素坐标。
// 边长与原点分别夹进图像范围：正方形先于位置保证，避免弹性回弹途中点完成裁出长方形。
- (UIImage *)croppedImage {
    CGImageRef source = self.working.CGImage;
    CGFloat zoom = self.scrollView.zoomScale;
    if (!source || zoom <= 0.0) return nil;

    CGFloat imageWidth = (CGFloat)CGImageGetWidth(source);
    CGFloat imageHeight = (CGFloat)CGImageGetHeight(source);
    CGPoint offset = self.scrollView.contentOffset;
    CGRect window = self.cropWindow;

    CGFloat side = floor(MIN(CGRectGetWidth(window) / zoom, MIN(imageWidth, imageHeight)));
    if (side < 1.0) return nil;
    CGFloat x = MIN(MAX(floor((offset.x + CGRectGetMinX(window)) / zoom), 0.0), imageWidth - side);
    CGFloat y = MIN(MAX(floor((offset.y + CGRectGetMinY(window)) / zoom), 0.0), imageHeight - side);

    CGImageRef cropped = CGImageCreateWithImageInRect(source, CGRectMake(x, y, side, side));
    if (!cropped) return nil;

    CGFloat output = MIN(kDKCropOutputMaxSide, MAX(kDKCropOutputMinSide, side));
    UIGraphicsImageRendererFormat *format = UIGraphicsImageRendererFormat.preferredFormat;
    format.opaque = NO;
    format.scale = 1.0;
    UIImage *result = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(output, output) format:format]
        imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            CGRect box = CGRectMake(0.0, 0.0, output, output);
            // 圆形 alpha 就此烘进图内，显示端不再需要任何 layer 遮罩。
            [[UIBezierPath bezierPathWithOvalInRect:box] addClip];
            [[UIImage imageWithCGImage:cropped] drawInRect:box];
        }];
    CGImageRelease(cropped);
    return result;
}

#pragma mark - 动作

- (void)cancelTapped {
    [self finishWithImage:nil];
}

- (void)doneTapped {
    [self finishWithImage:[self croppedImage]];
}

- (void)finishWithImage:(UIImage *)image {
    void (^completion)(UIImage *) = self.completion;
    self.completion = nil;                       // 回调只发一次
    [self dismissViewControllerAnimated:YES completion:^{
        if (completion) completion(image);
    }];
}

@end
