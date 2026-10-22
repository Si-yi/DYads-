//
//  DYYYPlusIcon.m
//  移植自 DYKiller 的 DKPlusIcon.xm。
//
//  图片存在 Documents/DYYY/tab_plus.png——与 DYYY 原来的「拍摄的图标」同一个文件，
//  备份导出与恢复沿用原有逻辑，老用户以前设的图标继续有效。
//

#import "DYYYPlusIcon.h"
#import "DKIconCropper.h"

#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>

static NSString *const kDYYYPlusStyleKey = @"DYYYPlusStyle";
static char kDKPickerRelayKey;

static const CGFloat kDKPreviewSide = 88.0;
static const CGFloat kDKPreviewPadding = 8.0;
static const CGFloat kDKPreviewWidth = 250.0;

NSArray<NSString *> *DYYYPlusStyleTitles(void) {
    return @[ @"默认", @"新图标", @"新双色图标", @"自定义图片" ];
}

#pragma mark - 存储

static NSString *DYYYPlusIconPath(void) {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *directory = [documents stringByAppendingPathComponent:@"DYYY"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return [directory stringByAppendingPathComponent:@"tab_plus.png"];
}

static UIImage *gCustomIcon = nil;
static BOOL gCustomIconLoaded = NO;

UIImage *DKPlusIconCustom(void) {
    if (!gCustomIconLoaded) {
        gCustomIconLoaded = YES;
        gCustomIcon = [UIImage imageWithContentsOfFile:DYYYPlusIconPath()];
    }
    return gCustomIcon;
}

// 写盘失败时内存也不改：界面显示的与磁盘上的必须是同一件事。
static void DYYYPlusIconStore(UIImage *icon) {
    NSString *path = DYYYPlusIconPath();
    if (!icon) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        gCustomIconLoaded = YES;
        gCustomIcon = nil;
        return;
    }
    NSData *data = UIImagePNGRepresentation(icon);
    if (!data || ![data writeToFile:path atomically:YES]) return;
    gCustomIconLoaded = YES;
    gCustomIcon = icon;
}

#pragma mark - 样式

static DKPlusStyle DYYYPlusStoredStyle(BOOL *explicit) {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:kDYYYPlusStyleKey];
    NSUInteger index = saved.length ? [DYYYPlusStyleTitles() indexOfObject:saved] : NSNotFound;
    if (explicit) *explicit = index != NSNotFound;
    if (index == NSNotFound) return DKPlusStyleDefault;
    return (DKPlusStyle)index;
}

DKPlusStyle DKPlusCurrentStyle(void) {
    BOOL explicit = NO;
    DKPlusStyle style = DYYYPlusStoredStyle(&explicit);
    if (!explicit) return DKPlusIconCustom() ? DKPlusStyleCustom : DKPlusStyleDefault;
    if (style == DKPlusStyleCustom && !DKPlusIconCustom()) return DKPlusStyleDefault;
    return style;
}

UIImage *DYYYPlusNativeImage(void) {
    return DKPlusCurrentStyle() == DKPlusStyleCustom ? DKPlusIconCustom() : nil;
}

NSString *DYYYPlusIconDetail(void) {
    return DKPlusIconCustom() ? @"已设置" : @"默认";
}

NSString *DYYYPlusStyleDetail(void) {
    return DYYYPlusStyleTitles()[DKPlusCurrentStyle()];
}

void DYYYPlusRefresh(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        DKGlassTabBarRefresh();
    });
}

static void DYYYPlusSetStyle(DKPlusStyle style) {
    [[NSUserDefaults standardUserDefaults] setObject:DYYYPlusStyleTitles()[style] forKey:kDYYYPlusStyleKey];
}

#pragma mark - 裁剪

// completion 只在写盘成功后以 YES 调用；取消裁剪、写盘失败都以 NO 调用。
static void DYYYPlusPresentCropper(UIViewController *presenter, UIImage *image, void (^completion)(BOOL picked)) {
    if (!presenter || !image) {
        if (completion) completion(NO);
        return;
    }
    DKIconCropper *cropper = [[DKIconCropper alloc] initWithImage:image completion:^(UIImage *cropped) {
        BOOL stored = NO;
        if (cropped) {
            DYYYPlusIconStore(cropped);
            stored = DKPlusIconCustom() == cropped;
        }
        if (completion) completion(stored);
    }];
    if (cropper) [presenter presentViewController:cropper animated:YES completion:nil];
    else if (completion) completion(NO);
}

#pragma mark - 相册

@interface DYYYPlusPickerRelay : NSObject <PHPickerViewControllerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) void (^completion)(BOOL picked);
@end

@implementation DYYYPlusPickerRelay

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    NSItemProvider *provider = results.firstObject.itemProvider;
    // 只捕获目标对象，不捕获 self：relay 挂在 picker 上，picker 一消失它就走了，而取图是异步的。
    __weak UIViewController *presenter = self.presenter;
    void (^completion)(BOOL) = self.completion;

    // 裁剪页要等相册收完再开：present 不能压在别人的 dismiss 动画上。
    [picker dismissViewControllerAnimated:YES completion:^{
        if (![provider canLoadObjectOfClass:UIImage.class]) {
            if (completion) completion(NO);
            return;
        }
        [provider loadObjectOfClass:UIImage.class
                  completionHandler:^(UIImage *image, __unused NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![image isKindOfClass:UIImage.class]) {
                    if (completion) completion(NO);
                    return;
                }
                DYYYPlusPresentCropper(presenter, image, completion);
            });
        }];
    }];
}

