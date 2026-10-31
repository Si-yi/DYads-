#import "AwemeHeaders.h"
#import "DYYYUnreadProbe.h"

%group DYYYUnreadHintProbe
%hook AWEIMBaseUnreadMessagesConsumer
- (id)generateHintModelForConversation:(id)conversation filterOptions:(id)options {
    id result = %orig(conversation, options);
    [DYYYUnreadProbe recordReceiver:self input:options result:result selector:_cmd];
    return result;
}
%end
%end

%group DYYYUnreadFilterProbe
%hook AWEIMBaseUnreadMessagesConsumer
- (id)targetFilterOptionsForUnreadMessagesInChat:(id)chat {
    id result = %orig(chat);
    [DYYYUnreadProbe recordReceiver:self input:chat result:result selector:_cmd];
    return result;
}
%end
%end

%group DYYYUnreadCellProbe
%hook AWEIMChatListCommonCell
- (void)renderWithHolder:(id)holder {
    %orig(holder);
    [DYYYUnreadProbe recordReceiver:self input:holder result:nil selector:_cmd];
}
%end
%end

@implementation DYYYUnreadProbe (Hooks)
+ (void)installHooks {
    if (!NSThread.isMainThread || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYDebugInspectorEnabled"]) return;
    static BOOL hint, filter, cell;
    Class consumer = NSClassFromString(@"AWEIMBaseUnreadMessagesConsumer");
    if (!hint && [self canObserveClass:consumer selector:@selector(generateHintModelForConversation:filterOptions:) arguments:4 result:'@']) {
        %init(DYYYUnreadHintProbe);
        hint = YES;
        [self didInstall:@"native_hint_model"];
    }
    if (!filter && [self canObserveClass:consumer selector:@selector(targetFilterOptionsForUnreadMessagesInChat:) arguments:3 result:'@']) {
        %init(DYYYUnreadFilterProbe);
        filter = YES;
        [self didInstall:@"native_filter_options"];
    }
    Class cls = NSClassFromString(@"AWEIMChatListCommonCell");
    if (!cell && [self canObserveClass:cls selector:@selector(renderWithHolder:) arguments:3 result:'v']) {
        %init(DYYYUnreadCellProbe);
        cell = YES;
        [self didInstall:@"native_cell_holder"];
    }
}
@end
