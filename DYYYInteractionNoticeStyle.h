#import <UIKit/UIKit.h>
@interface DYYYInteractionNoticeStyle : NSObject
+ (id)beginUpdate:(UICollectionViewCell *)cell;
+ (void)endUpdate:(id)token;
+ (void)synchronizeCell:(UICollectionViewCell *)cell;
+ (void)resetCell:(UICollectionViewCell *)cell;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
@interface DYYYInteractionNoticeStyle (RuntimeHooks)
+ (void)installHooks;
@end
