#import <UIKit/UIKit.h>
@interface DYYYRefreshIndicatorStyle : NSObject
+ (void)synchronizeHeader:(UIView *)header;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYRefreshIndicatorStyle (RuntimeHooks)
+ (void)installHooks;
@end
