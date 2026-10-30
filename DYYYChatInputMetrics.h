#import <Foundation/Foundation.h>

@interface DYYYChatInputMetrics : NSObject
+ (double)bottomExtensionForHostBottom:(double)hostBottom listTop:(double)listTop listBottom:(double)listBottom
                             inputTop:(double)inputTop inputBottom:(double)inputBottom folded:(BOOL)folded;
+ (BOOL)canReuseTopExtension:(double)top bottomExtension:(double)bottom topWanted:(BOOL)topWanted
               bottomWanted:(BOOL)bottomWanted previousTopWanted:(BOOL)oldTop previousBottomWanted:(BOOL)oldBottom;
@end
