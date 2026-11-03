#import <Foundation/Foundation.h>

@interface DYYYFeedCardPolicy : NSObject
+ (BOOL)isPromotionalCard:(id)model;
+ (BOOL)bindFeed:(id)feed controller:(id)controller;
+ (BOOL)isEnabledForController:(id)controller;
+ (NSArray *)filterArray:(id)array controller:(id)controller;
// 几何纯计算：按原生常量增减，重复布局不累加。
+ (double)bottomConstant:(double)native inset:(double)inset reversed:(BOOL)reversed;
@end
