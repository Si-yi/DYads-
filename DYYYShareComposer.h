#import <UIKit/UIKit.h>

// 评论分享留言区；不接管原生文本、选择、代理或发送动作。
@interface DYYYShareComposer : NSObject
+ (void)synchronizeInput:(UITextView *)input;
+ (void)restoreController:(UIViewController *)controller;
+ (void)restoreInput:(UITextView *)input;
+ (UIColor *)adjustTextColor:(UIColor *)color input:(UITextView *)input;
+ (NSDictionary *)adjustTypingAttributes:(NSDictionary *)attributes input:(UITextView *)input;
+ (NSDictionary *)diagnosticsForController:(UIViewController *)controller;
@end
