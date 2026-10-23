#import <UIKit/UIKit.h>

@interface DYYYArticleBackdrop : NSObject
+ (void)synchronizeController:(UIViewController *)controller refresh:(BOOL)refresh;
+ (void)removeFromController:(UIViewController *)controller;
@end

@interface DYYYArticleBackdrop (Hooks)
+ (void)installHooks;
@end

// 只保存文章底边的一行背景像素，不拉伸或移动正文。
@interface DYYYArticleBackdropView : UIImageView
@property (nonatomic, assign) CGFloat contentBottom;
@property (nonatomic, assign) CGRect sourceBounds;
@property (nonatomic, assign) BOOL samplePending;
@property (nonatomic, assign) BOOL resamplePending;
@end
