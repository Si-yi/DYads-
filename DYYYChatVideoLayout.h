#import <UIKit/UIKit.h>

@interface DYYYChatVideoLayout : NSObject
+ (CGRect)adjustedFrame:(CGRect)frame view:(UIView *)view controller:(UIViewController *)controller;
+ (void)layoutCellController:(UIViewController *)controller;
+ (void)layoutInteractionController:(UIViewController *)controller;
+ (void)updateReplyBackground:(UIViewController *)controller;
+ (void)syncPlayerBackdrop:(UIViewController *)controller;
+ (void)removePlayerBackdrop:(UIViewController *)controller;
+ (void)refresh;
+ (BOOL)ownsReplyBackground:(UIView *)view;
@end
