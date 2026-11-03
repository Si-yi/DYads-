#import <Foundation/Foundation.h>
#import "DYYYFeedCardPolicy.h"
#import <math.h>

@interface AWEAwemeModel : NSObject
@property (nonatomic, strong) id dCardModel;
@property (nonatomic, strong) id hotSpotLynxCardModel;
@property (nonatomic, strong) id poiInfo;
@end
@implementation AWEAwemeModel
@end
@interface AWEFeedRootViewController : NSObject
@end
@implementation AWEFeedRootViewController
@end
@interface AWEHotListDataController : NSObject
@end
@implementation AWEHotListDataController
@end
@interface DYYYFeedDouble : NSObject
@property (nonatomic, strong) id parentViewController;
@end
@implementation DYYYFeedDouble
@end
@interface DYYYUnreadableCard : AWEAwemeModel
@end
@implementation DYYYUnreadableCard
- (id)dCardModel { [NSException raise:@"Unavailable" format:@"字段不可读"]; return nil; }
@end
@interface DYYYFeedCardPolicyTests : NSObject
@end
@implementation DYYYFeedCardPolicyTests
+ (void)check:(BOOL)value reason:(NSString *)reason { if (!value) [NSException raise:@"RegressionFailure" format:@"%@", reason]; }
+ (void)run {
    AWEAwemeModel *ordinary = [AWEAwemeModel new]; ordinary.poiInfo = [NSObject new];
    AWEAwemeModel *poi = [AWEAwemeModel new]; poi.dCardModel = [NSObject new];
    AWEAwemeModel *hot = [AWEAwemeModel new]; hot.hotSpotLynxCardModel = [NSObject new];
    NSObject *unknown = [NSObject new];
    [self check:![DYYYFeedCardPolicy isPromotionalCard:ordinary] reason:@"普通视频带定位不误判推广卡片"];
    [self check:[DYYYFeedCardPolicy isPromotionalCard:poi] && [DYYYFeedCardPolicy isPromotionalCard:hot] reason:@"两种独立卡片模型都能识别"];
    [self check:![DYYYFeedCardPolicy isPromotionalCard:unknown] && ![DYYYFeedCardPolicy isPromotionalCard:@{@"dCardModel": @YES}] reason:@"未知类和字典不猜测"];
    [self check:![DYYYFeedCardPolicy isPromotionalCard:[DYYYUnreadableCard new]] reason:@"原生字段异常保留内容"];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id saved = [defaults objectForKey:@"DYYYSkipHotSpot"];
    [defaults setBool:YES forKey:@"DYYYSkipHotSpot"];
    DYYYFeedDouble *feed = [DYYYFeedDouble new];
    AWEHotListDataController *controller = [AWEHotListDataController new];
    NSMutableArray *source = [@[ordinary, poi, hot, unknown] mutableCopy];
    NSArray *before = source.copy;
    [DYYYFeedCardPolicy bindFeed:feed controller:controller];
    [self check:[DYYYFeedCardPolicy filterArray:source controller:controller] == source reason:@"尚未挂到首页不处理"];
    feed.parentViewController = [AWEFeedRootViewController new];
    [self check:[DYYYFeedCardPolicy bindFeed:feed controller:controller] reason:@"首页推荐首次挂载补算"];
    [self check:![DYYYFeedCardPolicy bindFeed:feed controller:controller] reason:@"不重复触发重算"];
    NSArray *result = [DYYYFeedCardPolicy filterArray:source controller:controller];
    [self check:[result isEqual:@[ordinary, unknown]] && [source isEqual:before] reason:@"只过滤推荐卡片，保持顺序和原数据"];
    [self check:[result isKindOfClass:NSMutableArray.class] reason:@"可变列表类型保留"];
    NSObject *otherController = [NSObject new];
    [DYYYFeedCardPolicy bindFeed:feed controller:otherController];
    [self check:[DYYYFeedCardPolicy filterArray:source controller:otherController] == source reason:@"首页其他数据源不扩大过滤范围"];
    [defaults setBool:NO forKey:@"DYYYSkipHotSpot"];
    [self check:[DYYYFeedCardPolicy bindFeed:feed controller:controller] reason:@"关闭允许原生恢复原始数据"];
    [self check:[DYYYFeedCardPolicy filterArray:source controller:controller] == source reason:@"关闭完全透传"];
    [defaults setBool:YES forKey:@"DYYYSkipHotSpot"]; [DYYYFeedCardPolicy bindFeed:feed controller:controller]; feed = nil;
    [self check:[DYYYFeedCardPolicy filterArray:source controller:controller] == source reason:@"弱宿主释放后不保留作用域"];
    if (saved) [defaults setObject:saved forKey:@"DYYYSkipHotSpot"]; else [defaults removeObjectForKey:@"DYYYSkipHotSpot"];
    [self check:[DYYYFeedCardPolicy bottomConstant:-8 inset:65 reversed:NO] == -73 && [DYYYFeedCardPolicy bottomConstant:8 inset:65 reversed:YES] == 73 reason:@"底部约束正反方向都按原生常量偏移"];
    [self check:[DYYYFeedCardPolicy bottomConstant:-8 inset:0 reversed:NO] == -8 && [DYYYFeedCardPolicy bottomConstant:-8 inset:NAN reversed:NO] == -8 reason:@"关闭和非法尺寸恢复原生常量"];
    NSLog(@"DYYYFeedCardPolicy regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYFeedCardPolicyTests run]; } return 0; }
