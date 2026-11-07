#import <UIKit/UIKit.h>
@interface DYYYInteractionNoticeStyle : NSObject
+ (id)beginUpdate:(UIView *)cell;
+ (void)endUpdate:(id)token;
+ (void)synchronizeCell:(UIView *)cell;
+ (void)resetCell:(UIView *)cell;
+ (void)synchronizeFansController:(UIViewController *)controller;
+ (void)prepareFansCell:(UIView *)cell table:(UITableView *)table indexPath:(NSIndexPath *)path controller:(UIViewController *)controller;
+ (void)clearFansBinding:(UIView *)cell;
+ (void)synchronizeMergedController:(UIViewController *)controller;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYInteractionNoticeStyle (RuntimeHooks)
+ (void)installHooks;
+ (BOOL)installFansCellHooksForCell:(UIView *)cell;
+ (BOOL)installFansCellHooksForClass:(Class)cls;
+ (NSDictionary *)hookDiagnostics;
@end
