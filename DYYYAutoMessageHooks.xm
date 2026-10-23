#import "AwemeHeaders.h"
#import "DYYYAutoMessage.h"
#import "DYYYIMService.h"

// 复用抖音创建并配置好的实例，不自己 new 消息 SDK，也不调用其他插件。
%hook AWEIMUserDBManager
- (id)init {
    id result = %orig;
    [DYYYIMService captureService:result role:@"contacts"];
    return result;
}
%end

%hook TIMXOConversationManager
- (id)initWithRootObject:(id)root {
    id result = %orig;
    [DYYYIMService captureService:result role:@"conversations"];
    return result;
}
%end

%hook IESIMMessageSender
- (id)init {
    id result = %orig;
    [DYYYIMService captureService:result role:@"sender"];
    return result;
}
- (id)sendMessage:(id)model {
    [DYYYIMService observeTextModel:model sender:self];
    return %orig;
}
- (void)asyncSendMessage:(id)model completion:(id)completion {
    [DYYYIMService observeTextModel:model sender:self];
    %orig;
}
- (void)message:(id)message inConversation:(id)conversation didReceiveResponse:(id)response error:(id)error {
    %orig;
    [DYYYIMService observeMessage:message conversation:conversation error:error];
}
- (void)message:(id)message inConversation:(id)conversation didReceiveAsyncResponse:(id)response error:(id)error {
    %orig;
    [DYYYIMService observeMessage:message conversation:conversation error:error];
}
%end

%hook TIMXOMessageManager
- (id)messagesInConversation:(id)conversation excludeMessageTypes:(id)types limit:(unsigned long long)limit {
    [DYYYIMService observeHistoryQuery:conversation manager:self];
    return %orig;
}
%end

%hook AWENormalModeTabBarController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [DYYYAutoMessage runDailyMessageCheckIfNeeded];
    });
}
%end

%ctor {
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [DYYYAutoMessage runDailyMessageCheckIfNeeded];
        });
    }];
}
