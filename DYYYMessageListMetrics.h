#import <Foundation/Foundation.h>
@interface DYYYMessageListMetrics : NSObject
+ (NSString *)kindForNotice:(BOOL)notice pinned:(BOOL)pinned;
+ (NSDictionary *)segmentForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next width:(double)width height:(double)height;
+ (NSDictionary *)contentPlacementForX:(double)x width:(double)width rowWidth:(double)rowWidth trailing:(BOOL)trailing;
@end
