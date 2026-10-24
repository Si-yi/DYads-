#import <UIKit/UIKit.h>

@interface DYYYSameStyleVisibility : NSObject
+ (void)applyToView:(UIView *)view;
+ (void)beginNativeUpdate:(UIView *)view;
+ (void)endNativeUpdate:(UIView *)view;
+ (void)refreshVisibleViews;
@end
