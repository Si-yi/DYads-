#import "DYYYUnreadExpiry.h"
#import "DYYYUnreadExpiryPolicy.h"
#import "DYYYIMService.h"
#import "DYYYIMConversationStore.h"
#import "DYYYIMHistoryReader.h"
#import "DYYYSettingsHelper.h"
#import "DYYYToast.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#include <math.h>

@interface DYYYExpiryStyle : NSObject
@property (nonatomic, weak) id receiver;
@property (nonatomic) unsigned long long mode;
@property (nonatomic, copy) NSString *shape;
@property (nonatomic) BOOL direct;
@end
@implementation DYYYExpiryStyle
@end
@interface DYYYExpiryScope : NSObject
@property (nonatomic, strong) DYYYExpiryStyle *style;
@property (nonatomic, strong) NSMutableOrderedSet *hints;
@end
@implementation DYYYExpiryScope
- (instancetype)init { if ((self = [super init])) _hints = [NSMutableOrderedSet orderedSet]; return self; }
@end
@interface DYYYUnreadExpiry ()
@property (nonatomic, strong) NSMapTable *scopes;
@property (nonatomic, strong) NSMutableDictionary *scanned;
@property (nonatomic, strong) NSMutableSet *attempted;
@property (nonatomic, strong) NSHashTable *statusItems;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) NSUInteger submissions;
@property (nonatomic) NSUInteger callbacks;
@property (nonatomic) NSUInteger pendingQueries;
@property (nonatomic) NSUInteger pendingWrites;
@property (nonatomic) NSUInteger checked;
@property (nonatomic) NSUInteger skippedUnverified;
@property (nonatomic) BOOL scheduled;
@property (nonatomic) BOOL busy;
@property (nonatomic) BOOL requested;
@property (nonatomic, copy) NSString *status;
@end

