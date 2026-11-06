#import "DYYYRecallCoordinator.h"
#import "DYYYRecallPolicy.h"
#import "DYYYRecallStore.h"
#import "DYYYChatEnhancementPolicy.h"
#import "DYYYIMService.h"
#import "DYYYSettingsHelper.h"
#import "DYYYBottomAlertView.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface DYYYRecallModelState : NSObject
@property (atomic, weak) id root;
@property (nonatomic, copy) NSString *cacheKey;
@property (atomic, weak) NSDictionary *content;
@property (atomic, copy) NSDictionary *identity;
@property (atomic, assign) BOOL recalled;
@property (atomic, assign) BOOL countedProtection;
@property (atomic, assign) NSTimeInterval recalledAt;
@property (atomic, assign) BOOL pending;
@property (atomic, copy) NSString *lastSignature;
@end
@implementation DYYYRecallModelState @end

@interface DYYYRecallUIReference : NSObject
@property (atomic, copy) NSString *account;
@property (atomic, copy) NSDictionary *media;
@property (atomic, copy) NSDictionary *pathMap;
@end
@implementation DYYYRecallUIReference @end

@interface DYYYRecallCellBinding : NSObject
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *conversation;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *server;
@property (nonatomic, copy) NSDictionary *record;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, assign) BOOL requested;
@end
@implementation DYYYRecallCellBinding @end

@interface DYYYRecallCoordinator ()
@property (atomic, assign) BOOL active;
@property (atomic, assign) NSUInteger generation;
@property (atomic, copy) NSString *account;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) DYYYRecallStore *store;
@property (nonatomic, strong) NSCache<NSString *, NSDictionary *> *cache;
@property (nonatomic, strong) NSCache<NSString *, NSDictionary *> *contents;
@property (nonatomic, strong) NSHashTable<UITableViewCell *> *cells;
@property (nonatomic, strong) NSHashTable<DYYYRecallUIReference *> *uiReferences;
@property (atomic, assign) NSUInteger savedSnapshots;
@property (atomic, assign) NSUInteger protectedModels;
@property (nonatomic, strong) NSMutableDictionary *hooks;
@property (atomic, copy) NSString *status;
@property (atomic, copy) NSDictionary *statistics;
@property (nonatomic, assign) NSUInteger pending;
@end

