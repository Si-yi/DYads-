#import <Foundation/Foundation.h>
#import "DYYYRecallMarkerMetrics.h"
#include <math.h>

@interface DYYYRecallMarkerMetricsTests : NSObject @end
@implementation DYYYRecallMarkerMetricsTests
+ (void)check:(BOOL)value reason:(NSString *)reason {if(!value)[NSException raise:@"RegressionFailure" format:@"%@",reason];}
+ (NSDictionary *)rectX:(double)x y:(double)y width:(double)w height:(double)h {return @{@"x":@(x),@"y":@(y),@"width":@(w),@"height":@(h)};}
+ (BOOL)overlap:(NSDictionary *)a other:(NSDictionary *)b {
    return MAX([a[@"x"] doubleValue],[b[@"x"] doubleValue])<MIN([a[@"x"] doubleValue]+[a[@"width"] doubleValue],[b[@"x"] doubleValue]+[b[@"width"] doubleValue]) &&
        MAX([a[@"y"] doubleValue],[b[@"y"] doubleValue])<MIN([a[@"y"] doubleValue]+[a[@"height"] doubleValue],[b[@"y"] doubleValue]+[b[@"height"] doubleValue]);
}
+ (void)run {
    NSDictionary *bubble=[self rectX:56 y:14 width:83 height:38],*avatar=[self rectX:12 y:14 width:36 height:36];
    NSDictionary *layout=[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:bubble occupied:@[bubble,avatar] idealWidth:100];
    [self check:[layout[@"style"] isEqual:@"beside"] && [layout[@"x"] doubleValue]==145 reason:@"BC0DA5B0：底部只有2pt时，移到真实气泡右侧，不用整行x0当气泡"];
    [self check:![self overlap:layout other:avatar] && ![self overlap:layout other:bubble] reason:@"提示不压头像和原消息"];
    [self check:[layout[@"y"] doubleValue]+[layout[@"height"] doubleValue]<=54 reason:@"不超出原生行高、不撑表格"];
    NSDictionary *photo=[self rectX:56 y:38 width:210 height:250];
    layout=[DYYYRecallMarkerMetrics layoutForWidth:440 height:304 bubble:photo occupied:@[photo,avatar] idealWidth:100];
    [self check:[layout[@"style"] isEqual:@"below"] && [layout[@"y"] doubleValue]==290 reason:@"原生底部空间足够时置于图片下方"];
    NSDictionary *longText=[self rectX:56 y:14 width:330 height:38];
    layout=[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:longText occupied:@[longText,avatar] idealWidth:100];
    [self check:[layout[@"style"] isEqual:@"above"] && [layout[@"y"] doubleValue]==0 reason:@"长消息右侧不足时使用上方空白，仍不覆盖正文"];
    NSDictionary *header=[self rectX:56 y:0 width:150 height:14];
    layout=[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:longText occupied:@[longText,avatar,header] idealWidth:100];
    [self check:[layout[@"style"] isEqual:@"compact"] && ![self overlap:layout other:header] reason:@"上方有昵称时使用右侧双行短提示"];
    NSDictionary *button=[self rectX:145 y:40 width:28 height:14];
    layout=[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:bubble occupied:@[bubble,avatar,button] idealWidth:100];
    [self check:[layout[@"style"] isEqual:@"above"] reason:@"避开右侧原生操作按钮"];
    NSDictionary *blocked=[self rectX:0 y:0 width:440 height:54];
    layout=[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:bubble occupied:@[blocked] idealWidth:100];
    [self check:[layout[@"style"] isEqual:@"hidden"] reason:@"没有安全空位时不把提示压在原生内容上"];
    [self check:[[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:nil occupied:@[] idealWidth:100][@"style"] isEqual:@"hidden"] reason:@"未知气泡结构不退回头像区"];
    NSDictionary *stable=[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:bubble occupied:@[bubble,avatar] idealWidth:100];
    for(NSUInteger i=0;i<100;i++)[self check:[stable isEqual:[DYYYRecallMarkerMetrics layoutForWidth:440 height:54 bubble:bubble occupied:@[bubble,avatar] idealWidth:100]] reason:@"重复布局不累加位移"];
    NSLog(@"DYYYRecallMarkerMetrics regression tests passed");
}
@end
int main(void){@autoreleasepool{[DYYYRecallMarkerMetricsTests run];}return 0;}
