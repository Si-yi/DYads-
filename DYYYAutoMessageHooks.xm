#import "AwemeHeaders.h"
#import "DYYYAutoMessage.h"
#import "DYYYIMService.h"
#import "DYYYFriendShareService.h"
#import "DYYYFriendShareBadgeView.h"
#import "DYYYChatVideoLayout.h"
#import "DYYYUtils.h"

%hook AWEPlayInteractionViewController
- (void)setModel:(AWEAwemeModel *)model {
    [DYYYFriendShareBadgeView resetForController:self];
    %orig(model);
}
- (void)viewDidLayoutSubviews {
    %orig;
    [DYYYChatVideoLayout layoutInteractionController:self];
    [DYYYFriendShareBadgeView updateForController:self];
}
%end

%hook AWEElementStackView
- (void)layoutSubviews {
    %orig;
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYFriendShareFeedEnabled"]) return;
    UIViewController *controller = [DYYYUtils firstAvailableViewControllerFromView:self];
    if ([controller isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) [DYYYFriendShareBadgeView updateForController:controller];
}
%end

// 复用抖音创建并配置好的实例，不自己 new 消息 SDK，也不调用其他插件。
%hook AWEIMUserDBManager
- (id)init {
    id result = %orig;
    [DYYYIMService captureService:result role:@"contacts"];
    return result;
}
%end

%hook AWEFeedTableViewController
- (void)viewDidLoad {
    %orig;
    [DYYYFriendShareService bindHomeFeed:self];
}
- (void)setDataController:(id)controller {
    %orig(controller);
    __weak UIViewController *weakFeed = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYFriendShareService bindHomeFeed:weakFeed]; });
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [DYYYFriendShareService bindHomeFeed:self];
}
- (void)viewWillDisappear:(BOOL)animated {
    [DYYYFriendShareService homeDidLeave:self];
    %orig;
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    [DYYYFriendShareService homeDidEndScrolling:self scrollView:scrollView];
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [DYYYFriendShareService homeWillDrag:self scrollView:scrollView];
    %orig;
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!decelerate) [DYYYFriendShareService homeDidEndScrolling:self scrollView:scrollView];
}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    %orig;
    [DYYYFriendShareService homeDidEndScrolling:self scrollView:scrollView];
}
- (void)videoPlayer:(id)player didSingleClick:(id)event {
    [DYYYFriendShareService homePlaybackTouched:self];
    %orig(player, event);
}
- (void)videoPlayer:(id)player updatePlayTime:(double)time totalTime:(double)total {
    %orig(player, time, total);
    [DYYYFriendShareService homePlaybackAdvanced:self time:time];
}
- (void)videoControllerWillStartNextLoop:(id)controller {
    [DYYYFriendShareService homeWillLoop:self];
    %orig;
}
- (void)pi_scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [DYYYFriendShareService homeWillDrag:self scrollView:scrollView];
    %orig;
}
- (void)pi_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!decelerate) [DYYYFriendShareService homeDidEndScrolling:self scrollView:scrollView];
}
%end

%hook AWEDPlayerViewController_Merge
- (void)player:(id)player updatePlayTime:(double)time canPlayTime:(double)buffered totalTime:(double)total {
    [DYYYFriendShareService playerPlaybackAdvanced:self time:time];
    %orig(player, time, buffered, total);
}
- (void)playerWillStartNextLoop:(id)player {
    [DYYYFriendShareService playerWillLoop:self];
    %orig;
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

%hook TIMXOConversation
- (id)sendMessage:(id)model error:(void *)error {
    [DYYYIMService observeConversationSend:model conversation:self];
    return %orig;
}
- (id)sendMessage:(id)model isSaveDB:(BOOL)saveDB error:(void *)error {
    [DYYYIMService observeConversationSend:model conversation:self];
    return %orig;
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
    id result = %orig;
    [DYYYIMService observeHistoryResults:result manager:self];
    return result;
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

