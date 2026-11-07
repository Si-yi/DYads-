#import <Foundation/Foundation.h>
@interface DYYYMessageListMetrics : NSObject
+ (NSString *)kindForNotice:(BOOL)notice pinned:(BOOL)pinned;
+ (NSDictionary *)segmentForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next width:(double)width height:(double)height;
+ (NSDictionary *)contentTransformForX:(double)x y:(double)y width:(double)width height:(double)height rowWidth:(double)rowWidth rowHeight:(double)rowHeight;
+ (NSDictionary *)nativeFrameForRequest:(NSDictionary *)request previousNative:(NSDictionary *)native previousDisplayed:(NSDictionary *)displayed;
+ (NSDictionary *)paddingForKind:(NSString *)kind previous:(NSString *)previous next:(NSString *)next nativeHeight:(double)height;
@end
