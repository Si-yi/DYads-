#import "AwemeHeaders.h"
#import "DYYYUnreadExpiry.h"

%group DYYYExpiryConversationHooks
%hook TIMXOConversation
- (void)markAllMessagesBeforeMessage:(id)message asReadWithMode:(unsigned long long)mode completion:(id)completion {
    %orig(message, mode, completion);
    [DYYYUnreadExpiry learnConversation:self receiver:self mode:mode completion:completion];
}
%end
%end
%group DYYYExpiryManagerHooks
%hook IESIMConversationDataManager
- (void)markAllMessagesBeforeMessage:(id)message asReadWithMode:(unsigned long long)mode ofConversation:(id)conversation completion:(id)completion {
    %orig(message, mode, conversation, completion);
    [DYYYUnreadExpiry learnConversation:conversation receiver:self mode:mode completion:completion];
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
    if (!NSThread.isMainThread || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYUnreadExpiryEnabled"]) return;
    static BOOL conversation, manager, hints, list, total;
    if (!conversation && [self matchesClass:NSClassFromString(@"TIMXOConversation") selector:@selector(markAllMessagesBeforeMessage:asReadWithMode:completion:) arguments:@"@Q@"]) {
        %init(DYYYExpiryConversationHooks); conversation = YES;
    }
    if (!manager && [self matchesClass:NSClassFromString(@"IESIMConversationDataManager") selector:@selector(markAllMessagesBeforeMessage:asReadWithMode:ofConversation:completion:) arguments:@"@Q@@"]) {
        %init(DYYYExpiryManagerHooks); manager = YES;
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
}
@end
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYUnreadExpiry installHooks]; });
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        [DYYYUnreadExpiry installHooks]; [DYYYUnreadExpiry schedule];
    }];
}
