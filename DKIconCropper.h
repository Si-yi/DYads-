//
//  DKIconCropper.h
//  DYKiller
//
//  圆形图标裁剪页：拖动/缩放取景，产出一枚圆形 alpha 已烘进图内的方形 PNG 源图。
//  纯 UIKit，不依赖抖音任何类。
//

#ifndef DKIconCropper_h
#define DKIconCropper_h

#import <UIKit/UIKit.h>

@interface DKIconCropper : UIViewController

/// completion 在主线程回调；cropped 为 nil 表示用户取消。
/// 输出是正方形图，圆外全透明，可直接当图标显示，无需再加 layer 遮罩。
- (instancetype)initWithImage:(UIImage *)image completion:(void (^)(UIImage *cropped))completion;

@end

#endif /* DKIconCropper_h */
