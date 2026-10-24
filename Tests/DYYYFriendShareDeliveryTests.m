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
