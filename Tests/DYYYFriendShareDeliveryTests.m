#import <Foundation/Foundation.h>
#import "DYYYFriendShareDelivery.h"

@interface DYYYDeliveryTestCell : NSObject
@property (nonatomic, strong) id model;
@property (nonatomic, strong) NSMutableArray *calls;
@end
@implementation DYYYDeliveryTestCell
- (instancetype)init { if ((self = [super init])) _calls = [NSMutableArray array]; return self; }
- (void)prepareForDisplay { [self.calls addObject:@"prepare"]; }
- (void)play { [self.calls addObject:@"play"]; }
@end
@interface DYYYDeliveryInvalidCell : DYYYDeliveryTestCell
@end
@implementation DYYYDeliveryInvalidCell
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if (selector == NSSelectorFromString(@"play")) return [NSMethodSignature signatureWithObjCTypes:"B@:"];
    return [super methodSignatureForSelector:selector];
}
@end
// 模拟 39.5 的现场行为：updateAwemeList: 不把新 ID 插入数据源。
@interface DYYYDeliveryTestController : NSObject
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, strong) NSMutableArray *filteredDataSource;
@property (nonatomic) NSUInteger calculations;
@end
@implementation DYYYDeliveryTestController
- (void)updateAwemeList:(id)models {}
- (void)calculateFilteredDataSource {
    self.calculations++;
    self.filteredDataSource = [NSMutableArray array];
    for (NSDictionary *model in self.dataSource)
        if (![model[@"filtered"] boolValue]) [self.filteredDataSource addObject:model];
}
@end
@interface DYYYDeliveryInvalidController : DYYYDeliveryTestController
@end
@implementation DYYYDeliveryInvalidController
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if (selector == NSSelectorFromString(@"calculateFilteredDataSource")) return nil;
    return [super methodSignatureForSelector:selector];
}
@end
// 原生索引重载并不等于刷新 UITableView 的已有行缓存。
@interface DYYYDeliveryTestFeed : NSObject
@property (nonatomic, strong) DYYYDeliveryTestController *dataController;
@property (nonatomic, copy) NSArray *rendered;
@property (nonatomic, strong) id current;
@property (nonatomic, strong) NSMutableArray *calls;
@end
@implementation DYYYDeliveryTestFeed
- (instancetype)init { if ((self = [super init])) _calls = [NSMutableArray array]; return self; }
- (void)reloadTableViewData {
    [self.calls addObject:@"table"];
    self.rendered = [self.dataController.filteredDataSource copy];
}
- (void)reloadWithCurrentIndex:(long long)index {
    [self.calls addObject:@"selection"];
    self.current = self.rendered[(NSUInteger)index];
}
@end
@interface DYYYDeliveryInvalidFeed : DYYYDeliveryTestFeed
@end
@implementation DYYYDeliveryInvalidFeed
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if (selector == NSSelectorFromString(@"reloadTableViewData")) return nil;
    return [super methodSignatureForSelector:selector];
}
@end
@interface DYYYFriendShareDeliveryTests : NSObject
+ (void)run;
@end
@implementation DYYYFriendShareDeliveryTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    NSDictionary *one = @{ @"itemID": @"first-original" }, *two = @{ @"itemID": @"second-original" };
    NSDictionary *shareA = @{ @"itemID": @"share-A" }, *shareB = @{ @"itemID": @"share-B" };
    NSArray *original = @[ one, two ];
    NSArray *feed = [DYYYFriendShareDelivery feedWithOriginal:original sharedModels:@{ @"share-A": shareA, @"share-B": shareB }
        orderedIDs:@[ @"share-A", @"share-B" ]];
    [self check:[feed isEqual:@[ shareA, shareB, one, two ]] reason:@"一次提交完整分享前缀，保留原首条和原有顺序"];
    [self check:[original isEqual:@[ one, two ]] reason:@"不能在原列表上逐条修改"];
    feed = [DYYYFriendShareDelivery feedWithOriginal:feed sharedModels:@{ @"share-A": shareA, @"share-B": shareB }
        orderedIDs:@[ @"share-A", @"share-B", @"share-A" ]];
    [self check:feed.count == 4 reason:@"隐藏页接收重复结果也不能重复插入"];
    feed = [DYYYFriendShareDelivery feedWithOriginal:original sharedModels:@{ @"share-A": shareA }
        orderedIDs:@[ @"share-A", @"not-ready" ]];
    [self check:[feed isEqual:@[ shareA, one, two ]] reason:@"单条未加载不能挡住已就绪分享"];
    feed = [DYYYFriendShareDelivery feedWithOriginal:@[] sharedModels:@{ @"share-A": shareA } orderedIDs:@[ @"share-A" ]];
    [self check:feed.count == 1 reason:@"原列表为空也可以准备首批分享"];
    feed = [DYYYFriendShareDelivery feedWithOriginal:original sharedModels:@{ @"share-A": shareB } orderedIDs:@[ @"share-A" ]];
    [self check:[feed isEqual:original] reason:@"缓存模型 ID 不匹配时不能混入首页"];

    NSSet *watched = [NSSet setWithArray:@[ @"share-A", @"share-B" ]];
    NSDictionary *shareC = @{ @"itemID": @"share-C" }, *shareD = @{ @"itemID": @"share-D" };
    NSDictionary *cached = @{ @"share-A": shareA, @"share-B": shareB, @"share-C": shareC, @"share-D": shareD };
    NSArray *delayed = [DYYYFriendShareDelivery feedWithOriginal:@[ shareA, shareB, shareC, one, two ] sharedModels:cached
        orderedIDs:@[ @"share-C", @"share-D", @"share-A", @"share-B" ] watchedIDs:watched currentItemID:@"share-C"];
    [self check:[delayed isEqual:@[ shareC, shareD, one, two ]]
        reason:@"后续批次不得从 active 缓存或原列表重推已经划走的分享"];
    delayed = [DYYYFriendShareDelivery feedWithOriginal:@[ shareC, one ] sharedModels:cached
        orderedIDs:@[ @"share-D", @"share-C" ] watchedIDs:[NSSet setWithArray:@[ @"share-C" ]] currentItemID:@"share-C"];
    [self check:[delayed containsObject:shareC] reason:@"播完一轮但仍显示的当前 Cell 不可立即删除"];
    delayed = [DYYYFriendShareDelivery feedWithOriginal:delayed sharedModels:cached orderedIDs:@[ @"share-D", @"share-C" ]
        watchedIDs:[NSSet setWithArray:@[ @"share-C" ]] currentItemID:@"share-D"];
    [self check:[delayed isEqual:@[ shareD, one ]] reason:@"离开已完成的当前 Cell 后，不得再将其排回列表"];
    delayed = [DYYYFriendShareDelivery feedWithOriginal:@[ shareA, shareB, one, two ] sharedModels:cached
        orderedIDs:@[ @"share-A", @"share-B" ] watchedIDs:watched currentItemID:nil];
    [self check:[delayed isEqual:original] reason:@"整批都已刷后重新打开，旧来源缓存不能复活整批分享"];

    DYYYDeliveryTestController *controller = [DYYYDeliveryTestController new];
    controller.dataSource = [original mutableCopy];
    [controller calculateFilteredDataSource];
    NSArray *merged = [DYYYFriendShareDelivery feedWithOriginal:original sharedModels:@{ @"share-A": shareA, @"share-B": shareB }
        orderedIDs:@[ @"share-A", @"share-B" ]];
    [controller updateAwemeList:merged];
    [self check:[controller.dataSource isEqual:original] reason:@"复现旧入口调用完成但未插入新 ID"];
    [self check:[DYYYFriendShareDelivery replaceFeed:merged controller:controller] &&
        [controller.dataSource isEqual:merged] && [controller.filteredDataSource isEqual:merged]
        reason:@"整表 setter 与原生过滤计算必须让两个列表均包含新分享"];
    [self check:[controller.dataSource isKindOfClass:NSMutableArray.class] && controller.dataSource != merged
        reason:@"保留原生可变数据源，不修改调用方列表"];
    [self check:[DYYYFriendShareDelivery replaceFeed:merged controller:controller] && controller.dataSource.count == 4
        reason:@"重复准备相同列表不增加重复项"];
    NSDictionary *ad = @{ @"itemID": @"ad", @"filtered": @YES };
    [self check:[DYYYFriendShareDelivery replaceFeed:@[ shareA, ad, shareB, one ] controller:controller] &&
        [controller.filteredDataSource isEqual:@[ shareA, shareB, one ]]
        reason:@"重算原生过滤列表，不能把原始列表直接塞入过滤结果"];
    [self check:[DYYYFriendShareDelivery replaceFeed:@[ shareA ] controller:controller] &&
        [controller.filteredDataSource isEqual:@[ shareA ]] reason:@"跨页准备新批次不能保留旧播放列表"];
    DYYYDeliveryInvalidController *unsupported = [DYYYDeliveryInvalidController new];
    unsupported.dataSource = [original mutableCopy];
    [self check:![DYYYFriendShareDelivery replaceFeed:merged controller:unsupported] &&
        [unsupported.dataSource isEqual:original] && !unsupported.calculations
        reason:@"缺少原生过滤入口时不能只写入半套列表"];

    // 数据源已经包含新分享，但实际表格仍显示上次旧视频；单独重设索引不能修复。
    DYYYDeliveryTestFeed *nativeFeed = [DYYYDeliveryTestFeed new];
    nativeFeed.dataController = controller;
    nativeFeed.rendered = original;
    [self check:[DYYYFriendShareDelivery replaceFeed:merged controller:controller] reason:@"准备完整新列表"];
    [nativeFeed reloadWithCurrentIndex:0];
    [self check:[nativeFeed.current isEqual:one] && nativeFeed.rendered.count == 2
        reason:@"复现更新数据源和重设索引后仍显示旧 Cell"];
    [nativeFeed.calls removeAllObjects];
    [self check:[DYYYFriendShareDelivery reloadFeed:nativeFeed atIndex:0] && [nativeFeed.current isEqual:shareA] &&
        [nativeFeed.rendered isEqual:merged] && [nativeFeed.calls isEqual:@[ @"table", @"selection" ]]
        reason:@"必须先重载实际表格，再选新分享的索引"];
    [self check:[DYYYFriendShareDelivery reloadFeed:nativeFeed atIndex:1] && [nativeFeed.current isEqual:shareB]
        reason:@"重载后选择非零行也应匹配目标视频"];
    DYYYDeliveryInvalidFeed *invalidFeed = [DYYYDeliveryInvalidFeed new];
    [self check:![DYYYFriendShareDelivery reloadFeed:invalidFeed atIndex:0] && !invalidFeed.calls.count
        reason:@"缺少原生表格重载入口时不能假装完成同步"];

    DYYYDeliveryTestCell *cell = [DYYYDeliveryTestCell new]; cell.model = shareA;
    [self check:![DYYYFriendShareDelivery prepareAndPlayCell:cell itemID:@"share-A" allowed:NO] && !cell.calls.count
        reason:@"其他界面可以准备列表，但不能抢播首页 Cell"];
    [self check:![DYYYFriendShareDelivery prepareAndPlayCell:cell itemID:@"share-B" allowed:YES] && !cell.calls.count
        reason:@"不能激活仍绑定旧视频的 Cell"];
    [self check:[DYYYFriendShareDelivery prepareAndPlayCell:cell itemID:@"share-A" allowed:YES] &&
        [cell.calls isEqual:@[ @"prepare", @"play" ]] reason:@"当前可见模型匹配后，必须先准备 Cell 再请求播放"];
    DYYYDeliveryInvalidCell *invalid = [DYYYDeliveryInvalidCell new]; invalid.model = shareA;
    [self check:![DYYYFriendShareDelivery prepareAndPlayCell:invalid itemID:@"share-A" allowed:YES] && !invalid.calls.count
        reason:@"未知原生签名不能触发一半的准备流程"];
    NSLog(@"DYYYFriendShareDelivery regression tests passed");
}
@end
int main(void) {
    @autoreleasepool { [DYYYFriendShareDeliveryTests run]; }
    return 0;
}
