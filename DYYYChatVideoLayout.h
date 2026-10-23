#import <UIKit/UIKit.h>

@interface DYYYChatVideoLayout : NSObject
+ (CGRect)adjustedFrame:(CGRect)frame view:(UIView *)view controller:(UIViewController *)controller;
+ (void)layoutCellController:(UIViewController *)controller;
+ (void)layoutInteractionController:(UIViewController *)controller;
+ (void)updateReplyBackground:(UIViewController *)controller;
+ (BOOL)ownsReplyBackground:(UIView *)view;
@end
