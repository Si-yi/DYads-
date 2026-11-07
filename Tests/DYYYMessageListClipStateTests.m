#import <Foundation/Foundation.h>
#import "DYYYMessageListClipState.h"
@interface DYYYObservedMaskLayer : CALayer
@property (nonatomic) BOOL sawEmptyMask;
@property (nonatomic) BOOL failUnclip;
- (BOOL)hasVisibleCenter;
@end
@implementation DYYYObservedMaskLayer
- (void)setMask:(CALayer *)mask {
    if(mask && (CGRectIsEmpty(mask.bounds) || ![mask isKindOfClass:CAShapeLayer.class] || !((CAShapeLayer *)mask).path))self.sawEmptyMask=YES;
    [super setMask:mask];
}
- (void)setMasksToBounds:(BOOL)value {
    if(!value && self.failUnclip)[NSException raise:@"DYYYTestClipFailure" format:@"模拟挂载遮罩后的原生布局失败"];
    [super setMasksToBounds:value];
}
- (BOOL)hasVisibleCenter {
    size_t width=440,height=850;void *bytes=calloc(width*height,4);CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(bytes,width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    [self renderInContext:context];unsigned char *pixel=(unsigned char *)bytes+((height/2)*width+width/2)*4;BOOL visible=pixel[3]>240;
    CGContextRelease(context);CGColorSpaceRelease(space);free(bytes);return visible;
}
@end
int main(void) {
    @autoreleasepool {
        DYYYObservedMaskLayer *layer=[DYYYObservedMaskLayer layer];layer.bounds=CGRectMake(0,0,440,850);layer.masksToBounds=YES;
        CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGFloat rgba[]={0.2,0.4,0.8,1};CGColorRef color=CGColorCreate(space,rgba);layer.backgroundColor=color;CGColorRelease(color);CGColorSpaceRelease(space);
        DYYYMessageListClipState *clip=[[DYYYMessageListClipState alloc] initWithLayer:layer];
        NSCAssert([clip applyExtension:106] && clip.active,@"真实440x850图层必须得到完整非空遮罩");
        NSCAssert(!layer.sawEmptyMask,@"任何时刻都不能把未初始化遮罩挂到消息容器");
        NSCAssert(layer.mask.bounds.size.height==956,@"遮罩自身包含整个扩展区域");
        NSCAssert([layer hasVisibleCenter],@"实际栅格化后消息区域仍可见，不能出现空白页");
        CALayer *mask=layer.mask;
        for(NSUInteger i=0;i<1000;i++)NSCAssert([clip applyExtension:106] && layer.mask==mask && layer.mask.bounds.size.height==956,@"重复布局不替换遮罩、不叠加高度");
        [clip restore];NSCAssert(!layer.mask && layer.masksToBounds && [layer hasVisibleCenter],@"关闭后原生绘制与裁切恢复");
        [clip applyExtension:106];layer.bounds=CGRectZero;
        NSCAssert(![clip applyExtension:106] && !layer.mask && layer.masksToBounds,@"空几何必须撤销遮罩而不是遮掉整页");
        layer.bounds=CGRectMake(0,0,440,850);layer.failUnclip=YES;
        NSCAssert(![clip applyExtension:106] && !layer.mask && layer.masksToBounds,@"部分挂载失败必须立即恢复");layer.failUnclip=NO;
        CAShapeLayer *native=[CAShapeLayer layer];layer.mask=native;
        NSCAssert(![[DYYYMessageListClipState alloc] initWithLayer:layer],@"已有原生遮罩时不接管");layer.mask=nil;
        NSLog(@"DYYYMessageListClipState regression tests passed");
    }return 0;
}
