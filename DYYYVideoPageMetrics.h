#import <Foundation/Foundation.h>

@interface DYYYVideoPageMetrics : NSObject
+ (double)tableHeight:(double)native target:(double)target enabled:(BOOL)enabled nativePaging:(BOOL)nativePaging;
+ (double)rowHeight:(double)native original:(double)original viewport:(double)viewport enabled:(BOOL)enabled nativePaging:(BOOL)nativePaging;
+ (NSDictionary *)paintExtensionForWidth:(double)width height:(double)height pageWidth:(double)pageWidth pageHeight:(double)pageHeight replyTop:(double)replyTop replyHeight:(double)replyHeight enabled:(BOOL)enabled;
@end
