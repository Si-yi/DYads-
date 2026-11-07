#import <UIKit/UIKit.h>
@interface DYYYMessageListStyle : NSObject
+ (void)preparePreferences;
+ (BOOL)cardsEnabled;
+ (BOOL)topEnabled;
+ (CGFloat)rowHeight:(CGFloat)native controller:(UIViewController *)controller table:(UITableView *)table indexPath:(NSIndexPath *)path;
+ (void)synchronizeLightInteraction:(UIView *)view;
+ (void)resetLightInteraction:(UIView *)view;
+ (void)synchronizeController:(UIViewController *)controller;
+ (void)synchronizeCell:(UITableViewCell *)cell;
+ (void)resetCell:(UITableViewCell *)cell;
+ (BOOL)contentAdapterReady;
+ (CGRect)nativeContentFrame:(CGRect)frame forView:(UIView *)view;
+ (id)beginContentGeometry:(UIView *)view;
+ (void)endContentGeometry:(id)token;
+ (CGAffineTransform)nativeContentTransform:(CGAffineTransform)transform forView:(UIView *)view;
+ (void)didSetContentTransform:(UIView *)view;
+ (id)beginNoticePlateFrame:(UIView *)plate;
+ (void)endNoticePlateFrame:(id)token;
+ (BOOL)passThroughNoticeActions:(CGPoint)point bar:(UIView *)bar;
+ (void)synchronizeBar:(UIView *)bar;
+ (void)synchronizeHeaderForView:(UIView *)view;
+ (void)scheduleBarSynchronization:(UIView *)bar;
+ (UIColor *)nativeBackgroundColor:(UIColor *)color forBar:(UIView *)bar;
+ (BOOL)nativeOpaque:(BOOL)opaque forBar:(UIView *)bar;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