@implementation DYYYUnreadExpiry
+ (instancetype)shared {
    static DYYYUnreadExpiry *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [DYYYUnreadExpiry new];
        instance.scopes = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsOpaquePersonality valueOptions:NSPointerFunctionsStrongMemory];
        instance.scanned = [NSMutableDictionary dictionary]; instance.attempted = [NSMutableSet set];
        instance.statusItems = [NSHashTable weakObjectsHashTable]; instance.status = @"尚未处理";
    });
    return instance;
}
+ (NSNumber *)days {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return [defaults boolForKey:@"DYYYUnreadExpiryEnabled"] ? [DYYYUnreadExpiryPolicy daysFromText:[defaults objectForKey:@"DYYYUnreadExpiryDays"]] : nil;
}
+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *exception) { return nil; }
}
+ (DYYYExpiryScope *)scope:(id)root {
    DYYYExpiryScope *scope = [[self shared].scopes objectForKey:root];
    if (!scope && root) {
        scope = [DYYYExpiryScope new]; [[self shared].scopes setObject:scope forKey:root];
        NSDictionary *context = [DYYYIMService capturedExpiryContext:nil];
        if (context[@"root"] == root) {
            NSDictionary *cache = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"DYYYUnreadExpiryNativeStyles"];
            id entry = cache[[self cacheKey:context]];
            if ([entry isKindOfClass:NSDictionary.class]) {
                if ([entry[@"mode"] isKindOfClass:NSNumber.class] && [@[@"nil", @"void", @"object", @"objects"] containsObject:entry[@"shape"]] &&
                    [self matchesClass:NSClassFromString(@"TIMXOConversation") selector:@selector(markAllMessagesBeforeMessage:asReadWithMode:completion:) arguments:@"@Q@"]) {
                    DYYYExpiryStyle *style = [DYYYExpiryStyle new]; style.direct = YES;
                    style.mode = [entry[@"mode"] unsignedLongLongValue]; style.shape = entry[@"shape"]; scope.style = style;
                }
                if ([entry[@"hints"] isKindOfClass:NSArray.class])
                    for (id hint in entry[@"hints"]) if ([hint isKindOfClass:NSNumber.class] && scope.hints.count < 8) [scope.hints addObject:hint];
            }
        }
    }
    return scope;
}
+ (NSString *)cacheKey:(NSDictionary *)context {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return [NSString stringWithFormat:@"%@/%@/%@", info[@"CFBundleShortVersionString"] ?: @"", info[@"CFBundleVersion"] ?: @"", context[@"account"] ?: @""];
}
+ (void)saveScope:(DYYYExpiryScope *)scope context:(NSDictionary *)context {
    if (!scope || !context) return;
    NSMutableDictionary *cache = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"DYYYUnreadExpiryNativeStyles"] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *key = [self cacheKey:context];
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    if (scope.style.direct) { entry[@"mode"] = @(scope.style.mode); entry[@"shape"] = scope.style.shape; }
    entry[@"hints"] = scope.hints.array;
    if (!cache[key] && cache.count >= 8) [cache removeObjectForKey:[cache.allKeys sortedArrayUsingSelector:@selector(compare:)].firstObject];
    cache[key] = entry;
    [NSUserDefaults.standardUserDefaults setObject:cache forKey:@"DYYYUnreadExpiryNativeStyles"];
}
+ (void)setStatus:(NSString *)status {
    [self shared].status = status;
    for (AWESettingItemModel *item in [self shared].statusItems.allObjects) { item.detail = status; [item refreshCell]; }
}
+ (BOOL)matchesClass:(Class)cls selector:(SEL)selector arguments:(NSString *)arguments {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != arguments.length + 2) return NO;
    char *result = method_copyReturnType(method);
    BOOL matches = result && result[0] == 'v'; free(result);
    for (NSUInteger index = 0; matches && index < arguments.length; index++) {
        char *type = method_copyArgumentType(method, (unsigned int)index + 2);
        matches = type && type[0] == [arguments characterAtIndex:index]; free(type);
    }
    return matches;
}
+ (void)learnConversation:(id)conversation receiver:(id)receiver mode:(unsigned long long)mode completion:(id)completion {
    if (![self days]) return;
    NSString *shape = [DYYYUnreadExpiryPolicy completionShape:completion];
    if (!shape) return;
    __weak id weakConversation = conversation, weakReceiver = receiver;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self days] || !weakConversation || !weakReceiver) return;
        NSDictionary *context = [DYYYIMService capturedExpiryContext:weakConversation];
        if (!context) return;
        DYYYExpiryStyle *style = [DYYYExpiryStyle new];
        style.receiver = weakReceiver; style.direct = weakReceiver == weakConversation;
        style.mode = mode; style.shape = shape;
        DYYYExpiryScope *scope = [self scope:context[@"root"]];
        if (style.direct || !scope.style.direct) scope.style = style;
        [self saveScope:scope context:context];
        [self setStatus:@"已学习原生方式，等待检查"];
        [self schedule];
    });
}
+ (void)observeHintType:(long long)hint manager:(id)manager {
    if (![self days]) return;
    __weak id weakManager = manager;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self days]) return;
        NSDictionary *context = [DYYYIMService capturedExpiryContext:nil];
        if (!context || context[@"messages"] != weakManager) return;
        DYYYExpiryScope *scope = [self scope:context[@"root"]];
        if (scope.hints.count < 8) [scope.hints addObject:@(hint)];
        [self saveScope:scope context:context];
    });
}
+ (dispatch_queue_t)queue {
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.dyyy.expired-unread", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
+ (void)settingsChanged {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self settingsChanged]; }); return; }
    DYYYUnreadExpiry *state = [self shared]; state.generation++;
    [state.scanned removeAllObjects]; [state.attempted removeAllObjects];
    [self installHooks];
    [self setStatus:[self days] ? @"等待原生已读方式，请正常读一次聊天" : @"使用抖音默认"];
    [self schedule];
}
+ (void)schedule {
    if (![self days]) return;
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self schedule]; }); return; }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    DYYYUnreadExpiry *state = [self shared];
    if (state.busy) { state.requested = YES; return; }
    if (state.scheduled) return;
    state.scheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        state.scheduled = NO;
        if (![self days] || state.busy || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        NSDictionary *context = [DYYYIMService capturedExpiryContext:nil];
        if (!context) { [self setStatus:@"等待当前账户消息服务"]; return; }
        DYYYExpiryStyle *style = [self scope:context[@"root"]].style;
        if (!style || (!style.direct && !style.receiver)) { [self setStatus:@"请先正常读一次有未读的聊天"]; return; }
        NSArray *conversations = [DYYYIMConversationStore conversationsForRoot:context[@"root"] limit:128];
        [self setStatus:@"正在检查原生已加载会话"];
        state.busy = YES; state.requested = NO;
        [self process:conversations index:0 context:context generation:state.generation];
    });
}
+ (BOOL)validContext:(NSDictionary *)context generation:(NSUInteger)generation {
    if (generation != [self shared].generation || ![self days] || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    NSDictionary *current = [DYYYIMService capturedExpiryContext:nil];
    return current && current[@"root"] == context[@"root"] && [current[@"account"] isEqual:context[@"account"]];
}
+ (void)finishRun {
    DYYYUnreadExpiry *state = [self shared]; state.busy = NO;
    if (state.requested) { state.requested = NO; [self schedule]; }
}
+ (void (^)(id))callbackFor:(void (^)(id))returned {
    __block BOOL used = NO;
    return ^(id value) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (used) return; used = YES;
            if ([self shared].pendingQueries) [self shared].pendingQueries--;
            returned(value);
        });
    };
}
+ (void)process:(NSArray *)conversations index:(NSUInteger)index context:(NSDictionary *)context generation:(NSUInteger)generation {
    if (![self validContext:context generation:generation] || index >= conversations.count) { [self finishRun]; return; }
    TIMXOConversation *conversation = conversations[index];
    void (^next)(void) = ^{ dispatch_async(dispatch_get_main_queue(), ^{ [self process:conversations index:index + 1 context:context generation:generation]; }); };
    NSString *cid = conversation.identifier;
    if (![DYYYIMService capturedExpiryContext:conversation] || !conversation.isCurrentUserAParticipant || !cid.length) { next(); return; }
    NSUInteger count = conversation.unreadCount;
    if (!count || count > 4096) { if (count > 4096) [self setStatus:@"单会话未读超出检查上限，保留原状"]; next(); return; }
    DYYYExpiryScope *scope = [self scope:context[@"root"]];
    long long peer = [(TIMXOConversationManager *)context[@"manager"] otherUserIDFor1to1ChatWithConversationID:cid];
    if (peer == [context[@"account"] longLongValue]) { next(); return; }
    NSArray *hints = scope.hints.array.copy;
    if (peer <= 0 && !hints.count) { [self setStatus:@"群聊提示类型尚未就绪，保留原状"]; next(); return; }
    NSString *signature = [NSString stringWithFormat:@"%@/%@/%lu/%.0f/%lu", context[@"account"], [self days], (unsigned long)count, floor(NSDate.date.timeIntervalSince1970 / 60), (unsigned long)hints.count];
    NSString *key = [context[@"account"] stringByAppendingFormat:@"/%@", cid];
    if ([[self shared].scanned[key] isEqual:signature] || [self shared].scanned.count >= 512) { next(); return; }
    [self shared].scanned[key] = signature;
    TIMXOMessageManager *messages = context[@"messages"];
    if (![messages respondsToSelector:@selector(asyncGetUnreadMessagesFromSender:inConversation:limit:completion:)] ||
        (peer <= 0 && ![messages respondsToSelector:@selector(asyncGetUnreadMessagesForHintType:inConversation:limit:completion:)])) {
        [self setStatus:@"原生未读接口不可用，保留原状"]; next(); return;
    }
    NSUInteger queryCount = peer > 0 ? 1 : hints.count;
    if ([self shared].pendingQueries + queryCount > 8) { [self setStatus:@"已有未确认查询，等待原生返回"]; next(); return; }
    [self shared].pendingQueries += queryCount;
    __block BOOL finished = NO;
    __block NSUInteger pending = peer > 0 ? 1 : hints.count;
    NSMutableArray *results = [NSMutableArray array];
    void (^returned)(id) = ^(id result) {
        if (finished) return;
        // 原生回调栈只转交结果；解包和模型读取离开 SDK 锁后在独立队列执行。
        dispatch_async([self queue], ^{
            NSArray *array = [DYYYIMHistoryReader messageArray:result];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (finished) return;
                if (![self validContext:context generation:generation]) { finished = YES; next(); return; }
                if (!array || array.count > 4096) { finished = YES; [self setStatus:@"未读明细不可验证，保留原状"]; next(); return; }
                [results addObjectsFromArray:array];
                if (--pending) return;
                finished = YES;
                NSArray *batch = results.copy;
                dispatch_async([self queue], ^{
                    NSMutableArray *facts = [NSMutableArray array]; NSMutableDictionary *byID = [NSMutableDictionary dictionary];
                    NSMutableSet *observedHints = [NSMutableSet set]; BOOL hasObjectOrders = YES, validBatch = YES;
                    @try {
                        for (TIMXOMessage *message in batch) {
                            if (![message isKindOfClass:NSClassFromString(@"TIMXOMessage")]) { validBatch = NO; break; }
                            NSNumber *order = message.orderInConversation;
                            if (![order isKindOfClass:NSNumber.class] || order.longLongValue <= 0) hasObjectOrders = NO;
                        }
                        for (TIMXOMessage *message in batch) {
                            if (!validBatch) break;
                            if (![message isKindOfClass:NSClassFromString(@"TIMXOMessage")]) continue;
                            NSString *identifier = message.identifier, *belonging = message.belongingConversationIdentifier;
                            NSDate *date = message.serverCreatedAt ?: message.createdAt;
                            NSNumber *order = hasObjectOrders ? message.orderInConversation : @(message.orderIndex);
                            [facts addObject:@{ @"id":identifier ?: @"", @"conversation":belonging ?: @"", @"order":order ?: @0, @"date":date ?: NSNull.null }];
                            if (identifier.length) byID[identifier] = message;
                            [observedHints addObject:@(message.hintType)];
                        }
                    } @catch (__unused NSException *exception) { [facts removeAllObjects]; }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (![self validContext:context generation:generation] || ![DYYYIMService capturedExpiryContext:conversation] || conversation.unreadCount != count) { next(); return; }
                        NSDictionary *plan = [DYYYUnreadExpiryPolicy planForFacts:facts nativeCount:count conversation:cid cutoff:[NSDate dateWithTimeIntervalSinceNow:-[self days].doubleValue * 86400]];
                        [self shared].checked++;
                        if (![plan[@"status"] isEqual:@"ready"]) {
                            if ([plan[@"status"] isEqual:@"no_safe_expired_prefix"]) [self setStatus:@"已检查，暂无可安全处理的超时未读"];
                            else { [self shared].skippedUnverified++; [self setStatus:@"未读明细或边界不完整，保留原状"]; }
                        }
                        if ([plan[@"status"] isEqual:@"ready"] || [plan[@"status"] isEqual:@"no_safe_expired_prefix"]) {
                            NSUInteger prior = scope.hints.count;
                            for (NSNumber *hint in observedHints) if (scope.hints.count < 8) [scope.hints addObject:hint];
                            if (scope.hints.count != prior) { [self shared].requested = YES; [self saveScope:scope context:context]; }
                        }
                        if (![plan[@"status"] isEqual:@"ready"]) { next(); return; }
                        TIMXOMessage *boundary = byID[plan[@"boundary"]];
                        NSString *attemptKey = [key stringByAppendingFormat:@"/%@/%@", [self days], plan[@"boundary"]];
                        if (!boundary || [[self shared].attempted containsObject:attemptKey] || [self shared].attempted.count >= 512) { next(); return; }
                        if ([self shared].pendingWrites >= 8) { [self setStatus:@"已有未确认已读请求，保留原状"]; next(); return; }
                        [[self shared].attempted addObject:attemptKey];
                        [self submitBoundary:boundary conversation:conversation style:scope.style next:next];
                    });
                });
            });
        });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!finished) { finished = YES; [self setStatus:@"未读查询超时，保留原状"]; next(); }
    });
    dispatch_async([self queue], ^{
        for (NSNumber *argument in peer > 0 ? @[@(peer)] : hints) {
            void (^callback)(id) = [self callbackFor:returned];
            @try {
                if (peer > 0) [messages asyncGetUnreadMessagesFromSender:peer inConversation:cid limit:4096 completion:callback];
                else [messages asyncGetUnreadMessagesForHintType:argument.longLongValue inConversation:cid limit:4096 completion:callback];
            } @catch (__unused NSException *exception) { callback(nil); }
        }
    });
}
+ (void)submitBoundary:(TIMXOMessage *)boundary conversation:(TIMXOConversation *)conversation style:(DYYYExpiryStyle *)style next:(void (^)(void))next {
    if (!style || (!style.direct && !style.receiver)) { [self setStatus:@"原生已读方式已失效"]; next(); return; }
    __block BOOL completed = NO;
    __block BOOL callbackUsed = NO;
    NSUInteger generation = [self shared].generation;
    void (^finished)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callbackUsed) return; callbackUsed = YES;
            if ([self shared].pendingWrites) [self shared].pendingWrites--;
            [self shared].callbacks++;
            if (completed) return; completed = YES;
            if (generation == [self shared].generation && [self days]) [self setStatus:@"原生处理已返回，请以消息页为准"]; next();
        });
    };
    id completion = nil;
    if ([style.shape isEqual:@"void"]) completion = ^{ finished(); };
    else if ([style.shape isEqual:@"object"]) completion = ^(id value) { finished(); };
    else if ([style.shape isEqual:@"objects"]) completion = ^(id first, id second) { finished(); };
    else if (![style.shape isEqual:@"nil"]) { [self setStatus:@"回调格式未知，保留原状"]; next(); return; }
    [self shared].submissions++;
    if (completion) [self shared].pendingWrites++;
    [self setStatus:@"已提交超时消息边界，等待原生更新"];
    // 只调用观察过的同一种原生接口/参数形式，不写 count/cursor，不删除消息。
    @try {
        if (style.direct) [conversation markAllMessagesBeforeMessage:boundary asReadWithMode:style.mode completion:completion];
        else [(IESIMConversationDataManager *)style.receiver markAllMessagesBeforeMessage:boundary asReadWithMode:style.mode ofConversation:conversation completion:completion];
    } @catch (__unused NSException *exception) {
        if (completion && !callbackUsed && [self shared].pendingWrites) [self shared].pendingWrites--;
        callbackUsed = YES; completed = YES;
        [self setStatus:@"原生处理异常，不自动重试"]; next(); return;
    }
    if (!completion) { completed = YES; next(); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!completed) { completed = YES; [self setStatus:@"原生结果未确认，不自动重试"]; next(); }
    });
}
+ (NSArray<AWESettingItemModel *> *)settingsItems {
    AWESettingItemModel *toggle = [DYYYSettingsHelper createSettingItem:@{ @"identifier":@"DYYYUnreadExpiryEnabled", @"title":@"超时未读自动已读", @"subTitle":@"将超时消息设为已读，聊天记录仍可翻看", @"cellType":@37, @"imageName":@"ic_comment_outlined_20" }];
    void (^original)(void) = toggle.switchChangedBlock;
    toggle.switchChangedBlock = ^{ if (original) original(); [self settingsChanged]; };
    NSString *text = [NSUserDefaults.standardUserDefaults stringForKey:@"DYYYUnreadExpiryDays"] ?: @"";
    AWESettingItemModel *days = [DYYYSettingsHelper createSettingItem:@{ @"identifier":@"DYYYUnreadExpiryDays", @"title":@"未读保留天数", @"detail":text.length ? text : @"抖音默认", @"cellType":@26, @"imageName":@"ic_clock_outlined_20" }];
    __weak AWESettingItemModel *weakDays = days;
    days.cellTappedBlock = ^{
        [DYYYSettingsHelper showTextInputAlert:@"未读保留天数" defaultText:[NSUserDefaults.standardUserDefaults stringForKey:@"DYYYUnreadExpiryDays"] ?: @"" placeholder:@"例如 7；留空使用抖音默认" onConfirm:^(NSString *input) {
            NSString *value = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (value.length && ![DYYYUnreadExpiryPolicy daysFromText:value]) { [DYYYToast showToast:@"请输入大于 0 且不超过 36500 的天数，可填小数"]; return; }
            [DYYYSettingsHelper setUserDefaults:value forKey:@"DYYYUnreadExpiryDays"];
            weakDays.detail = value.length ? value : @"抖音默认"; [weakDays refreshCell]; [self settingsChanged];
        } onCancel:nil];
    };
    AWESettingItemModel *status = [DYYYSettingsHelper createSettingItem:@{ @"identifier":@"DYYYUnreadExpiryStatus", @"title":@"处理状态", @"detail":[self days] ? [self shared].status : @"使用抖音默认", @"cellType":@26, @"imageName":@"ic_clock_outlined_20" }];
    [[self shared].statusItems addObject:status];
    return @[toggle, days, status];
}
+ (NSDictionary *)diagnostics {
    if (!NSThread.isMainThread) return @{};
    NSDictionary *context = [DYYYIMService capturedExpiryContext:nil];
    DYYYExpiryScope *scope = context ? [[self shared].scopes objectForKey:context[@"root"]] : nil;
    return @{ @"enabled":@([NSUserDefaults.standardUserDefaults boolForKey:@"DYYYUnreadExpiryEnabled"]), @"days":[self days] ?: NSNull.null,
        @"status":[self shared].status, @"nativeStyleReady":@(scope.style != nil), @"knownHintTypes":@(scope.hints.count),
        @"submissions":@([self shared].submissions), @"callbacks":@([self shared].callbacks), @"busy":@([self shared].busy),
        @"pendingQueries":@([self shared].pendingQueries), @"pendingWrites":@([self shared].pendingWrites),
        @"checkedConversations":@([self shared].checked), @"skippedUnverified":@([self shared].skippedUnverified),
        @"limitPerConversation":@4096, @"policy":@"complete_native_unread_expired_prefix_native_mark_read" };
}
@end
