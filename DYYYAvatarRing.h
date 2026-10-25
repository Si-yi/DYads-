#import <UIKit/UIKit.h>

@interface DYYYAvatarRing : NSObject
+ (void)applyToRing:(UIView *)ring;
+ (void)restoreRing:(UIView *)ring;
+ (void)beginNativeUpdate:(UIView *)ring;
+ (void)endNativeUpdate:(UIView *)ring;
+ (void)refreshVisibleRings;
+ (NSDictionary *)diagnostics;
@end