@end

// 走进程外选取：不申请相册权限，也就不弹权限请求。
static void DYYYPlusPick(UIViewController *presenter, void (^completion)(BOOL picked)) {
    if (!presenter) {
        if (completion) completion(NO);
        return;
    }

    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.filter = PHPickerFilter.imagesFilter;
    configuration.selectionLimit = 1;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    DYYYPlusPickerRelay *relay = [[DYYYPlusPickerRelay alloc] init];
    relay.presenter = presenter;
    relay.completion = completion;
    picker.delegate = relay;
    // delegate 是弱引用，relay 得跟着 picker 一起活着。
    objc_setAssociatedObject(picker, &kDKPickerRelayKey, relay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter presentViewController:picker animated:YES completion:nil];
}

#pragma mark - 弹窗

// 居中必须用约束，不能用 frame + autoresizing：box.view 建出来时是整屏宽，之后被 alert 压到自己的内容宽度。
static UIViewController *DYYYPlusPreviewBox(UIImage *icon) {
    UIViewController *box = [[UIViewController alloc] init];
    box.preferredContentSize = CGSizeMake(kDKPreviewWidth, kDKPreviewSide + kDKPreviewPadding * 2.0);

    UIView *content = nil;
    if (icon) {
        UIImageView *thumbnail = [[UIImageView alloc] initWithImage:icon];
        thumbnail.contentMode = UIViewContentModeScaleAspectFit;
        content = thumbnail;
    } else {
        UILabel *label = [[UILabel alloc] init];
        label.text = @"选择图标";
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:15.0];
        label.textColor = UIColor.secondaryLabelColor;
        content = label;
    }

    content.translatesAutoresizingMaskIntoConstraints = NO;
    [box.view addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:box.view.centerXAnchor],
        [content.topAnchor constraintEqualToAnchor:box.view.topAnchor constant:kDKPreviewPadding],
        [content.widthAnchor constraintEqualToConstant:kDKPreviewSide],
        [content.heightAnchor constraintEqualToConstant:kDKPreviewSide]
    ]];
    return box;
}

void DYYYPlusShowIconDialog(UIViewController *presenter, void (^changed)(void)) {
    if (!presenter) return;
    UIImage *icon = DKPlusIconCustom();
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"拍摄的图标"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert setValue:DYYYPlusPreviewBox(icon) forKey:@"contentViewController"];

    __weak UIViewController *weakPresenter = presenter;

    UIAlertAction *clear = [UIAlertAction actionWithTitle:@"清除"
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(__unused UIAlertAction *action) {
        DYYYPlusIconStore(nil);
        // 清掉图片时若样式正选着「自定义图片」，一并改回默认。
        BOOL explicit = NO;
        if (DYYYPlusStoredStyle(&explicit) == DKPlusStyleCustom) DYYYPlusSetStyle(DKPlusStyleDefault);
        DYYYPlusRefresh();
        if (changed) changed();
    }];
    clear.enabled = icon != nil;
    [alert addAction:clear];

    [alert addAction:[UIAlertAction actionWithTitle:@"选择"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        // 退一拍再开相册：直接 present 会压在 alert 自己的消失动画上。
        dispatch_async(dispatch_get_main_queue(), ^{
            DYYYPlusPick(weakPresenter, ^(BOOL picked) {
                if (!picked) return;
                DYYYPlusRefresh();
                if (changed) changed();
            });
        });
    }]];

    // Alert 点外部不消失，没有这一项就没有退出路径。
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 样式选择

void DYYYPlusShowStyleChooser(UIViewController *presenter, void (^changed)(void)) {
    if (!presenter) return;
    NSArray<NSString *> *titles = DYYYPlusStyleTitles();
    DKPlusStyle current = DKPlusCurrentStyle();

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"拍摄的按钮"
                                                                   message:@"新图标与新双色图标只在悬浮底栏生效；自定义图片两种底栏都生效。"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak UIViewController *weakPresenter = presenter;
    for (NSUInteger i = 0; i < titles.count; i++) {
        NSString *label = (NSInteger)i == current ? [titles[i] stringByAppendingString:@"  ✓"] : titles[i];
        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            DKPlusStyle chosen = (DKPlusStyle)i;
            void (^commit)(void) = ^{
                DYYYPlusSetStyle(chosen);
                DYYYPlusRefresh();
                if (changed) changed();
            };
            // 还没有自定义图片时先选图，写盘成功才切过去；取消则保持原样式。
            if (chosen != DKPlusStyleCustom || DKPlusIconCustom()) {
                commit();
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                DYYYPlusPick(weakPresenter, ^(BOOL picked) {
                    if (picked) commit();
                });
            });
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    // iPad 上 action sheet 必须有锚点。
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                                                CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}
