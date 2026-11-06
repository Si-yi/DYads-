#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import "DYYYRecallCoordinator.h"
#import "DYYYChatEnhancementPolicy.h"

%group DYYYRecallInitHooks
%hook TIMXOMessage
- (id)initWithRootObject:(id)root model:(id)model {
    id result=%orig(root,model);
    [DYYYRecallCoordinator bindModel:result root:root];
    return result;
}
%end
%end
%group DYYYRecallIdentityInitHooks
%hook TIMXOMessage
- (id)initWithRootObject:(id)root identifier:(id)identifier { id result=%orig(root,identifier);[DYYYRecallCoordinator bindModel:result root:root];return result; }
%end
%end
%group DYYYRecallEmptyInitHooks
%hook TIMXOMessage
- (id)initEmptyNoCacheInstanceWithRootObject:(id)root { id result=%orig(root);[DYYYRecallCoordinator bindModel:result root:root];return result; }
%end
%end
%group DYYYRecallCacheFactoryHooks
%hook TIMXOMessage
+ (id)cachedInstanceWithRootObject:(id)root identifier:(id)identifier { id result=%orig(root,identifier);[DYYYRecallCoordinator bindModel:result root:root];return result; }
%end
%end
%group DYYYRecallFactoryHooks
%hook TIMXOMessage
+ (id)instanceWithRootObject:(id)root identifier:(id)identifier inConversation:(id)conversation { id result=%orig(root,identifier,conversation);[DYYYRecallCoordinator bindModel:result root:root];return result; }
%end
%end
%group DYYYRecallContentHooks
%hook TIMXOMessage
- (void)setContent:(id)content {
    [DYYYRecallCoordinator captureContent:content model:self];
    NSDictionary *retained=[DYYYRecallCoordinator protectedContentForModel:self];
    %orig(retained?:content);
}
- (id)content {
    NSDictionary *retained=[DYYYRecallCoordinator protectedContentForModel:self];
    return retained?:%orig;
}
%end
%end
%group DYYYRecallFlagHooks
%hook TIMXOMessage
- (void)setRecalled:(BOOL)recalled {
    [DYYYRecallCoordinator observeRecalled:recalled model:self];
    %orig(recalled && ![DYYYRecallCoordinator protectModel:self]);
}
- (BOOL)recalled {
    if([DYYYRecallCoordinator protectModel:self])return NO;
    BOOL result=%orig;
    if(result)[DYYYRecallCoordinator observeRecalled:YES model:self];
    return result;
}
%end
%end
%group DYYYRecallOriginalContentHooks
%hook TIMXOMessage
- (void)setRecalledContent:(id)content {
    [DYYYRecallCoordinator captureContent:content model:self];
    %orig(content);
}
%end
%end
%group DYYYRecallDownloadHooks
%hook TIMXOMessage
- (void)setFileDownloadProgressPercentage:(int)percentage {
    %orig(percentage);
    if(percentage==100)[DYYYRecallCoordinator mediaDownloadCompleted:self];
}
%end
%end
%group DYYYRecallUIFactoryHooks
%hook AWEIMMessage
+ (id)messageWithContext:(id)context { return [DYYYRecallCoordinator replacementForUIMessage:%orig(context)]; }
+ (id)createMessageWithContext:(id)context { return [DYYYRecallCoordinator replacementForUIMessage:%orig(context)]; }
%end
%end
%group DYYYRecallUIFileHooks
%hook AWEIMMessage
- (id)filePath { return [DYYYRecallCoordinator mediaPathForUIMessage:self original:%orig]; }
- (id)awe_filePathDictionary { return [DYYYRecallCoordinator mediaPathsForUIMessage:self original:%orig]; }
%end
%end
%group DYYYRecallCellHooks
%hook AWEIMReusableCommonCell
- (void)setCurrentContext:(id)context { [DYYYRecallCoordinator resetCell:self]; %orig(context); [DYYYRecallCoordinator captureCell:self]; }
- (void)didMoveToWindow { %orig; [DYYYRecallCoordinator captureCell:self]; }
- (void)layoutSubviews { %orig; [DYYYRecallCoordinator captureCell:self]; }
- (void)prepareForReuse { [DYYYRecallCoordinator resetCell:self]; %orig; }
%end
%end
%group DYYYRecallListHooks
%hook AWEIMMessageListViewController
- (void)viewDidAppear:(BOOL)animated { %orig(animated); [DYYYRecallCoordinator controllerAppeared:self]; }
%end
%end

