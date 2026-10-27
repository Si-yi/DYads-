#import <Foundation/Foundation.h>

@interface DYYYChatInputMetrics : NSObject
+ (double)bottomExtensionForHostBottom:(double)hostBottom listTop:(double)listTop listBottom:(double)listBottom
                             inputTop:(double)inputTop inputBottom:(double)inputBottom folded:(BOOL)folded;
@end
