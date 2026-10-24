#import <UIKit/UIKit.h>

@interface DYYYFriendShareService : NSObject
+ (NSDictionary *)diagnostics;
+ (void)applicationOpened;
+ (void)applicationEnteredBackground;
+ (void)applicationBecameActive;
+ (void)bindHomeFeed:(UIViewController *)feed;
+ (void)scanWithToast:(BOOL)showToast;
+ (NSArray *)arrangeData:(NSArray *)data controller:(id)controller;
+ (void)homeDidScroll:(UIViewController *)feed;
+ (void)homeDidScroll:(UIViewController *)feed scrollView:(UIScrollView *)scrollView;
+ (void)homeWillDrag:(UIViewController *)feed scrollView:(UIScrollView *)scrollView;
+ (void)homeDidLeave:(UIViewController *)feed;
+ (void)homeWillLoop:(UIViewController *)feed;
+ (void)homePlaybackTouched:(UIViewController *)feed;
+ (void)homePlaybackAdvanced:(UIViewController *)feed time:(NSTimeInterval)time;
+ (void)clearWatched;
+ (NSDictionary *)shareSourceForItemID:(NSString *)itemID controller:(UIViewController *)controller;
@end
