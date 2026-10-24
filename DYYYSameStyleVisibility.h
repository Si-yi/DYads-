#import <UIKit/UIKit.h>

@interface DYYYSameStyleVisibility : NSObject
+ (void)applyToView:(UIView *)view;
+ (void)beginNativeUpdate:(UIView *)view;
+ (void)endNativeUpdate:(UIView *)view;
+ (BOOL)hiddenForView:(UIView *)view nativeHidden:(BOOL)hidden;
+ (void)refreshVisibleViews;
@end
