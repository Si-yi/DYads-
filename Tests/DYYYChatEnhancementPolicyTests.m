#import <Foundation/Foundation.h>
#import "DYYYChatEnhancementPolicy.h"

@interface DYYYChatEnhancementPolicyTests : NSObject
+ (void)check:(BOOL)condition reason:(NSString *)reason;
@end
@implementation DYYYChatEnhancementPolicyTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    NSMethodSignature *(^sig)(const char *) = ^NSMethodSignature *(const char *encoding) { return [NSMethodSignature signatureWithObjCTypes:encoding]; };
    [self check:[DYYYChatEnhancementPolicy signature:sig("v32@0:8@16@24") result:'v' arguments:@"@@"] reason:@"允许核对过的两个对象参数"];
    [self check:![DYYYChatEnhancementPolicy signature:sig("v32@0:8@16q24") result:'v' arguments:@"@@"] reason:@"整数不能误当对象调用"];
    [self check:![DYYYChatEnhancementPolicy signature:sig("v24@0:8@?16") result:'v' arguments:@"@"] reason:@"完成回调不能误当普通上下文"];
    [self check:![DYYYChatEnhancementPolicy signature:sig("q16@0:8") result:'B' arguments:@""] reason:@"64位整数不能当布尔 getter"];
    [self check:[DYYYChatEnhancementPolicy signature:sig("c16@0:8") result:'B' arguments:@""] reason:@"支持旧版 Objective-C BOOL 编码"];
    [self check:![DYYYChatEnhancementPolicy signature:sig("v24@0:8@16") result:'v' arguments:@"@@"] reason:@"参数数量不符拒绝"];
    [self check:![DYYYChatEnhancementPolicy class:Nil selector:@selector(description) result:'@' arguments:@""] reason:@"未加载私有类安全跳过"];
    DYYYChatTranslationLedger *ledger = [DYYYChatTranslationLedger new];
    [self check:![ledger reserveAccount:@"" conversation:@"c" message:@"m"] reason:@"账号未初始化不能自动转换"];
    [self check:[ledger reserveAccount:@"A" conversation:@"c" message:@"m"] reason:@"首次可见语音可以转换"];
    [self check:![ledger reserveAccount:@"A" conversation:@"c" message:@"m"] reason:@"Cell复用与重复事件不能重复转换"];
    [self check:[ledger reserveAccount:@"A" conversation:@"other" message:@"m"] reason:@"同消息ID不同会话不能混淆"];
    [self check:[ledger reserveAccount:@"B" conversation:@"c" message:@"m"] && ledger.count == 1 reason:@"切账号清除旧去重状态"];
    for (NSUInteger i = 0; i < 600; i++) [ledger reserveAccount:@"B" conversation:@"c" message:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    [self check:ledger.count == 256 reason:@"长时间翻历史时缓存及自动请求有界"];
    [self check:![ledger reserveAccount:@"B" conversation:@"c" message:@"after_limit"] reason:@"达到限额后不因缓存淘汰反复请求"];
    NSLog(@"DYYYChatEnhancementPolicy regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYChatEnhancementPolicyTests run]; } return 0; }
