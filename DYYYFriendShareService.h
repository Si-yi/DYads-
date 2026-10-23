#import <UIKit/UIKit.h>

@interface DYYYFriendShareService : NSObject
+ (void)applicationOpened;
+ (void)applicationEnteredBackground;
+ (void)applicationBecameActive;
+ (void)bindHomeFeed:(UIViewController *)feed;
+ (void)scanWithToast:(BOOL)showToast;
+ (NSArray *)arrangeData:(NSArray *)data controller:(id)controller;
+ (void)homeDidScroll:(UIViewController *)feed;
+ (void)homeWillDrag:(UIViewController *)feed;
+ (void)homeWillLoop:(UIViewController *)feed;
+ (void)clearWatched;
@end
