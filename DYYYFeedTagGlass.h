#import <UIKit/UIKit.h>

@interface DYYYFeedTagGlass : NSObject
+ (void)decorateTag:(UIView *)tag;
+ (void)decorateStack:(UIView *)stack;
+ (void)restoreTag:(UIView *)tag;
+ (void)refreshVisibleTags;
@end
