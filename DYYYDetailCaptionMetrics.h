#import <Foundation/Foundation.h>

@interface DYYYDetailCaptionMetrics : NSObject
+ (double)pageInputTopForViewportInputTop:(double)inputTop viewportMinY:(double)viewportMinY
                         viewportHeight:(double)viewportHeight pageMinY:(double)pageMinY pageHeight:(double)pageHeight;
+ (double)captionBottomForRowBottom:(double)rowBottom plainTextBottom:(double)textBottom;
+ (double)downwardShiftForCaptionBottom:(double)captionBottom inputTop:(double)inputTop
                       progressBottom:(double)progressBottom progressLimit:(double)progressLimit enabled:(BOOL)enabled;
@end
