#import <UIKit/UIKit.h>

@interface DYYYDebugMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title handler:(void (^)(void))handler;
@end

@interface DYYYDebugMenuView : UIView
+ (void)presentFromController:(UIViewController *)presenter window:(UIWindow *)window title:(NSString *)title message:(NSString *)message items:(NSArray<DYYYDebugMenuItem *> *)items;
@end
