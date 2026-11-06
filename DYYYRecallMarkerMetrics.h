#import <Foundation/Foundation.h>

@interface DYYYRecallMarkerMetrics : NSObject
/// 输入均为Cell.contentView内实际可见矩形；不改变原生行高，找不到空位时隐藏提示。
+ (NSDictionary *)layoutForWidth:(double)width height:(double)height bubble:(NSDictionary *)bubble
                      occupied:(NSArray<NSDictionary *> *)occupied idealWidth:(double)idealWidth;
@end
