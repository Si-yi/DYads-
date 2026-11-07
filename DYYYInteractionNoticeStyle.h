#import <UIKit/UIKit.h>
@interface DYYYInteractionNoticeStyle : NSObject
+ (id)beginUpdate:(UIView *)cell;
+ (void)endUpdate:(id)token;
+ (void)synchronizeCell:(UIView *)cell;
+ (void)resetCell:(UIView *)cell;
+ (void)synchronizeFansController:(UIViewController *)controller;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYInteractionNoticeStyle (RuntimeHooks)
+ (void)installHooks;
+ (BOOL)installFansCellHooksForCell:(UIView *)cell;
@end
