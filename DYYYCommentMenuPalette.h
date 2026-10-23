#import <UIKit/UIKit.h>

@interface DYYYCommentMenuPalette : NSObject
+ (void)synchronizeCell:(UIView *)cell;
+ (void)applyLabel:(UILabel *)label controller:(UIViewController *)controller;
+ (CALayer *)cardLayerInCell:(UIView *)cell;
+ (void)applyInView:(UIView *)view controller:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (void)restoreView:(UIView *)view;
@end
