#import <UIKit/UIKit.h>

@interface DYYYChatInputList : NSObject
+ (id)beginNativeLayoutForComponent:(id)component;
+ (void)endNativeLayout:(id)token;
+ (void)synchronizeInputController:(UIViewController *)input active:(BOOL)active;
+ (CGRect)frameForBottomTips:(UIView *)tips proposedFrame:(CGRect)frame;
+ (NSDictionary *)diagnostics;
@end
