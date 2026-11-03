#import <Foundation/Foundation.h>

@interface DYYYTabBarMetrics : NSObject
// 按自然尺寸与窗口可用宽度计算，绝不使用已压缩按钮的测量值。
+ (double)capsuleWidthForCount:(NSUInteger)count reference:(NSUInteger)reference barWidth:(double)barWidth buttonWidth:(double)buttonWidth padding:(double)padding accessory:(double)accessory inset:(double)inset;
@end
