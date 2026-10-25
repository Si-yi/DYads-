#import <Foundation/Foundation.h>

@interface DYYYCommentMenuMetrics : NSObject
+ (double)contentInsetForShellTop:(double)shellTop contentTop:(double)contentTop;
+ (double)contentHeightForActionBottom:(double)bottom safeAreaBottom:(double)safeArea rawContent:(double)raw;
+ (BOOL)needsUpdateForTarget:(double)target propertyHeight:(double)property renderedHeight:(double)rendered;
+ (double)composerHeightForBounds:(double)bounds contentBottom:(double)bottom safeAreaBottom:(double)safeArea active:(BOOL)active;
+ (double)heightLimitForOriginal:(double)original nativeMinimum:(double)minimum screenLimit:(double)screenLimit composerActive:(BOOL)active;
+ (double)compactHeightForContent:(double)content inset:(double)inset firstRowBottom:(double)rowBottom composerHeight:(double)composer maximum:(double)maximum;
+ (double)constrainedSheetHeight:(double)height target:(double)target composerActive:(BOOL)active;
+ (double)constrainedNativeHeight:(double)height target:(double)target managed:(BOOL)managed;
@end
