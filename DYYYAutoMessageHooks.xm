#import "AwemeHeaders.h"
#import "DYYYAutoMessage.h"
#import "DYYYIMService.h"
#import "DYYYFriendShareService.h"

// 复用抖音创建并配置好的实例，不自己 new 消息 SDK，也不调用其他插件。
%hook AWEIMUserDBManager
- (id)init {
    id result = %orig;
    [DYYYIMService captureService:result role:@"contacts"];
    return result;
}
%end

%hook AWEFeedTableViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [DYYYFriendShareService bindHomeFeed:self];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    [DYYYFriendShareService homeDidScroll:self];
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    %orig;
    [DYYYFriendShareService homeWillDrag:self];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!decelerate) [DYYYFriendShareService homeDidScroll:self];
}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    %orig;
    [DYYYFriendShareService homeDidScroll:self];
}
- (void)videoControllerWillStartNextLoop:(id)controller {
    %orig;
    [DYYYFriendShareService homeWillLoop:self];
}
%end

%hook AWEListDataController
- (void)setDataSource:(NSMutableArray *)data {
    NSArray *ordered = [DYYYFriendShareService arrangeData:data controller:self];
    %orig(ordered == data ? data : [ordered mutableCopy]);
}
%end

%hook AWEHotListDataController
- (id)_refreshDataSourceWithArray:(id)data cleanRefresh:(BOOL)clean requestId:(id)requestID {
    NSArray *ordered = [DYYYFriendShareService arrangeData:data controller:self];
    return %orig(ordered, clean, requestID);
}
- (void)updateAwemeList:(id)data {
    NSArray *ordered = [DYYYFriendShareService arrangeData:data controller:self];
    %orig(ordered);
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
- (id)initWithRootObject:(id)root {
    id result = %orig;
    [DYYYIMService captureService:result role:@"messages"];
    return result;
}
- (id)messagesInConversation:(id)conversation excludeMessageTypes:(id)types limit:(unsigned long long)limit {
    [DYYYIMService observeHistoryQuery:conversation manager:self];
    return %orig;
}
%end

// 自动消息仅由前台通知调度，不在切页和返回设置时重复执行。

%ctor {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults boolForKey:@"DYYYFriendShareLaunchRefreshConfigured"]) {
        [defaults setBool:YES forKey:@"DYYYFriendShareAutoRefreshEnabled"];
        [defaults setBool:YES forKey:@"DYYYFriendShareLaunchRefreshConfigured"];
    }
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        [DYYYFriendShareService applicationBecameActive];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [DYYYAutoMessage runDailyMessageCheckIfNeeded];
        });
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        [DYYYFriendShareService applicationEnteredBackground];
    }];
}

