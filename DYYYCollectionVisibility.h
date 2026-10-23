#import <UIKit/UIKit.h>

@interface DYYYCollectionVisibility : NSObject
+ (BOOL)hiddenForRow:(UIView *)row requested:(BOOL)hidden;
+ (void)applyRow:(UIView *)row;
+ (void)applyBar:(UIView *)bar;
+ (void)applyStack:(UIView *)stack;
@end
