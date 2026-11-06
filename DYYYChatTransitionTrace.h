#import <UIKit/UIKit.h>

@interface DYYYChatTransitionTrace : NSObject
+ (void)recordController:(UIViewController *)controller phase:(NSString *)phase;
+ (void)watchController:(UIViewController *)controller phase:(NSString *)phase;
+ (NSDictionary *)diagnostics;
@end
