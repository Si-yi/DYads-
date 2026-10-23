#import <UIKit/UIKit.h>

@interface DYYYCommentMenuPalette : NSObject
+ (void)synchronizeCell:(UIView *)cell;
+ (void)applyInView:(UIView *)view controller:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (void)restoreView:(UIView *)view;
@end
