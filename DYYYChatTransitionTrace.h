#import <UIKit/UIKit.h>

@interface DYYYChatTransitionTrace : NSObject
+ (void)recordController:(UIViewController *)controller phase:(NSString *)phase;
+ (void)watchController:(UIViewController *)controller phase:(NSString *)phase;
+ (void)recordPaging:(UIViewController *)controller scrollView:(UIScrollView *)scroll phase:(NSString *)phase probe:(BOOL)probe;
+ (NSDictionary *)diagnostics;
@end
