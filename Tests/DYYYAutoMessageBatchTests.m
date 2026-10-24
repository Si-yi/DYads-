#import <Foundation/Foundation.h>
#import "DYYYAutoMessageBatch.h"

@interface DYYYAutoMessageBatchTests : NSObject
+ (void)run;
@end
@implementation DYYYAutoMessageBatchTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    NSDictionary *one = @{ @"userID": @"one", @"ownerID": @"A", @"name": @"单独称呼", @"message": @"比心",
        @"enabled": @NO, @"sendMode": @1, @"randomText": @NO, @"imagePaths": @[ @"kept-image" ], @"createdAt": @123, @"extra": @"keep" };
    NSDictionary *two = @{ @"userID": @"two", @"ownerID": @"A", @"name": @"好友二", @"message": @"早安", @"randomText": @NO };
    NSDictionary *other = @{ @"userID": @"one", @"ownerID": @"B", @"name": @"另一账户", @"message": @"不改" };
    NSDictionary *legacy = @{ @"userID": @"one", @"ownerID": @"", @"name": @"未绑定", @"message": @"旧配置" };
    NSArray *configs = @[ one, two, other, legacy ];
    NSArray *snapshot = [configs copy];
    NSArray *contacts = @[ @{ @"userID": @"one", @"name": @"备注一", @"avatar": @"avatar", @"aliases": @[ @"原昵称" ] },
        @{ @"userID": @"not-added", @"name": @"未添加互关好友" } ];
    NSArray *friends = [DYYYAutoMessageBatch configuredFriends:configs ownerID:@"A" contacts:contacts];
    [self check:friends.count == 2 && [friends[0][@"name"] isEqual:@"备注一"] reason:@"仅列当前账户已添加好友，使用备注显示"];
    [self check:[friends[1][@"name"] isEqual:@"好友二"] reason:@"不在联系人缓存中的已添加好友也须显示"];
    [self check:[friends[0][@"aliases"] containsObject:@"单独称呼"] && [friends[0][@"aliases"] containsObject:@"原昵称"] reason:@"搜索支持原配置称呼与昵称"];
    [self check:![DYYYAutoMessageBatch configuredFriends:configs ownerID:@"" contacts:contacts].count reason:@"无账户不能选到其他账户配置"];
    NSString *text = @"早安 {remark}\n今天也开心";
    NSArray *updated = [DYYYAutoMessageBatch configsByUpdatingText:text randomText:YES configs:configs ownerID:@"A" selectedUserIDs:[NSSet setWithArray:@[ @"one", @"deleted" ]]];
    NSMutableDictionary *expected = [one mutableCopy]; expected[@"message"] = text; expected[@"randomText"] = @YES;
    [self check:[updated[0] isEqual:expected] reason:@"只改所选好友的两项文字字段，保留禁用状态、图片、模式、序号基础和未知字段"];
    [self check:[updated[1] isEqual:two] && [updated[2] isEqual:other] && [updated[3] isEqual:legacy] reason:@"未选、其他账户同 UID 和未绑定旧配置都不可改"];
    [self check:[configs isEqual:snapshot] && [one[@"message"] isEqual:@"比心"] reason:@"生成草稿不能改动原配置，取消后原内容保留"];
    [self check:updated.count == configs.count reason:@"保存时已删除的目标不能被重新添加"];
    updated = [DYYYAutoMessageBatch configsByUpdatingText:@"统一内容" randomText:NO configs:configs ownerID:@"A" selectedUserIDs:[NSSet setWithArray:@[ @"one", @"two" ]]];
    [self check:[updated[0][@"message"] isEqual:@"统一内容"] && [updated[1][@"message"] isEqual:@"统一内容"] && [updated[2] isEqual:other]
        reason:@"全选只统一当前账户已添加的两位好友"];
    [self check:[[DYYYAutoMessageBatch configsByUpdatingText:@"" randomText:NO configs:configs ownerID:@"A" selectedUserIDs:[NSSet setWithObject:@"one"]] isEqual:configs]
        reason:@"空内容不能清空整批消息"];
    [self check:[[DYYYAutoMessageBatch configsByUpdatingText:@"内容" randomText:NO configs:configs ownerID:@"A" selectedUserIDs:[NSSet set]] isEqual:configs]
        reason:@"全不选不能改任何配置"];
    NSLog(@"DYYYAutoMessageBatch regression tests passed");
}
@end
int main(void) {
    @autoreleasepool { [DYYYAutoMessageBatchTests run]; }
    return 0;
}
