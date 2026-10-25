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
    message.messageType = 8;
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
    [emoji setMessageType:7];
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
    // 1.6.6 真机日志：类型 83/105 的评论或引用同样直接携带 itemId。
    // 原先只看 ID 层级的测试没有覆盖这条路径。
    id rootReply = [self message:@"root-reply-83" sender:42 content:@{
        @"itemId": oldVideo, @"refmsg_uid": @7, @"ref_uid": @7,
        @"comment_id": @"reference-comment", @"text": @"👍👍👍", @"comment_content_type": @0
    }];
    [rootReply setMessageType:83];
    id rootComment = [self message:@"root-comment-105" sender:42 content:@{
        @"itemId": oldVideo, @"comment_id": @"reference-comment", @"media_type": @0,
        @"comment": @"🌚🌚🌚", @"comment_content_type": @0, @"aweme_title": @"被引用的视频"
    }];
    [rootComment setMessageType:105];
    for (id context in @[rootReply, rootComment]) {
        [self check:[self ids:context].count == 0 reason:@"评论/引用的顶层视频 ID 也必须拒绝，不能再次误判为直接分享"];
        [self check:[DYYYIMShareParser receiptForUnreadMessage:context peerID:@"42" itemID:oldVideo] == nil
            reason:@"不能给评论/引用生成新版分享凭据"];
        NSDictionary *diagnostic = [DYYYIMShareParser diagnosticsForMessage:context peerID:@"42" accountID:@"7"];
        [self check:[diagnostic[@"classification"] isEqual:@"context_type"] && [diagnostic[@"topLevelVideoCount"] integerValue] == 1 &&
            [diagnostic[@"directVideoCount"] integerValue] == 0 reason:@"诊断必须区分正文带 ID 与真实分享"];
    }
    id unknown = [self message:@"unknown-native-type" sender:42 content:@{ @"itemId": oldVideo }];
    [unknown setMessageType:9999];
    [self check:[self ids:unknown].count == 0 reason:@"未观察过的原生类型不能仅凭 ID 猜成分享"];
    id album = [self message:@"real-album-77" sender:42 content:@{ @"itemId": newVideo, @"awemeType": @68 }];
    [album setMessageType:77];
    [self check:[[self ids:album] isEqual:@[newVideo]] reason:@"现场确认的图文分享类型 77 应继续接收"];
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
    NSMutableDictionary *v1Wrong = [legacy mutableCopy];
    v1Wrong[@"shareValidationVersion"] = @1; v1Wrong[@"shareMessageID"] = @"root-reply-83";
    [self check:![DYYYIMShareParser isCurrentReceipt:v1Wrong] reason:@"1.6.6 的 v1 旧凭据不能继续免检恢复首页"];
    NSDictionary *repairV1 = [DYYYIMShareParser reconcileRows:@[v1Wrong] history:@[rootReply]
        peerID:@"42" accountID:@"7"];
    [self check:[repairV1[@"rejectedRows"] count] == 1 &&
        [repairV1[@"rejectedRows"][0][@"reason"] isEqual:@"non_share_message_receipt"]
        reason:@"找到旧凭据对应的 83 引用消息时必须撤销，不能再被 v1 已验证标记保护"];
    NSDictionary *repairRootLegacy = [DYYYIMShareParser reconcileRows:@[legacy] history:@[outgoing, rootComment]
        peerID:@"42" accountID:@"7"];
    [self check:[repairRootLegacy[@"rejectedRows"] count] == 1 reason:@"更早无凭据的顶层引用也可结合自己发出的原作确认误判"];
    NSMutableDictionary *v1Real = [legacy mutableCopy];
    v1Real[@"shareValidationVersion"] = @1; v1Real[@"shareMessageID"] = @"received-direct";
    NSDictionary *upgrade = [DYYYIMShareParser reconcileRows:@[v1Real] history:@[direct, rootReply] unreadMessages:@[direct]
        peerID:@"42" accountID:@"7"];
    [self check:[upgrade[@"rejectedRows"] count] == 0 && [upgrade[@"verifiedRows"] count] == 1 &&
        [DYYYIMShareParser isCurrentReceipt:upgrade[@"verifiedRows"][0]] reason:@"旧真实视频核实为 8 后升级凭据，再恢复待刷"];
    NSDictionary *historicalOnly = [DYYYIMShareParser reconcileRows:@[v1Real] history:@[direct, outgoing, rootReply]
        unreadMessages:@[] peerID:@"42" accountID:@"7"];
    [self check:[historicalOnly[@"verifiedRows"] count] == 0 && [historicalOnly[@"rejectedRows"] count] == 0
        reason:@"全历史里找到很久前真实分享不能证明它属于未读；旧记录只保留待核实，不能重新回灌首页"];
    NSMutableDictionary *missingUnreadProof = [upgrade[@"verifiedRows"][0] mutableCopy];
    [missingUnreadProof removeObjectForKey:@"shareUnreadValidated"];
    [self check:![DYYYIMShareParser isCurrentReceipt:missingUnreadProof] reason:@"有类型和消息 ID 仍不等于有未读窗口凭据"];
    NSMutableDictionary *v1Unknown = [v1Wrong mutableCopy]; v1Unknown[@"shareMessageID"] = @"unknown-native-type";
    NSDictionary *uncertain = [DYYYIMShareParser reconcileRows:@[v1Unknown] history:@[unknown, outgoing]
        peerID:@"42" accountID:@"7"];
    [self check:[uncertain[@"rejectedRows"] count] == 0 && [uncertain[@"verifiedRows"] count] == 0
        reason:@"未知类型/核实不了的旧记录保留待核实，不能删掉，也不能当成分享放行"];
    NSDictionary *readChatRepair = [DYYYIMShareParser reconcileRows:@[legacy] history:@[outgoing, jsonReply]
        peerID:@"42" accountID:@"7"];
    [self check:[readChatRepair[@"rejectedRows"] count] == 1 reason:@"已读聊天仍能用本地历史核对 JSON 引用，修复不依赖未读状态"];
    NSDictionary *real = [DYYYIMShareParser reconcileRows:@[legacy] history:@[outgoing, emoji, direct] unreadMessages:@[direct]
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
        NSDictionary *genuine = [DYYYIMShareParser receiptForUnreadMessage:shareWithQuote peerID:@"42" itemID:newVideo];
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
        [history mergeRows:@[v1Wrong]];
        NSDictionary *preserved = [history.pendingRows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"itemID == %@", oldVideo]].firstObject;
        [self check:[DYYYIMShareParser isCurrentReceipt:preserved] && [preserved[@"shareMessageID"] isEqual:@"received-direct"]
            reason:@"旧版来源缓存不能把新版真实分享凭据降回 v1 引用"];
        DYYYFriendShareHistory *migration = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"migration"];
        [migration mergeRows:@[v1Wrong]];
        migration = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"migration"];
        [self check:migration.pendingRows.count == 1 && ![DYYYIMShareParser isCurrentReceipt:migration.pendingRows.firstObject]
            reason:@"核实前旧记录应跨重启保留，但不能免检入队"];
        [self check:[migration discardUnverifiedRows:repairV1[@"rejectedRows"]].count == 1 && migration.watchedItemIDs.count == 0
            reason:@"v1 错误凭据应真正从持久待刷撤销，不冒记已刷"];
        [migration mergeRows:@[v1Real]];
        [migration mergeRows:upgrade[@"verifiedRows"]];
        migration = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"migration"];
        [self check:[DYYYIMShareParser isCurrentReceipt:migration.pendingRows.firstObject] &&
            [migration.pendingRows.firstObject[@"shareMessageType"] integerValue] == 8
            reason:@"核实后的版本、类型、消息凭据必须一起保存，重启后可直接续推"];
        NSDictionary *afterRead = [DYYYIMShareParser reconcileRows:migration.pendingRows history:@[outgoing, rootReply]
            unreadMessages:@[] peerID:@"42" accountID:@"7"];
        [migration discardUnverifiedRows:afterRead[@"rejectedRows"]];
        [self check:migration.pendingRows.count == 1 && [DYYYIMShareParser isCurrentReceipt:migration.pendingRows.firstObject]
            reason:@"新版已验证但首页未刷的分享，不会因为聊天已读而被撤销，必须继续跨启动续推"];
        DYYYFriendShareHistory *oldCache = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"old-read-cache"];
        [oldCache mergeRows:@[v1Real]];
        [oldCache mergeRows:historicalOnly[@"verifiedRows"]];
        oldCache = [[DYYYFriendShareHistory alloc] initWithDefaults:defaults account:@"old-read-cache"];
        [self check:oldCache.pendingRows.count == 1 && ![DYYYIMShareParser isCurrentReceipt:oldCache.pendingRows.firstObject]
            reason:@"历史核对不能把旧已读缓存洗成新版免检凭据，重启后也必须继续暂存而非推送"];
    } @finally { [defaults removePersistentDomainForName:suite]; }
    NSLog(@"DYYYIMShareParser regression tests passed");
}
@end
int main(void) {
    @autoreleasepool { [DYYYIMShareParserTests run]; }
    return 0;
}
