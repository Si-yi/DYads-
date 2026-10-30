#import <Foundation/Foundation.h>

@interface DYYYHomeDailyFilter : NSObject
+ (BOOL)isDailyModel:(id)model;
+ (NSArray *)filterArray:(id)array enabled:(BOOL)enabled home:(BOOL)home;
+ (BOOL)bindFeed:(id)feed controller:(id)controller;
+ (NSArray *)filterArray:(id)array controller:(id)controller;
+ (NSDictionary *)diagnostics;
@end
