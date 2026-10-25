#import <Foundation/Foundation.h>
#import "DYYYIMShareParser.h"
#import "DYYYFriendShareHistory.h"

@interface DYYYShareTestMessage : NSObject
@property (nonatomic, assign) long long sender;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) id content;
@property (nonatomic, assign) long long messageType;
@end
@implementation DYYYShareTestMessage
@end

@interface DYYYIMShareParserTests : NSObject
+ (void)run;
@end
@implementation DYYYIMShareParserTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (DYYYShareTestMessage *)message:(NSString *)identifier sender:(long long)sender content:(id)content {
    DYYYShareTestMessage *message = [DYYYShareTestMessage new];
    message.identifier = identifier; message.sender = sender; message.content = content;
    return message;
}
+ (NSArray *)ids:(id)message {
    return [DYYYIMShareParser directItemIDsForMessage:message peerID:@"42" accountID:@"7"];
}
+ (void)run {
    NSString *oldVideo = @"7699342516063067475", *newVideo = @"7700177534259955638";
    id outgoing = [self message:@"sent-original" sender:7 content:@{ @"itemId": oldVideo }];
    id emoji = [self message:@"emoji-reply" sender:42 content:@{
        @"text": @"🌚🌚🌚", @"refer_message": @{ @"sender": @7, @"content": @{ @"itemId": oldVideo } }
    }];
    [self check:[self ids:outgoing].count == 0 reason:@"自己发出的视频不能冒充好友分享"];
    [self check:[self ids:emoji].count == 0 reason:@"好友引用自己发出的视频并回复表情，不能入队引用卡片"];
    for (NSString *key in @[ @"refer_message", @"quote", @"reply", @"reaction", @"extra", @"data", @"card" ]) {
        id reply = [self message:@"nested" sender:42 content:@{key: @{ @"aweme_id": oldVideo }}];
        [self check:[self ids:reply].count == 0 reason:@"引用/回应/扩展/卡片中的 ID 均不能当作当前分享"];
    }
    id jsonReply = [self message:@"json-reply" sender:42 content:@{
        @"ref": [NSString stringWithFormat:@"{\"content\":{\"item_id\":\"%@\"}}", oldVideo]
    }];
    [self check:[self ids:jsonReply].count == 0 reason:@"JSON 字符串内的引用也不能被递归捞入首页"];
    id direct = [self message:@"received-direct" sender:42 content:@{ @"item_id": oldVideo }];
    [self check:[[self ids:direct] isEqual:@[oldVideo]] reason:@"好友真正直接分享仍需保留"];
    id shareWithQuote = [self message:@"new-with-reference" sender:42 content:@{
        @"awemeId": newVideo, @"refer_message": @{ @"content": @{ @"itemId": oldVideo } }
    }];
    [self check:[[self ids:shareWithQuote] isEqual:@[newVideo]] reason:@"分享新视频同时带引用时只取新视频，不能一刀切拒绝回复消息"];
    id other = [self message:@"foreign" sender:84 content:@{ @"item_id": oldVideo }];
    [self check:[self ids:other].count == 0 reason:@"其他好友不能串入当前会话来源"];
    [self check:[DYYYIMShareParser directItemIDsForMessage:direct peerID:@"42" accountID:@"42"].count == 0 reason:@"本账户不得作为好友来源"];
    id encoded = [self message:@"json-direct" sender:42 content:[NSString stringWithFormat:@"{\"aweme_id\":\"%@\"}", oldVideo]];
    [self check:[[self ids:encoded] isEqual:@[oldVideo]] reason:@"消息正文为 JSON 时只解码最外层"];
    for (id bad in @[NSNull.null, @"not-json", @[], @{ @"item_id": @"not-a-video" }, @{ @"item_id": @"１２３４５６７８" },
                     @{ @"item_id": oldVideo, @"aweme_id": newVideo }]) {
        [self check:[self ids:[self message:@"invalid" sender:42 content:bad]].count == 0 reason:@"未知正文、非法 ID 或互相冲突的直接字段必须拒绝"];
    }
    id numeric = [self message:@"numeric" sender:42 content:@{ @"itemId": @7699342516063067475LL }];
    [self check:[[self ids:numeric] isEqual:@[oldVideo]] reason:@"原生数字 ID 不能损失精度"];
    NSDictionary *legacy = @{ @"itemID": oldVideo, @"friendID": @"42", @"collectedAt": @1 };
    NSDictionary *repair = [DYYYIMShareParser reconcileRows:@[legacy] history:@[outgoing, emoji]
        peerID:@"42" accountID:@"7"];
    [self check:[repair[@"rejectedRows"] count] == 1 && [repair[@"verifiedRows"] count] == 0
        reason:@"同时确认自己发出与好友引用时，应撤销旧版误判"];
    NSDictionary *readChatRepair = [DYYYIMShareParser reconcileRows:@[legacy] history:@[outgoing, jsonReply]
        peerID:@"42" accountID:@"7"];
    [self check:[readChatRepair[@"rejectedRows"] count] == 1 reason:@"已读聊天仍能用本地历史核对 JSON 引用，修复不依赖未读状态"];
    NSDictionary *real = [DYYYIMShareParser reconcileRows:@[legacy] history:@[outgoing, emoji, direct]
        peerID:@"42" accountID:@"7"];
    [self check:[real[@"rejectedRows"] count] == 0 && [real[@"verifiedRows"] count] == 1
        reason:@"同视频好友也曾真正分享时保留待刷，并保存直接消息凭据"];
    for (NSArray *incomplete in @[ @[], @[outgoing], @[emoji] ]) {
        NSDictionary *result = [DYYYIMShareParser reconcileRows:@[legacy] history:incomplete peerID:@"42" accountID:@"7"];
        [self check:[result[@"rejectedRows"] count] == 0 reason:@"查不到或证据不足必须保留旧待刷，不能清空用户未看视频"];
    }
    NSString *suite = [@"com.dyyy.share-parser." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    @try {
        DYYYFriendShareHistory *history = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"7"];
        NSDictionary *genuine = [DYYYIMShareParser receiptForMessage:shareWithQuote peerID:@"42" itemID:newVideo];
        [history mergeRows:@[legacy, genuine]];
        [self check:[history discardUnverifiedRows:repair[@"rejectedRows"]].count == 1 reason:@"旧误推应从持久待刷中撤销"];
        [self check:history.watchedItemIDs.count == 0 && history.pendingRows.count == 1 reason:@"撤销误推不是已刷，不能损坏真实待刷"];
        [history discardUnverifiedRows:@[ @{ @"itemID": newVideo, @"friendID": @"42" } ]];
        [self check:history.pendingRows.count == 1 reason:@"已有直接凭据的分享不能被旧缓存修复误删"];
        history = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"7"];
        [self check:[history.pendingRows.firstObject[@"shareMessageID"] isEqual:@"new-with-reference"] reason:@"直接消息凭据必须跨启动保存"];
        [history mergeRows:@[legacy]];
        [history discardUnverifiedRows:@[ @{ @"itemID": oldVideo, @"friendID": @"84" } ]];
        [self check:history.pendingRows.count == 2 reason:@"同视频其他好友的错误来源不能撤销当前好友的待刷"];
        DYYYFriendShareHistory *otherAccount = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"8"];
        [self check:otherAccount.pendingRows.count == 0 reason:@"清理和凭据都必须按账户隔离"];
        [history mergeRows:real[@"verifiedRows"]];
        [history discardUnverifiedRows:repair[@"rejectedRows"]];
        [self check:history.pendingRows.count == 2 reason:@"旧待刷核实为真实分享后不得被随后旧误判回调删除"];
    } @finally { [defaults removePersistentDomainForName:suite]; }
    NSLog(@"DYYYIMShareParser regression tests passed");
}
@end
int main(void) {
    @autoreleasepool { [DYYYIMShareParserTests run]; }
    return 0;
}
