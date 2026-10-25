#import <Foundation/Foundation.h>

@interface DYYYDetailCaptionMetrics : NSObject
+ (double)captionBottomForRowBottom:(double)rowBottom plainTextBottom:(double)textBottom;
+ (double)downwardShiftForCaptionBottom:(double)captionBottom inputTop:(double)inputTop
                       progressBottom:(double)progressBottom progressLimit:(double)progressLimit enabled:(BOOL)enabled;
@end
