#import <UIKit/UIKit.h>

@interface DYYYChatInputList : NSObject
+ (void)synchronizeHost:(UIViewController *)host topActive:(BOOL)active;
+ (id)beginNativeLayoutForComponent:(id)component;
+ (void)endNativeLayout:(id)token;
+ (void)synchronizeInputController:(UIViewController *)input active:(BOOL)active;
+ (id)tokenForTable:(UITableView *)table;
+ (id)beginTableUpdates:(UITableView *)table;
+ (void)endTableUpdates:(id)token;
+ (void)synchronizeTable:(UITableView *)table;
+ (CGRect)frameForBottomTips:(UIView *)tips proposedFrame:(CGRect)frame;
+ (NSDictionary *)diagnostics;
@end
