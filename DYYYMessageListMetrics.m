#import "DYYYMessageListMetrics.h"
#include <math.h>
@implementation DYYYMessageListMetrics
+ (NSString *)kindForNotice:(BOOL)notice pinned:(BOOL)pinned { return notice ? @"notice" : pinned ? @"pinned" : @"regular"; }
+ (NSDictionary *)paddingForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next nativeHeight:(double)height {
    if(![@[@"notice",@"pinned",@"regular"] containsObject:kind?:@""] || !isfinite(height) || height<40 || height>200)return @{};
    BOOL first=[kind isEqual:@"notice"] || ![kind isEqual:previous];
    BOOL last=[kind isEqual:@"notice"] || ![kind isEqual:next];
    double top=first?12:0,bottom=last?12:0;
    return @{@"top":@(top),@"bottom":@(bottom),@"nativeHeight":@(height),@"height":@(height+top+bottom)};
}
+ (NSDictionary *)segmentForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next width:(double)width height:(double)height {
    if (![@[@"notice",@"pinned",@"regular"] containsObject:kind ?: @""] || !isfinite(width) || !isfinite(height) || width < 160 || height < 40) return @{};
    BOOL first = [kind isEqual:@"notice"] || ![kind isEqual:previous];
    BOOL last = [kind isEqual:@"notice"] || ![kind isEqual:next];
    double top = first ? 6 : 0, bottom = last ? 6 : 0;
    return @{@"x":@16,@"y":@(top),@"width":@(width-32),@"height":@(height-top-bottom),@"first":@(first),@"last":@(last),@"radius":@18};
}
+ (NSDictionary *)contentTransformForX:(double)x y:(double)y width:(double)width height:(double)height rowWidth:(double)rowWidth rowHeight:(double)rowHeight {
    if (!isfinite(x) || !isfinite(y) || !isfinite(width) || !isfinite(height) || !isfinite(rowWidth) || !isfinite(rowHeight) ||
        rowWidth<160 || rowHeight<40 || x<0 || y<0 || width<=0 || height<=0 || x+width>rowWidth+0.5 || y+height>rowHeight+0.5) return @{};
    // 全行内容使用同一个坐标映射，保持原生文案、火花、摘要和尾部角标的相对距离。
    double scale=0.92;
    double tx=(scale-1)*(x+width/2-rowWidth/2),ty=(scale-1)*(y+height/2-rowHeight/2);
    return @{@"scale":@(scale),@"translationX":@(tx),@"translationY":@(ty),
        @"x":@(rowWidth/2+(x-rowWidth/2)*scale),@"y":@(rowHeight/2+(y-rowHeight/2)*scale),@"width":@(width*scale),@"height":@(height*scale)};
}
+ (NSDictionary *)nativeFrameForRequest:(NSDictionary *)request previousNative:(NSDictionary *)native previousDisplayed:(NSDictionary *)displayed {
    for(NSDictionary *frame in @[request?:@{},native?:@{},displayed?:@{}]){
        for(NSString *key in @[@"x",@"y",@"width",@"height"])
            if(![frame[key] isKindOfClass:NSNumber.class] || !isfinite([frame[key] doubleValue]))return request;
        if([frame[@"width"] doubleValue]<=0 || [frame[@"height"] doubleValue]<=0)return request;
    }
    NSMutableDictionary *result=[request mutableCopy];
    NSArray *sizes=@[@"width",@"height"],*origins=@[@"x",@"y"];
    for(NSUInteger axis=0;axis<2;axis++){
        NSString *size=sizes[axis],*origin=origins[axis];
        if(fabs([request[size] doubleValue]-[displayed[size] doubleValue])<=0.5 && fabs([native[size] doubleValue]-[displayed[size] doubleValue])>0.5){
            result[size]=native[size];
            result[origin]=@([request[origin] doubleValue]-([displayed[origin] doubleValue]-[native[origin] doubleValue]));
        }
    }
    return result;
}
@end
