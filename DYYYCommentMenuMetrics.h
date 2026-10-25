#import <Foundation/Foundation.h>

@interface DYYYCommentMenuMetrics : NSObject
+ (double)contentHeightForActionBottom:(double)bottom safeAreaBottom:(double)safeArea rawContent:(double)raw;
+ (BOOL)needsUpdateForTarget:(double)target propertyHeight:(double)property renderedHeight:(double)rendered;
+ (double)compactHeightForContent:(double)content inset:(double)inset firstRowBottom:(double)rowBottom composerHeight:(double)composer maximum:(double)maximum;
@end
