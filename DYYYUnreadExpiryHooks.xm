#import "AwemeHeaders.h"
#import "DYYYUnreadExpiry.h"

%group DYYYExpiryConversationHooks
%hook TIMXOConversation
- (void)markAllMessagesBeforeMessage:(id)message asReadWithMode:(unsigned long long)mode completion:(id)completion {
    %orig(message, mode, completion);
    [DYYYUnreadExpiry observeReadOperation:@"conversation_boundary" count:0];
    [DYYYUnreadExpiry learnConversation:self receiver:self message:message mode:mode completion:completion];
}
%end
%end
%group DYYYExpiryManagerHooks
%hook IESIMConversationDataManager
- (void)markAllMessagesBeforeMessage:(id)message asReadWithMode:(unsigned long long)mode ofConversation:(id)conversation completion:(id)completion {
    %orig(message, mode, conversation, completion);
    [DYYYUnreadExpiry observeReadOperation:@"manager_boundary" count:0];
    [DYYYUnreadExpiry learnConversation:conversation receiver:self message:message mode:mode completion:completion];
}
%end
%end
// 以下接口只计数原生自然调用，绝不主动调用，更不把全会话接口的 mode 用到边界接口。
%group DYYYExpiryConversationAllReadHooks
%hook TIMXOConversation
- (void)markAllMessagesAsReadWithMode:(unsigned long long)mode completion:(id)completion {
    %orig(mode, completion);
    [DYYYUnreadExpiry observeReadOperation:@"conversation_all_read" count:0];
}
%end
%end
%group DYYYExpiryManagerAllReadHooks
%hook IESIMConversationDataManager
- (void)markAllMessagesAsReadWithMode:(unsigned long long)mode ofConversation:(id)conversation completion:(id)completion {
    %orig(mode, conversation, completion);
    [DYYYUnreadExpiry observeReadOperation:@"manager_all_read" count:0];
}
%end
%end
%group DYYYExpiryNativeMarkUnreadHooks
%hook TIMXOConversation
- (void)markAsUnreadWithMode:(unsigned long long)mode unreadCount:(long long)count completion:(id)completion {
    %orig(mode, count, completion);
    [DYYYUnreadExpiry observeReadOperation:@"conversation_mark_unread" count:count > 0 ? (unsigned long long)count : 0];
}
%end
%end

%group DYYYExpiryHintHooks
%hook TIMXOMessageManager
- (void)asyncGetUnreadMessagesForHintType:(long long)hint inConversation:(id)conversation limit:(unsigned long long)limit completion:(id)completion {
    %orig(hint, conversation, limit, completion);
    [DYYYUnreadExpiry observeHintType:hint manager:self];
}
%end
%end
%group DYYYExpiryChatListHooks
%hook AWEIMChatListViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [DYYYUnreadExpiry schedule];
}
%end
%end
%group DYYYExpiryTotalHooks
%hook AWEIMGeneralTotalUnreadCountObserver
- (void)unreadCountForUser:(long long)user changeTo:(int)count cidToUnreadCountDict:(id)counts {
    %orig(user, count, counts);
    [DYYYUnreadExpiry schedule];
}
- (void)unreadCountForUser:(long long)user changeTo:(int)count cidToUnreadCountDict:(id)counts boxType:(int)box {
    %orig(user, count, counts, box);
    [DYYYUnreadExpiry schedule];
}
%end
%end

@implementation DYYYUnreadExpiry (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) return;
    static BOOL conversation, manager, allConversation, allManager, markUnread, hints, list, total;
    if (!conversation && [self matchesClass:NSClassFromString(@"TIMXOConversation") selector:@selector(markAllMessagesBeforeMessage:asReadWithMode:completion:) arguments:@"@Q@"]) {
        %init(DYYYExpiryConversationHooks); conversation = YES;
    }
    if (!manager && [self matchesClass:NSClassFromString(@"IESIMConversationDataManager") selector:@selector(markAllMessagesBeforeMessage:asReadWithMode:ofConversation:completion:) arguments:@"@Q@@"]) {
        %init(DYYYExpiryManagerHooks); manager = YES;
    }
    if (!allConversation && [self matchesClass:NSClassFromString(@"TIMXOConversation") selector:@selector(markAllMessagesAsReadWithMode:completion:) arguments:@"Q@"]) {
        %init(DYYYExpiryConversationAllReadHooks); allConversation = YES;
    }
    if (!allManager && [self matchesClass:NSClassFromString(@"IESIMConversationDataManager") selector:@selector(markAllMessagesAsReadWithMode:ofConversation:completion:) arguments:@"Q@@"]) {
        %init(DYYYExpiryManagerAllReadHooks); allManager = YES;
    }
    if (!markUnread && [self matchesClass:NSClassFromString(@"TIMXOConversation") selector:@selector(markAsUnreadWithMode:unreadCount:completion:) arguments:@"Qq@"]) {
        %init(DYYYExpiryNativeMarkUnreadHooks); markUnread = YES;
    }
    if (!hints && [self matchesClass:NSClassFromString(@"TIMXOMessageManager") selector:@selector(asyncGetUnreadMessagesForHintType:inConversation:limit:completion:) arguments:@"q@Q@"]) {
        %init(DYYYExpiryHintHooks); hints = YES;
    }
    if (!list && NSClassFromString(@"AWEIMChatListViewController")) { %init(DYYYExpiryChatListHooks); list = YES; }
    Class observer = NSClassFromString(@"AWEIMGeneralTotalUnreadCountObserver");
    if (!total && [self matchesClass:observer selector:@selector(unreadCountForUser:changeTo:cidToUnreadCountDict:) arguments:@"qi@"] &&
        [self matchesClass:observer selector:@selector(unreadCountForUser:changeTo:cidToUnreadCountDict:boxType:) arguments:@"qi@i"]) {
        %init(DYYYExpiryTotalHooks); total = YES;
    }
    [self recordHookState:@{@"conversationBoundary": @(conversation), @"managerBoundary": @(manager),
        @"conversationAllRead": @(allConversation), @"managerAllRead": @(allManager), @"markUnread": @(markUnread),
        @"hints": @(hints), @"list": @(list), @"total": @(total)}];
}
@end
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYUnreadExpiry installHooks]; });
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        [DYYYUnreadExpiry installHooks]; [DYYYUnreadExpiry schedule];
    }];
}
