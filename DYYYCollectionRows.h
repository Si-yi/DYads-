#import <UIKit/UIKit.h>

@interface DYYYCollectionRows : NSObject
+ (BOOL)requestedHidden:(BOOL)hidden row:(UIView *)row;
+ (void)applyStack:(UIView *)stack;
+ (void)refreshVisibleStacks;
@end
