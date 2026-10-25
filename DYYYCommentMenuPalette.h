#import <UIKit/UIKit.h>

@interface DYYYCommentMenuPalette : NSObject
+ (BOOL)isManagedSelectionOverlay:(UIView *)view;
+ (void)synchronizeCell:(UIView *)cell;
+ (void)synchronizeSelectionSection:(id)section overlay:(UIView *)overlay;
+ (void)synchronizeContentController:(UIViewController *)controller;
+ (void)applyLabel:(UILabel *)label controller:(UIViewController *)controller;
+ (CALayer *)cardLayerInCell:(UIView *)cell;
+ (void)applyInView:(UIView *)view controller:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (void)restoreView:(UIView *)view;
@end
