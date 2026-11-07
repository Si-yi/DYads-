#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
// 遮罩先生成完整尺寸与路径，再挂载；拒绝空几何，失败时恢复原生裁切。
@interface DYYYMessageListClipState : NSObject
- (instancetype)initWithLayer:(CALayer *)layer;
- (BOOL)applyExtension:(CGFloat)extension;
- (void)restore;
@property (nonatomic, readonly) BOOL active;
@end
