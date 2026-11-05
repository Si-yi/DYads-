#import <UIKit/UIKit.h>

@interface DYYYFeedTagGlass : NSObject
+ (void)installHooks;
+ (void)decorateTag:(UIView *)tag;
+ (BOOL)isLabelView:(UIView *)view;
+ (void)decorateStack:(UIView *)stack;
+ (void)restoreTag:(UIView *)tag;
+ (void)beginNativeUpdate:(UIView *)tag;
+ (void)endNativeUpdate:(UIView *)tag;
@end
