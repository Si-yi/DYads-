#import "DYYYRecallMarkerMetrics.h"
#include <math.h>

@implementation DYYYRecallMarkerMetrics
+ (BOOL)valid:(NSDictionary *)rect {
    if(![rect isKindOfClass:NSDictionary.class])return NO;
    for(NSString *key in @[@"x",@"y",@"width",@"height"])
        if(![rect[key] isKindOfClass:NSNumber.class] || !isfinite([rect[key] doubleValue]))return NO;
    return [rect[@"width"] doubleValue]>0 && [rect[@"height"] doubleValue]>0 &&
        isfinite([rect[@"x"] doubleValue]+[rect[@"width"] doubleValue]) && isfinite([rect[@"y"] doubleValue]+[rect[@"height"] doubleValue]);
}
+ (BOOL)rect:(NSDictionary *)a overlaps:(NSDictionary *)b {
    double left=MAX([a[@"x"] doubleValue],[b[@"x"] doubleValue]),top=MAX([a[@"y"] doubleValue],[b[@"y"] doubleValue]);
    double right=MIN([a[@"x"] doubleValue]+[a[@"width"] doubleValue],[b[@"x"] doubleValue]+[b[@"width"] doubleValue]);
    double bottom=MIN([a[@"y"] doubleValue]+[a[@"height"] doubleValue],[b[@"y"] doubleValue]+[b[@"height"] doubleValue]);
    return right>left && bottom>top;
}
+ (NSDictionary *)layoutForWidth:(double)width height:(double)height bubble:(NSDictionary *)bubble occupied:(NSArray<NSDictionary *> *)occupied idealWidth:(double)idealWidth {
    if(!isfinite(width)||!isfinite(height)||!isfinite(idealWidth)||width<=0||height<=0||idealWidth<=0||![self valid:bubble])return @{@"style":@"hidden",@"reason":@"invalid_geometry"};
    double x=[bubble[@"x"] doubleValue],y=[bubble[@"y"] doubleValue],w=[bubble[@"width"] doubleValue],h=[bubble[@"height"] doubleValue];
    if(x<0||y<0||x+w>width+0.5||y+h>height+0.5)return @{@"style":@"hidden",@"reason":@"bubble_outside_cell"};
    double labelWidth=MIN(idealWidth,width-24),firstTop=y;
    for(NSDictionary *obstacle in occupied)if([self valid:obstacle])firstTop=MIN(firstTop,[obstacle[@"y"] doubleValue]);
    NSArray *candidates=@[
        @{@"x":@(x),@"y":@(y+h+2),@"width":@(labelWidth),@"height":@12,@"style":@"below"},
        @{@"x":@(x+w+6),@"y":@(y+h-12),@"width":@(labelWidth),@"height":@12,@"style":@"beside"},
        @{@"x":@(x),@"y":@(firstTop-14),@"width":@(labelWidth),@"height":@12,@"style":@"above"},
        @{@"x":@(x+w+6),@"y":@(MAX(y,y+h-24)),@"width":@(MIN(38,width-x-w-18)),@"height":@24,@"style":@"compact"}
    ];
    for(NSDictionary *candidate in candidates){
        double cx=[candidate[@"x"] doubleValue],cy=[candidate[@"y"] doubleValue],cw=[candidate[@"width"] doubleValue],ch=[candidate[@"height"] doubleValue];
        if(![self valid:candidate]||cx<12||cy<0||cx+cw>width-12||cy+ch>height||([candidate[@"style"] isEqual:@"compact"]&&cw<30))continue;
        BOOL clear=![self rect:candidate overlaps:bubble];
        for(NSDictionary *obstacle in occupied)if(clear&&[self valid:obstacle]&&[self rect:candidate overlaps:obstacle])clear=NO;
        if(clear)return candidate;
    }
    return @{@"style":@"hidden",@"reason":@"no_free_space"};
}
@end
