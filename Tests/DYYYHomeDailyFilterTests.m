#import <Foundation/Foundation.h>
#import "DYYYHomeDailyFilter.h"

// 用导出的原生字段构造双身，不依赖 UIKit、网络和消息服务。
@interface AWEAwemeModel : NSObject
@property BOOL is24Story;
@property BOOL is25Story;
@property BOOL isStory;
@property long long isMomentStory;
@property NSInteger awemeType;
@property (nonatomic, strong) id storyGroup;
@end
@implementation AWEAwemeModel
@end
@interface DYYYUnreadableDailyModel : AWEAwemeModel
@end
@implementation DYYYUnreadableDailyModel
- (BOOL)is24Story { [NSException raise:@"Unavailable" format:@"读取失败"]; return NO; }
@end
@interface AWEFeedRootViewController : NSObject
@end
@implementation AWEFeedRootViewController
@end
@interface DYYYDailyFeedDouble : NSObject
@property (nonatomic, strong) id parentViewController;
@end
@implementation DYYYDailyFeedDouble
@end

@interface DYYYHomeDailyFilterTests : NSObject
+ (void)run;
@end
@implementation DYYYHomeDailyFilterTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    AWEAwemeModel *normal = [AWEAwemeModel new];
    AWEAwemeModel *photo = [AWEAwemeModel new];
    photo.awemeType = 68; photo.storyGroup = [NSObject new];
    NSMutableArray *source = [NSMutableArray arrayWithObjects:normal, photo, nil];
    for (NSString *flag in @[ @"is24Story", @"is25Story", @"isStory", @"isMomentStory" ]) {
        AWEAwemeModel *daily = [AWEAwemeModel new];
        [daily setValue:@1 forKey:flag];
        [source insertObject:daily atIndex:1];
    }
    NSObject *unknown = [NSObject new];
    [source addObject:unknown];
    [source addObject:@{ @"isStory": @YES }];
    DYYYUnreadableDailyModel *unreadable = [DYYYUnreadableDailyModel new];
    [source addObject:unreadable];
    NSArray *prior = source.copy;
    [self check:[DYYYHomeDailyFilter filterArray:source enabled:NO home:YES] == source reason:@"开关关闭原样透传"];
    [self check:[DYYYHomeDailyFilter filterArray:source enabled:YES home:NO] == source reason:@"详情和其他页面不处理"];
    NSArray *result = [DYYYHomeDailyFilter filterArray:source enabled:YES home:YES];
    [self check:result.count == source.count - 4 reason:@"四种原生日常标记均过滤"];
    [self check:result[0] == normal && result[1] == photo && result[2] == unknown reason:@"普通视频图文与未知对象原顺序保留"];
    [self check:[result containsObject:unreadable] reason:@"字段异常不误删"];
    [self check:[source isEqual:prior] reason:@"原始列表、日常标记不改写"];
    [self check:[result isKindOfClass:NSMutableArray.class] reason:@"原生可变列表类型保留"];
    NSArray *immutable = prior.copy;
    [self check:![[DYYYHomeDailyFilter filterArray:immutable enabled:YES home:YES] isKindOfClass:NSMutableArray.class] reason:@"不可变列表类型保留"];
    NSArray *ordinary = @[normal, photo];
    [self check:[DYYYHomeDailyFilter filterArray:ordinary enabled:YES home:YES] == ordinary reason:@"无命中不分配新列表"];
    [self check:[DYYYHomeDailyFilter filterArray:NSNull.null enabled:YES home:YES] == (id)NSNull.null reason:@"未知结构原样保留"];
    NSArray *allDaily = [source subarrayWithRange:NSMakeRange(1, 4)];
    [self check:[DYYYHomeDailyFilter filterArray:allDaily enabled:YES home:YES].count == 0 reason:@"全日常批次返回空列表，不伪造替代作品"];
    unreadable.is25Story = YES;
    [self check:[DYYYHomeDailyFilter isDailyModel:unreadable] reason:@"一个字段异常仍可由其他确切标记识别"];

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id saved = [defaults objectForKey:@"DYYYHideHomeDaily"];
    [defaults setBool:YES forKey:@"DYYYHideHomeDaily"];
    NSObject *controller = [NSObject new];
    DYYYDailyFeedDouble *feed = [DYYYDailyFeedDouble new];
    [self check:![DYYYHomeDailyFilter bindFeed:feed controller:controller] reason:@"未挂载到首页不补算"];
    [self check:[DYYYHomeDailyFilter filterArray:source controller:controller] == source reason:@"未确认首页不删作品"];
    feed.parentViewController = [AWEFeedRootViewController new];
    [self check:[DYYYHomeDailyFilter bindFeed:feed controller:controller] reason:@"首次挂载首页需要补算"];
    [self check:![DYYYHomeDailyFilter bindFeed:feed controller:controller] reason:@"重复 appearance 不触发循环重算"];
    [self check:[DYYYHomeDailyFilter filterArray:source controller:controller].count == source.count - 5 reason:@"绑定首页范围后生效"];
    [defaults setBool:NO forKey:@"DYYYHideHomeDaily"];
    [self check:[DYYYHomeDailyFilter bindFeed:feed controller:controller] reason:@"关闭后允许原生从原始列表恢复"];
    [self check:[DYYYHomeDailyFilter filterArray:source controller:controller] == source reason:@"关闭恢复原列表"];
    [defaults setBool:YES forKey:@"DYYYHideHomeDaily"];
    [DYYYHomeDailyFilter bindFeed:feed controller:controller];
    feed = nil;
    [self check:[DYYYHomeDailyFilter filterArray:source controller:controller] == source reason:@"弱宿主释放后不残留过滤范围"];
    if (saved) [defaults setObject:saved forKey:@"DYYYHideHomeDaily"];
    else [defaults removeObjectForKey:@"DYYYHideHomeDaily"];
    NSLog(@"DYYYHomeDailyFilter regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYHomeDailyFilterTests run]; } return 0; }
