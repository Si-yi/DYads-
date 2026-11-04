#import "AwemeHeaders.h"
#import "DYYYChatEnhancements.h"
#import "DYYYChatEnhancementPolicy.h"

%group DYYYChatTypingHooks
%hook AWEIMInputStateManager
- (void)reportInputStateWithText:(id)text {
    if ([DYYYChatEnhancements enabled:@"DYYYDisableInputStateReport"]) return;
    %orig(text);
}
%end
%end
%group DYYYChatOnlineGateHooks
%hook AWEIMActiveUserUploader
- (BOOL)checkEnableServerUploadActiveStatus {
    if ([DYYYChatEnhancements enabled:@"DYYYDisableOnlineUpload"]) return NO;
    return %orig;
}
%end
%end
%group DYYYChatOnlineUpdateHooks
%hook AWEIMActiveUserUploader
- (void)updateUserActiveStatusWithEntrance:(id)entrance context:(id)context {
    if ([DYYYChatEnhancements enabled:@"DYYYDisableOnlineUpload"]) return;
    %orig(entrance, context);
}
%end
%end
%group DYYYChatOnlinePrivateHooks
%hook AWEIMActiveUserUploader
- (void)p_updateUserActiveWithContext:(id)context {
    if ([DYYYChatEnhancements enabled:@"DYYYDisableOnlineUpload"]) return;
    %orig(context);
}
%end
%end
%group DYYYChatCellEnhancementHooks
%hook AWEIMReusableCommonCell
- (void)didMoveToWindow {
    %orig;
    [DYYYChatEnhancements cellChanged:self];
}
%end
%end
%group DYYYChatContextEnhancementHooks
%hook AWEIMReusableCommonCell
- (void)setCurrentContext:(id)context {
    %orig(context);
    [DYYYChatEnhancements cellChanged:self];
}
%end
%end
%group DYYYChatAppearanceEnhancementHooks
%hook AWEIMMessageListViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [DYYYChatEnhancements controllerAppeared:self];
}
%end
%end

// 仅原生阅后即焚的本机展示标记；不拦截普通消息 markAsRead 或任何完成回调。
%group DYYYWatchOnceImageFlagHooks
%hook AWEIMWatchOnceImageMessage
- (BOOL)watchEnd {
    if ([DYYYChatEnhancements enabled:@"DYYYPreventWatchOnceDestroy"]) return NO;
    return %orig;
}
%end
%end
%group DYYYWatchOnceVideoFlagHooks
%hook AWEIMWatchOnceVideoMessage
- (BOOL)watchEnd {
    if ([DYYYChatEnhancements enabled:@"DYYYPreventWatchOnceDestroy"]) return NO;
    return %orig;
}
%end
%end
%group DYYYWatchOnceReadingHooks
%hook AWEIMWatchOnceMessageManager
- (BOOL)isReadingWatchOnceMessage:(id)message {
    if ([DYYYChatEnhancements enabled:@"DYYYPreventWatchOnceDestroy"]) return YES;
    return %orig(message);
}
%end
%end
%group DYYYWatchOnceLoopHooks
%hook AWEIMWatchOnceMessageManager
- (long long)watchOnceMediaLoopTimes {
    if ([DYYYChatEnhancements enabled:@"DYYYPreventWatchOnceDestroy"]) return 1000000;
    return %orig;
}
%end
%end