@implementation DYYYRecallCoordinator (Hooks)
+ (void)installHooks {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self installHooks];});return;}
    static BOOL init,identityInit,emptyInit,cacheFactory,messageFactory,content,flag,original,download,factory,files,cells,list;
    Class sdk=NSClassFromString(@"TIMXOMessage"),ui=NSClassFromString(@"AWEIMMessage"),cell=NSClassFromString(@"AWEIMReusableCommonCell");
    BOOL initReady=[DYYYChatEnhancementPolicy class:sdk selector:@selector(initWithRootObject:model:) result:'@' arguments:@"@@"];
    BOOL contentReady=[DYYYChatEnhancementPolicy class:sdk selector:@selector(setContent:) result:'v' arguments:@"@"] && [DYYYChatEnhancementPolicy class:sdk selector:@selector(content) result:'@' arguments:@""];
    BOOL flagReady=[DYYYChatEnhancementPolicy class:sdk selector:@selector(setRecalled:) result:'v' arguments:@"B"] && [DYYYChatEnhancementPolicy class:sdk selector:@selector(recalled) result:'B' arguments:@""];
    [self recordHook:@"nativeInterfacesAvailable" installed:initReady && contentReady && flagReady];
    if([self enabled]){
        if(!init && initReady){%init(DYYYRecallInitHooks);init=YES;}
        if(!identityInit && [DYYYChatEnhancementPolicy class:sdk selector:@selector(initWithRootObject:identifier:) result:'@' arguments:@"@@"]){%init(DYYYRecallIdentityInitHooks);identityInit=YES;}
        if(!emptyInit && [DYYYChatEnhancementPolicy class:sdk selector:@selector(initEmptyNoCacheInstanceWithRootObject:) result:'@' arguments:@"@"]){%init(DYYYRecallEmptyInitHooks);emptyInit=YES;}
        if(!cacheFactory && [DYYYChatEnhancementPolicy class:object_getClass(sdk) selector:@selector(cachedInstanceWithRootObject:identifier:) result:'@' arguments:@"@@"]){%init(DYYYRecallCacheFactoryHooks);cacheFactory=YES;}
        if(!messageFactory && [DYYYChatEnhancementPolicy class:object_getClass(sdk) selector:@selector(instanceWithRootObject:identifier:inConversation:) result:'@' arguments:@"@@@"]){%init(DYYYRecallFactoryHooks);messageFactory=YES;}
        if(!content && contentReady){%init(DYYYRecallContentHooks);content=YES;}
        if(!flag && flagReady){%init(DYYYRecallFlagHooks);flag=YES;}
        if(!original && [DYYYChatEnhancementPolicy class:sdk selector:@selector(setRecalledContent:) result:'v' arguments:@"@"]){%init(DYYYRecallOriginalContentHooks);original=YES;}
        if(!download && [DYYYChatEnhancementPolicy class:sdk selector:@selector(setFileDownloadProgressPercentage:) result:'v' arguments:@"i"]){%init(DYYYRecallDownloadHooks);download=YES;}
        if(!factory && [DYYYChatEnhancementPolicy class:object_getClass(ui) selector:@selector(messageWithContext:) result:'@' arguments:@"@"] && [DYYYChatEnhancementPolicy class:object_getClass(ui) selector:@selector(createMessageWithContext:) result:'@' arguments:@"@"]){%init(DYYYRecallUIFactoryHooks);factory=YES;}
        if(!files && [DYYYChatEnhancementPolicy class:ui selector:@selector(filePath) result:'@' arguments:@""] && [DYYYChatEnhancementPolicy class:ui selector:@selector(awe_filePathDictionary) result:'@' arguments:@""]){%init(DYYYRecallUIFileHooks);files=YES;}
        if(!cells && [cell isSubclassOfClass:UITableViewCell.class] && [DYYYChatEnhancementPolicy class:cell selector:@selector(setCurrentContext:) result:'v' arguments:@"@"]){%init(DYYYRecallCellHooks);cells=YES;}
        if(!list && [DYYYChatEnhancementPolicy class:NSClassFromString(@"AWEIMMessageListViewController") selector:@selector(viewDidAppear:) result:'v' arguments:@"B"]){%init(DYYYRecallListHooks);list=YES;}
    }
    [self recordHook:@"nativeInit" installed:init || identityInit || emptyInit];[self recordHook:@"nativeFactories" installed:cacheFactory && messageFactory];[self recordHook:@"content" installed:content];[self recordHook:@"recallFlag" installed:flag];[self recordHook:@"originalContent" installed:original];[self recordHook:@"uiFactory" installed:factory];[self recordHook:@"mediaPaths" installed:files];[self recordHook:@"downloadCompletion" installed:download];[self recordHook:@"cells" installed:cells];
}
@end
%ctor {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"DYYYRecallShowMarker":@YES,@"DYYYRecallKeepMedia":@YES}];
    dispatch_async(dispatch_get_main_queue(),^{[DYYYRecallCoordinator settingsChanged];});
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){[DYYYRecallCoordinator installHooks];}];
}
