#import <UIKit/UIKit.h>
// 仅消息主列表的绘制视口；原生分页容器、行高和消息数据保持原样。
@interface DYYYMessageListViewport : NSObject
+ (BOOL)adapterReady;
+ (void)synchronizeController:(UIViewController *)controller;
+ (CGRect)nativeFrame:(CGRect)frame table:(UITableView *)table;
+ (UIEdgeInsets)nativeInset:(UIEdgeInsets)inset table:(UITableView *)table indicator:(BOOL)indicator;
+ (void)detachTable:(UITableView *)table;
+ (void)refresh;
+ (NSDictionary *)diagnostics;
@end