@implementation DYYYChatEnhancements (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self installHooks]; }); return; }
    static BOOL typing, onlineGate, onlineUpdate, onlinePrivate, cells, context, appearance, image, video, reading, loops;
    Class typingClass = NSClassFromString(@"AWEIMInputStateManager");
    BOOL typingReady = [DYYYChatEnhancementPolicy class:typingClass selector:@selector(reportInputStateWithText:) result:'v' arguments:@"@"];
    [self recordCapability:@"typingReport" available:typingReady];
    if (!typing && [self enabled:@"DYYYDisableInputStateReport"] && typingReady) { %init(DYYYChatTypingHooks); typing = YES; }
    Class uploader = NSClassFromString(@"AWEIMActiveUserUploader");
    BOOL gateReady = [DYYYChatEnhancementPolicy class:uploader selector:@selector(checkEnableServerUploadActiveStatus) result:'B' arguments:@""];
    BOOL updateReady = [DYYYChatEnhancementPolicy class:uploader selector:@selector(updateUserActiveStatusWithEntrance:context:) result:'v' arguments:@"@@"];
    BOOL privateReady = [DYYYChatEnhancementPolicy class:uploader selector:@selector(p_updateUserActiveWithContext:) result:'v' arguments:@"@"];
    [self recordCapability:@"onlineUpload" available:gateReady && updateReady && privateReady];
    if ([self enabled:@"DYYYDisableOnlineUpload"]) {
        if (!onlineGate && gateReady) { %init(DYYYChatOnlineGateHooks); onlineGate = YES; }
        if (!onlineUpdate && updateReady) { %init(DYYYChatOnlineUpdateHooks); onlineUpdate = YES; }
        if (!onlinePrivate && privateReady) { %init(DYYYChatOnlinePrivateHooks); onlinePrivate = YES; }
    }
    Class cellClass = NSClassFromString(@"AWEIMReusableCommonCell");
    BOOL cellReady = [cellClass isSubclassOfClass:UIView.class] && [DYYYChatEnhancementPolicy class:cellClass selector:@selector(didMoveToWindow) result:'v' arguments:@""];
    BOOL contextReady = [DYYYChatEnhancementPolicy class:cellClass selector:@selector(setCurrentContext:) result:'v' arguments:@"@"];
    BOOL appearanceReady = [DYYYChatEnhancementPolicy class:NSClassFromString(@"AWEIMMessageListViewController") selector:@selector(viewDidAppear:) result:'v' arguments:@"B"];
    [self recordCapability:@"chatCellEvents" available:cellReady && contextReady && appearanceReady];
    if ([self enabled:@"DYYYSwipeToQuote"] || [self enabled:@"DYYYAutoTranslateAudio"]) {
        if (!cells && cellReady) { %init(DYYYChatCellEnhancementHooks); cells = YES; }
        if (!context && contextReady) { %init(DYYYChatContextEnhancementHooks); context = YES; }
        if (!appearance && appearanceReady) { %init(DYYYChatAppearanceEnhancementHooks); appearance = YES; }
    }
    Class imageClass = NSClassFromString(@"AWEIMWatchOnceImageMessage"), videoClass = NSClassFromString(@"AWEIMWatchOnceVideoMessage");
    Class watch = NSClassFromString(@"AWEIMWatchOnceMessageManager");
    BOOL imageReady = [DYYYChatEnhancementPolicy class:imageClass selector:@selector(watchEnd) result:'B' arguments:@""];
    BOOL videoReady = [DYYYChatEnhancementPolicy class:videoClass selector:@selector(watchEnd) result:'B' arguments:@""];
    BOOL readingReady = [DYYYChatEnhancementPolicy class:watch selector:@selector(isReadingWatchOnceMessage:) result:'B' arguments:@"@"];
    BOOL loopReady = [DYYYChatEnhancementPolicy class:watch selector:@selector(watchOnceMediaLoopTimes) result:'q' arguments:@""];
    [self recordCapability:@"watchOnceLocalFlags" available:imageReady && videoReady && readingReady && loopReady];
    if ([self enabled:@"DYYYPreventWatchOnceDestroy"]) {
        if (!image && imageReady) { %init(DYYYWatchOnceImageFlagHooks); image = YES; }
        if (!video && videoReady) { %init(DYYYWatchOnceVideoFlagHooks); video = YES; }
        if (!reading && readingReady) { %init(DYYYWatchOnceReadingHooks); reading = YES; }
        if (!loops && loopReady) { %init(DYYYWatchOnceLoopHooks); loops = YES; }
    }
}
@end
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ [DYYYChatEnhancements installHooks]; });
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { [DYYYChatEnhancements installHooks]; }];
}
