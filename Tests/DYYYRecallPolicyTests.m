#import <Foundation/Foundation.h>
#import "DYYYRecallPolicy.h"
#include <math.h>
@interface DYYYRecallUnknown : NSObject @end
@implementation DYYYRecallUnknown
- (NSString *)description { [NSException raise:@"Unsafe" format:@"不能读未知模型"];return nil; }
@end
@interface DYYYRecallPolicyTests : NSObject @end
@implementation DYYYRecallPolicyTests
+ (void)check:(BOOL)value reason:(NSString *)reason { if(!value)[NSException raise:@"RegressionFailure" format:@"%@",reason]; }
+ (void)run {
    NSMutableDictionary *input=[@{@"text":@"original",@"resource_url":@{@"url_list":@[@"https://example.test/a"]}} mutableCopy];
    NSDictionary *copy=[DYYYRecallPolicy contentSnapshot:input];input[@"text"]=@"changed";
    [self check:[copy[@"text"] isEqual:@"original"] reason:@"原内容快照不被后续原生字典修改"];
    [self check:![DYYYRecallPolicy contentSnapshot:@{@"text":@"Recall Content Hided"}] reason:@"撤回占位不冒充原文"];
    [self check:![DYYYRecallPolicy contentSnapshot:@{@"bad":[DYYYRecallUnknown new]}] reason:@"拒绝未知SDK对象，不执行其getter或description"];
    [self check:![DYYYRecallPolicy contentSnapshot:@{@"bad":@(NAN)}] reason:@"非JSON数值不进入本地库"];
    [self check:![DYYYRecallPolicy canProtectAccount:@"a" sender:@"a" conversation:@"c" message:@"m" content:copy] reason:@"不拦截自己撤回"];
    [self check:![DYYYRecallPolicy canProtectAccount:@"" sender:@"b" conversation:@"c" message:@"m" content:copy] reason:@"账号未知不得拦截"];
    [self check:![DYYYRecallPolicy canProtectAccount:@"a" sender:@"b" conversation:@"" message:@"m" content:copy] reason:@"会话身份未知不得拦截"];
    [self check:[DYYYRecallPolicy canProtectAccount:@"a" sender:@"b" conversation:@"c" message:@"m" content:copy] reason:@"身份和原内容确认后允许保护"];
    [self check:![[DYYYRecallPolicy keyForAccount:@"a/b" conversation:@"c" message:@"d"] isEqual:[DYYYRecallPolicy keyForAccount:@"a" conversation:@"b/c" message:@"d"]] reason:@"身份分隔符不会造成跨会话碰撞"];
    NSMutableArray *deep=[NSMutableArray array];for(NSUInteger i=0;i<300;i++)[deep addObject:@"x"];
    [self check:![DYYYRecallPolicy contentSnapshot:@{@"items":deep}] reason:@"回调内快照限制数组容量"];
    [self check:![DYYYRecallPolicy contentSnapshot:@{@"type":@1,@"message_id":@"m"}] reason:@"类型或编号本身不能冒充消息原内容"];
    [self check:[[DYYYRecallPolicy fingerprint:@{@"b":@2,@"a":@1}] isEqual:[DYYYRecallPolicy fingerprint:@{@"a":@1,@"b":@2}]] reason:@"去重摘要不受字典顺序影响"];
    NSLog(@"DYYYRecallPolicy regression tests passed");
}
@end
int main(void){@autoreleasepool{[DYYYRecallPolicyTests run];}return 0;}
