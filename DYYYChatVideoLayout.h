#import <UIKit/UIKit.h>

@interface DYYYChatVideoLayout : NSObject
+ (BOOL)usesNativePagingForController:(UIViewController *)controller;
+ (void)updateReplyBackground:(UIViewController *)controller;
+ (void)syncPlayerBackdrop:(UIViewController *)controller;
+ (void)removePlayerBackdrop:(UIViewController *)controller;
+ (void)refresh;
+ (BOOL)ownsReplyBackground:(UIView *)view;
@end
