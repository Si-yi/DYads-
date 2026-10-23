#import <UIKit/UIKit.h>

// 首页好友分享来源提示，独立于抖音文案与原生推荐标签。
@interface DYYYFriendShareBadgeView : UIVisualEffectView
+ (void)updateForController:(UIViewController *)controller;
+ (void)resetForController:(UIViewController *)controller;
@end