@implementation DYYYRecallCoordinator
#pragma mark - 生命周期与私有接口保护
+ (instancetype)shared {
    static DYYYRecallCoordinator *instance; static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [DYYYRecallCoordinator new];
        instance.queue = dispatch_queue_create("com.dyads.recall.capture", DISPATCH_QUEUE_SERIAL);
        instance.cache = [NSCache new]; instance.cache.countLimit = 1024; instance.cache.totalCostLimit=8*1024*1024;
        instance.contents=[NSCache new];instance.contents.countLimit=256;instance.contents.totalCostLimit=8*1024*1024;
        instance.cells = [NSHashTable weakObjectsHashTable]; instance.uiReferences=[NSHashTable weakObjectsHashTable]; instance.hooks = [NSMutableDictionary dictionary];
        NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        instance.store = [[DYYYRecallStore alloc] initWithDirectory:[base URLByAppendingPathComponent:@"DYads/MessageRetention" isDirectory:YES]];
        instance.status = @"尚未启用";
        instance.active = [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYPreventRecall"];
    });
    return instance;
}
+ (BOOL)enabled { return [self shared].active; }
+ (id)object:(id)owner selector:(NSString *)name {
    SEL selector = NSSelectorFromString(name);
    if (!owner || ![DYYYChatEnhancementPolicy class:object_getClass(owner) selector:selector result:'@' arguments:@""]) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(owner,selector); } @catch (__unused NSException *exception) { return nil; }
}
+ (NSNumber *)number:(id)owner selector:(NSString *)name {
    SEL selector=NSSelectorFromString(name);
    @try {
        if ([DYYYChatEnhancementPolicy class:object_getClass(owner) selector:selector result:'q' arguments:@""]) return @(((long long(*)(id,SEL))objc_msgSend)(owner,selector));
        if ([DYYYChatEnhancementPolicy class:object_getClass(owner) selector:selector result:'Q' arguments:@""]) return @(((unsigned long long(*)(id,SEL))objc_msgSend)(owner,selector));
        if ([DYYYChatEnhancementPolicy class:object_getClass(owner) selector:selector result:'B' arguments:@""]) return @(((BOOL(*)(id,SEL))objc_msgSend)(owner,selector));
    } @catch (__unused NSException *exception) {}
    return nil;
}
+ (NSString *)identifier:(id)value {
    if ([value isKindOfClass:NSNumber.class]) value = [value stringValue];
    return [value isKindOfClass:NSString.class] && [value length] && [value length] <= 512 ? value : nil;
}
+ (DYYYRecallModelState *)state:(id)model create:(BOOL)create {
    if (!model) return nil;
    DYYYRecallModelState *state=objc_getAssociatedObject(model,@selector(bindModel:root:));
    if (!state && create) {
        @synchronized(model) {
            state=objc_getAssociatedObject(model,@selector(bindModel:root:));
            if (!state) { state=[DYYYRecallModelState new];state.cacheKey=NSUUID.UUID.UUIDString; objc_setAssociatedObject(model,@selector(bindModel:root:),state,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        }
    }
    return state;
}
+ (void)retainContent:(NSDictionary *)content state:(DYYYRecallModelState *)state {
    if(!content || !state)return;
    NSUInteger cost=[NSJSONSerialization dataWithJSONObject:content options:0 error:nil].length;
    [[self shared].contents setObject:content forKey:state.cacheKey cost:cost];state.content=content;
}
+ (void)recordHook:(NSString *)name installed:(BOOL)installed { if(NSThread.isMainThread)[self shared].hooks[name]=@(installed); }
+ (void)settingsChanged {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self settingsChanged];});return;}
    DYYYRecallCoordinator *coordinator=[self shared];
    coordinator.active=[NSUserDefaults.standardUserDefaults boolForKey:@"DYYYPreventRecall"];
    coordinator.account=[DYYYIMService capturedAccountID]; coordinator.generation++;
    coordinator.status=coordinator.active?@"等待抖音自然接收或展示消息":@"已关闭，已有留存保留";
    [self installHooks];
    for(UITableViewCell *cell in coordinator.cells) [self refreshCell:cell];
}
#pragma mark - 原生回调仅保存入参，不在SDK栈里读账号/消息或做磁盘IO
+ (void)bindModel:(id)model root:(id)root {
    if(![self enabled] || !model || !root)return;
    DYYYRecallModelState *state=[self state:model create:YES];
    if (state.root && state.root != root) { state.identity=nil; state.content=nil; state.recalled=NO; state.recalledAt=0; }
    if(state.root==root && state.identity && state.content)return;
    state.root=root;
    [self scheduleModel:model];
}
+ (void)captureContent:(id)content model:(id)model {
    if(![self enabled])return;
    NSDictionary *snapshot=[DYYYRecallPolicy contentSnapshot:content];
    if(!snapshot)return;
    DYYYRecallModelState *state=[self state:model create:YES];
    if(state.content.count)return;
    [self retainContent:snapshot state:state];
    [self scheduleModel:model];
}
+ (void)captureOriginalContent:(id)content model:(id)model {
    if(![self enabled])return;
    NSDictionary *snapshot=[DYYYRecallPolicy contentSnapshot:content];if(!snapshot)return;
    DYYYRecallModelState *state=[self state:model create:YES];
    [self retainContent:snapshot state:state];[self scheduleModel:model];
}
+ (void)observeRecalled:(BOOL)recalled model:(id)model {
    if(![self enabled] || !recalled)return;
    DYYYRecallModelState *state=[self state:model create:YES];
    @synchronized(state){if(state.recalled)return;state.recalled=YES;if(!state.recalledAt)state.recalledAt=NSDate.date.timeIntervalSince1970;}
    [self scheduleModel:model];
}
+ (BOOL)protectModel:(id)model {
    if(![self enabled])return NO;
    DYYYRecallModelState *state=[self state:model create:NO]; NSDictionary *identity=state.identity;
    if([self shared].account.length && ![identity[@"account"] isEqual:[self shared].account])return NO;
    BOOL protected=state.recalled && [DYYYRecallPolicy canProtectAccount:identity[@"account"] sender:identity[@"sender"] conversation:identity[@"conversation"] message:identity[@"message"] content:state.content];
    if(protected && !state.countedProtection){@synchronized(state){if(!state.countedProtection){state.countedProtection=YES;[self shared].protectedModels++;}}}
    return protected;
}
+ (NSDictionary *)protectedContentForModel:(id)model { return [self protectModel:model] ? [self state:model create:NO].content : nil; }
+ (void)scheduleModel:(id)model {
    DYYYRecallCoordinator *coordinator=[self shared]; DYYYRecallModelState *state=[self state:model create:YES];
    if(!state.root)return;
    @synchronized(coordinator){if(state.pending || coordinator.pending>=128)return;state.pending=YES;coordinator.pending++;}
    __weak id weakModel=model; NSUInteger generation=coordinator.generation;
    dispatch_async(coordinator.queue,^{
        @try {
            id current=weakModel,root=state.root;
            if(!current || !root || !coordinator.active || generation!=coordinator.generation)return;
            // 身份校验已离开原生回调栈；不创建SDK实例，不查历史/未读，不保存其他账号名下。
            NSString *account=[self identifier:[self object:[self object:root selector:@"config"] selector:@"uid"]];
            NSString *conversation=[self identifier:[self object:current selector:@"belongingConversationIdentifier"]];
            NSString *message=[self identifier:[self object:current selector:@"identifier"]];
            NSString *sender=[self identifier:[self number:current selector:@"sender"]];
            NSNumber *type=[self number:current selector:@"conversationType"];
            if(!account.length || !conversation.length || !message.length || !sender.length || sender.longLongValue<=0 || [account isEqual:sender] || type.unsignedLongLongValue==10)return;
            if(state.identity[@"account"] && ![state.identity[@"account"] isEqual:account])return;
            if(coordinator.account.length && ![coordinator.account isEqual:account])return;
            NSString *server=[self identifier:[self object:current selector:@"serverMessageID"]] ?: @"";
            if([server isEqual:@"0"])server=@"";
            state.identity=@{@"account":account,@"conversation":conversation,@"message":message,@"sender":sender,@"server":server};
            BOOL nativeRecalled=[[self number:current selector:@"recalled"] boolValue];
            if(nativeRecalled){state.recalled=YES;if(!state.recalledAt)state.recalledAt=NSDate.date.timeIntervalSince1970;}
            if(!state.content) {
                NSDictionary *snapshot=[DYYYRecallPolicy contentSnapshot:[self object:current selector:@"content"]];
                if(snapshot)[self retainContent:snapshot state:state];
            }
            if(!state.content) [self retainContent:[DYYYRecallPolicy contentSnapshot:[self object:current selector:@"recalledContent"]] state:state];
            NSMutableDictionary *record=[state.identity mutableCopy];
            if(state.content)record[@"content"]=state.content;
            record[@"recalled"]=@(state.recalled); if(state.recalledAt)record[@"recalledAt"]=@(state.recalledAt);
            NSString *signature=[DYYYRecallPolicy fingerprint:record];
            if([state.lastSignature isEqual:signature])return;
            state.lastSignature=signature;
            [coordinator.store recordForAccount:account conversation:conversation message:message server:server completion:^(NSDictionary *old){
                if(generation!=coordinator.generation || !coordinator.active)return;
                if(!state.content && old[@"content"])[self retainContent:old[@"content"] state:state];
                if([old[@"recalled"] boolValue]){state.recalled=YES;state.recalledAt=[old[@"recalledAt"] doubleValue];}
                if(state.content)record[@"content"]=state.content;
                record[@"recalled"]=@(state.recalled);if(state.recalledAt)record[@"recalledAt"]=@(state.recalledAt);
                [self persist:record state:state generation:generation];
            }];
        } @catch(__unused NSException *exception){coordinator.status=@"本次原生消息身份读取失败，保持原生处理";}
        @finally{@synchronized(coordinator){state.pending=NO;if(coordinator.pending)coordinator.pending--;}}
    });
}
+ (void)cacheRecord:(NSDictionary *)record {
    if(!record)return;
    for(NSString *message in @[record[@"message"]?:@"",record[@"server"]?:@""]){
        NSString *key=[DYYYRecallPolicy keyForAccount:record[@"account"] conversation:record[@"conversation"] message:message];
        if(key)[[self shared].cache setObject:record forKey:key cost:[NSJSONSerialization dataWithJSONObject:record options:0 error:nil].length];
    }
}
+ (void)persist:(NSDictionary *)record state:(DYYYRecallModelState *)state generation:(NSUInteger)generation {
    DYYYRecallCoordinator *coordinator=[self shared];
    if(!coordinator.active || generation!=coordinator.generation)return;
    [coordinator.store saveRecord:record completion:^(NSDictionary *saved,NSString *error){
        if(generation!=coordinator.generation)return;
        if(!saved){coordinator.status=error?:@"未取得原内容";return;}
        coordinator.savedSnapshots++;[self cacheRecord:saved];coordinator.status=[saved[@"recalled"] boolValue]?@"已保留撤回消息的原始记录":@"正在保留本机已取得的消息";
        dispatch_async(dispatch_get_main_queue(),^{
            if(generation!=coordinator.generation)return;
            for(UITableViewCell *cell in coordinator.cells){
                DYYYRecallCellBinding *binding=objc_getAssociatedObject(cell,@selector(captureCell:));
                if([binding.account isEqual:saved[@"account"]] && [binding.conversation isEqual:saved[@"conversation"]] &&
                   ([binding.message isEqual:saved[@"message"]] || (binding.server.length && [binding.server isEqual:saved[@"server"]]))){binding.record=saved;[self refreshCell:cell];}
            }
        });
    }];
}
#pragma mark - 原生UI消息恢复（不创建SDK模型、不改已读接口）
+ (NSDictionary *)cachedAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message server:(NSString *)server {
    NSString *key=[DYYYRecallPolicy keyForAccount:account conversation:conversation message:message];
    NSDictionary *record=key?[[self shared].cache objectForKey:key]:nil;
    if(!record && server.length){key=[DYYYRecallPolicy keyForAccount:account conversation:conversation message:server];record=key?[[self shared].cache objectForKey:key]:nil;}
    return record;
}
+ (id)replacementForUIMessage:(id)message {
    if(!NSThread.isMainThread || ![self enabled] || !message)return message;
    Class base=NSClassFromString(@"AWEIMMessage");
    if(!base || ![message isKindOfClass:base])return message;
    NSString *account=[self shared].account,*cid=[self identifier:[self object:message selector:@"conversationID"]],*mid=[self identifier:[self object:message selector:@"messageID"]];
    NSString *server=[self identifier:[self number:message selector:@"serverMessageID"]];
    NSDictionary *record=[self cachedAccount:account conversation:cid message:mid server:server];
    if(![record[@"recalled"] boolValue] || ![record[@"uiClass"] isKindOfClass:NSString.class])return message;
    BOOL recalled=[[self number:message selector:@"recalled"] boolValue];
    if(!recalled && ![NSStringFromClass([message class]) isEqual:@"AWEIMRecallMessage"])return message;
    Class cls=NSClassFromString(record[@"uiClass"]);
    if(!cls || ![cls isSubclassOfClass:base] || [record[@"uiClass"] isEqual:@"AWEIMRecallMessage"] ||
       ![DYYYChatEnhancementPolicy class:cls selector:NSSelectorFromString(@"initWithContentDict:") result:'@' arguments:@"@"])return message;
    @try {
        id clone=((id(*)(id,SEL,id))objc_msgSend)([cls alloc],NSSelectorFromString(@"initWithContentDict:"),record[@"content"]);
        if(![clone isKindOfClass:cls])return message;
        for(NSString *name in @[@"messageID",@"conversationID",@"fromUid",@"secFromUid"]){
            NSString *setter=[NSString stringWithFormat:@"set%@%@:",[[name substringToIndex:1] uppercaseString],[name substringFromIndex:1]];
            id value=[self object:message selector:name];
            if(value && [DYYYChatEnhancementPolicy class:cls selector:NSSelectorFromString(setter) result:'v' arguments:@"@"])((void(*)(id,SEL,id))objc_msgSend)(clone,NSSelectorFromString(setter),value);
        }
        for(NSString *name in @[@"serverMessageID",@"createTime",@"localID"]){
            NSNumber *value=[self number:message selector:name];NSString *setter=[NSString stringWithFormat:@"set%@%@:",[[name substringToIndex:1] uppercaseString],[name substringFromIndex:1]];
            if(value && [DYYYChatEnhancementPolicy class:cls selector:NSSelectorFromString(setter) result:'v' arguments:@"q"])((void(*)(id,SEL,long long))objc_msgSend)(clone,NSSelectorFromString(setter),value.longLongValue);
        }
        DYYYRecallUIReference *reference=[DYYYRecallUIReference new]; reference.account=account; reference.media=record[@"media"];reference.pathMap=record[@"pathMap"];
        objc_setAssociatedObject(clone,@selector(mediaPathForUIMessage:original:),reference,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self shared].uiReferences addObject:reference];
        return clone;
    } @catch(__unused NSException *exception){[self shared].status=@"当前消息的原生UI恢复未适配，原记录仍保留";return message;}
}
#pragma mark - 聊天内提示与本机媒体副本
+ (void)resetCell:(UITableViewCell *)cell {
    if(!NSThread.isMainThread)return;
    DYYYRecallCellBinding *binding=objc_getAssociatedObject(cell,@selector(captureCell:));[binding.label removeFromSuperview];
    objc_setAssociatedObject(cell,@selector(captureCell:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self shared].cells removeObject:cell];
}
+ (void)captureCell:(UITableViewCell *)cell {
    if(!NSThread.isMainThread || ![cell isKindOfClass:UITableViewCell.class])return;
    if(![self enabled] || !cell.window){[self resetCell:cell];return;}
    id ui=[self object:[self object:cell selector:@"currentContext"] selector:@"message"];
    NSString *account=[DYYYIMService capturedAccountID];[self shared].account=account;
    NSString *cid=[self identifier:[self object:ui selector:@"conversationID"]],*mid=[self identifier:[self object:ui selector:@"messageID"]],*sender=[self identifier:[self object:ui selector:@"fromUid"]];
    if(!account.length || !cid.length || !mid.length || !sender.length || [account isEqual:sender]){[self resetCell:cell];return;}
    NSString *server=[self identifier:[self number:ui selector:@"serverMessageID"]]?:@"";if([server isEqual:@"0"])server=@"";
    DYYYRecallCellBinding *binding=objc_getAssociatedObject(cell,@selector(captureCell:));
    if(![binding.account isEqual:account] || ![binding.conversation isEqual:cid] || ![binding.message isEqual:mid]){
        [self resetCell:cell];binding=[DYYYRecallCellBinding new];binding.account=account;binding.conversation=cid;binding.message=mid;binding.server=server;
        objc_setAssociatedObject(cell,@selector(captureCell:),binding,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self shared].cells addObject:cell];
    }
    NSDictionary *cached=[self cachedAccount:account conversation:cid message:mid server:server];
    if(cached)binding.record=cached;
    DYYYRecallUIReference *reference=objc_getAssociatedObject(ui,@selector(mediaPathForUIMessage:original:));
    if(!reference){reference=[DYYYRecallUIReference new];objc_setAssociatedObject(ui,@selector(mediaPathForUIMessage:original:),reference,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[self shared].uiReferences addObject:reference];}
    reference.account=account;reference.media=cached[@"media"];reference.pathMap=cached[@"pathMap"];
    [self refreshCell:cell];
    if(binding.requested)return;binding.requested=YES;
    NSDictionary *content=[DYYYRecallPolicy contentSnapshot:[self object:ui selector:@"getContentDict"]]?:[DYYYRecallPolicy contentSnapshot:[self object:ui selector:@"rawContentDict"]];
    NSString *className=NSStringFromClass([ui class]);
    BOOL notice=[className isEqual:@"AWEIMRecallMessage"];
    NSMutableDictionary *record=[@{@"account":account,@"conversation":cid,@"message":mid,@"server":server,@"sender":sender,@"recalled":@(notice || [cached[@"recalled"] boolValue])} mutableCopy];
    if(content && !notice){record[@"content"]=content;record[@"uiClass"]=className;}
    if(cached[@"recalledAt"])record[@"recalledAt"]=cached[@"recalledAt"];
    else if(notice)record[@"recalledAt"]=@(NSDate.date.timeIntervalSince1970);
    id paths=[self object:ui selector:@"awe_filePathDictionary"];
    NSMutableDictionary *pathMap=[NSMutableDictionary dictionary];
    if([paths isKindOfClass:NSDictionary.class])for(id key in paths){
        id value=paths[key];
        if([key isKindOfClass:NSString.class] && [key length]<=512 && [value isKindOfClass:NSString.class] && [value length]<=4096 && pathMap.count<8)pathMap[key]=value;
    }
    if([cached[@"pathMap"] isKindOfClass:NSDictionary.class] && [cached[@"pathMap"] count])record[@"pathMap"]=cached[@"pathMap"];
    else if(pathMap.count)record[@"pathMap"]=pathMap;
    reference.pathMap=record[@"pathMap"];
    NSUInteger generation=[self shared].generation;
    [self persist:record state:nil generation:generation];
    if(!cached)[[self shared].store recordForAccount:account conversation:cid message:mid server:server completion:^(NSDictionary *stored){
        if(generation!=[self shared].generation || !stored)return;[self cacheRecord:stored];
        dispatch_async(dispatch_get_main_queue(),^{if(objc_getAssociatedObject(cell,@selector(captureCell:))==binding){binding.record=stored;[self refreshCell:cell];}});
    }];
    NSMutableArray *candidates=[NSMutableArray array];
    NSString *path=[self identifier:[self object:ui selector:@"filePath"]];if(path)[candidates addObject:path];
    if([paths isKindOfClass:NSDictionary.class])for(id value in [paths allValues]){if([value isKindOfClass:NSString.class] && candidates.count<8)[candidates addObject:value];}
    if([NSUserDefaults.standardUserDefaults objectForKey:@"DYYYRecallKeepMedia"] && ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYRecallKeepMedia"])return;
    for(NSString *source in candidates){
        if([reference.media.allValues containsObject:source])continue;
        [[self shared].store copyMediaAtPath:source record:record completion:^(NSDictionary *media,NSString *error){
        if(generation!=[self shared].generation)return;
        if(media){
            [self shared].status=@"已另存实际媒体文件副本";
            [[self shared].store recordForAccount:account conversation:cid message:mid server:server completion:^(NSDictionary *saved){
                if(generation!=[self shared].generation || !saved)return;
                [self cacheRecord:saved];reference.media=saved[@"media"];reference.pathMap=saved[@"pathMap"];
            }];
        }
        else if(error.length)[self shared].status=error;
        }];
    }
}
+ (void)refreshCell:(UITableViewCell *)cell {
    DYYYRecallCellBinding *binding=objc_getAssociatedObject(cell,@selector(captureCell:));
    if(!binding)return;
    BOOL show=[self enabled] && [binding.record[@"recalled"] boolValue] && ![[NSUserDefaults.standardUserDefaults objectForKey:@"DYYYRecallShowMarker"] isEqual:@NO];
    if(!show){[binding.label removeFromSuperview];binding.label=nil;return;}
    if(![binding.account isEqual:[self shared].account]){[binding.label removeFromSuperview];binding.label=nil;return;}
    if(!binding.label){binding.label=[UILabel new];binding.label.font=[UIFont systemFontOfSize:10];binding.label.textColor=[UIColor colorWithRed:1 green:0.57 blue:0.32 alpha:1];binding.label.userInteractionEnabled=NO;binding.label.accessibilityIdentifier=@"DYads.RecallMarker";[cell.contentView addSubview:binding.label];}
    static NSDateFormatter *format;static dispatch_once_t once;dispatch_once(&once,^{format=[NSDateFormatter new];format.dateFormat=@"HH:mm:ss";});
    NSString *time=[format stringFromDate:[NSDate dateWithTimeIntervalSince1970:[binding.record[@"recalledAt"] doubleValue]]];
    BOOL available=[binding.record[@"content"] isKindOfClass:NSDictionary.class] && [binding.record[@"content"] count]>0;
    binding.label.text=[NSString stringWithFormat:@"对方已撤回 · %@%@",time,available?@"":@" · 原内容未取得"];
    CGSize size=[binding.label sizeThatFits:CGSizeMake(MAX(0,cell.bounds.size.width-32),12)];
    CGFloat x=16,y=MAX(0,cell.contentView.bounds.size.height-12);
    UIView *target=[self object:cell selector:@"contentTargetView"];
    if([target isKindOfClass:UIView.class] && [target isDescendantOfView:cell.contentView]){
        CGRect bubble=[target convertRect:target.bounds toView:cell.contentView];
        x=MAX(16,CGRectGetMinX(bubble));if(CGRectGetMaxY(bubble)+14<=CGRectGetHeight(cell.contentView.bounds))y=CGRectGetMaxY(bubble)+2;
    }
    CGRect frame=CGRectMake(x,y,MIN(size.width,MAX(0,cell.bounds.size.width-x-16)),12);
    if(!CGRectEqualToRect(binding.label.frame,frame))binding.label.frame=frame;
    [cell.contentView bringSubviewToFront:binding.label];
}
+ (id)mediaPathForUIMessage:(id)message original:(id)original {
    if(![self enabled])return original;
    DYYYRecallUIReference *reference=objc_getAssociatedObject(message,@selector(mediaPathForUIMessage:original:));
    if(![reference.account isEqual:[self shared].account])return original;
    if([original isKindOfClass:NSString.class] && [original length]){
        NSString *saved=reference.media[[original stringByStandardizingPath]];
        return [saved isKindOfClass:NSString.class]?saved:original;
    }
    // 原生已清掉路径时，只在已确认的消息种类中选唯一匹配的真实副本，不把视频封面当视频。
    NSString *type=NSStringFromClass(object_getClass(message));NSArray *extensions=nil;
    if([type containsString:@"ImageMessage"])extensions=@[@"jpg",@"jpeg",@"png",@"gif",@"webp",@"heic"];
    else if([type containsString:@"AudioMessage"])extensions=@[@"m4a",@"mp3",@"aac",@"amr",@"wav",@"caf"];
    else if([type containsString:@"VideoMessage"])extensions=@[@"mp4",@"mov"];
    NSString *only=nil;
    for(NSString *path in reference.media.allValues)if([extensions containsObject:path.pathExtension.lowercaseString]){if(only && ![only isEqual:path])return original;only=path;}
    return only?:original;
}
+ (id)mediaPathsForUIMessage:(id)message original:(id)original {
    if(![self enabled] || (original && ![original isKindOfClass:NSDictionary.class]))return original;
    DYYYRecallUIReference *reference=objc_getAssociatedObject(message,@selector(mediaPathForUIMessage:original:));
    if(![reference.account isEqual:[self shared].account])return original;
    NSMutableDictionary *result=nil;
    for(id key in original){id value=original[key];id saved=[self mediaPathForUIMessage:message original:value];if(saved!=value){if(!result)result=[original mutableCopy];result[key]=saved;}}
    // 仅恢复原生曾提供过的fileID到路径映射；没有原生键名时保持未知，不编造文件标识。
    for(NSString *key in reference.pathMap){
        NSString *source=reference.pathMap[key];NSString *saved=reference.media[source.stringByStandardizingPath];
        if(saved && !original[key]){if(!result)result=[original mutableCopy]?:[NSMutableDictionary dictionary];result[key]=saved;}
    }
    return result.count?result:original;
}
+ (void)mediaDownloadCompleted:(id)model {
    if(![self enabled])return;
    // 真实下载完成事件才补查可见消息的文件路径，不用定时扫描或每帧磁盘重试。
    dispatch_async(dispatch_get_main_queue(),^{for(UITableViewCell *cell in [self shared].cells.allObjects){
        DYYYRecallCellBinding *binding=objc_getAssociatedObject(cell,@selector(captureCell:));binding.requested=NO;[self captureCell:cell];
    }});
}
+ (void)controllerAppeared:(UIViewController *)controller {
    if(!NSThread.isMainThread)return;[self shared].account=[DYYYIMService capturedAccountID];
    UITableView *table=[self object:controller selector:@"tableView"];if(![table isKindOfClass:UITableView.class])return;
    for(UITableViewCell *cell in table.visibleCells)[self captureCell:cell];
}
#pragma mark - 设置与诊断
+ (NSArray<AWESettingItemModel *> *)settingsItems {
    NSMutableArray *items=[NSMutableArray array];
    for(NSArray *row in @[@[@"DYYYPreventRecall",@"消息防撤回",@"保留本机已取得的对方消息，在原聊天标记撤回时间"],@[@"DYYYRecallShowMarker",@"显示撤回提示",@"在对应原消息下沿显示对方已撤回与发现时间"],@[@"DYYYRecallKeepMedia",@"保留媒体副本",@"另存已取得的本机媒体文件，单文件64MB、总计512MB上限"]]){
        AWESettingItemModel *item=[DYYYSettingsHelper createSettingItem:@{@"identifier":row[0],@"title":row[1],@"subTitle":row[2],@"cellType":@37,@"imageName":@"ic_comment_outlined_20"}];
        void(^original)(void)=item.switchChangedBlock;item.switchChangedBlock=^{if(original)original();[self settingsChanged];};[items addObject:item];
    }
    AWESettingItemModel *status=[DYYYSettingsHelper createSettingItem:@{@"identifier":@"DYYYRecallStatus",@"title":@"留存状态",@"detail":[self shared].status?:@"",@"cellType":@26,@"imageName":@"ic_clock_outlined_20"}];
    __weak AWESettingItemModel *weakStatus=status;
    status.cellTappedBlock=^{NSString *account=[DYYYIMService capturedAccountID];[[self shared].store statisticsForAccount:account completion:^(NSDictionary *stats){[self shared].statistics=stats;dispatch_async(dispatch_get_main_queue(),^{weakStatus.detail=[NSString stringWithFormat:@"%@条记录 / %@条撤回 / %.1fMB",stats[@"records"]?:@0,stats[@"recalled"]?:@0,[stats[@"mediaBytes"] doubleValue]/1048576];[weakStatus refreshCell];});}];};[items addObject:status];
    AWESettingItemModel *clear=[DYYYSettingsHelper createSettingItem:@{@"identifier":@"DYYYRecallClear",@"title":@"清理当前账号留存",@"detail":@"仅清理本插件副本",@"cellType":@26,@"imageName":@"ic_delete_outlined_20"}];
    clear.cellTappedBlock=^{NSString *account=[DYYYIMService capturedAccountID];[DYYYBottomAlertView showAlertWithTitle:@"清理当前账号留存" message:@"将删除本插件保存的消息快照和媒体副本。抖音原消息不受影响。" avatarURL:nil cancelButtonText:@"取消" confirmButtonText:@"清理" cancelAction:nil closeAction:nil confirmAction:^{
        DYYYRecallCoordinator *coordinator=[self shared];coordinator.generation++;[coordinator.cache removeAllObjects];
        for(DYYYRecallUIReference *reference in coordinator.uiReferences)if([reference.account isEqual:account])reference.media=nil;
        [coordinator.store clearAccount:account completion:^(BOOL success){dispatch_async(dispatch_get_main_queue(),^{coordinator.status=success?@"当前账号留存已清理":@"清理失败，原副本保留";for(UITableViewCell *cell in coordinator.cells)[self refreshCell:cell];[DYYYUtils showToast:coordinator.status];});}];
    }];};[items addObject:clear];return items;
}
+ (NSDictionary *)diagnostics {
    if(!NSThread.isMainThread)return @{};
    DYYYRecallCoordinator *coordinator=[self shared];
    return @{@"enabled":@(coordinator.active),@"hooks":[coordinator.hooks copy],@"status":coordinator.status?:@"",@"statistics":coordinator.statistics?:@{},@"savedSnapshots":@(coordinator.savedSnapshots),@"protectedModels":@(coordinator.protectedModels),@"nativeReadHooks":@NO,@"historyQueries":@0,@"mediaLimitMB":@512,@"recordLimit":@5000};
}
@end
