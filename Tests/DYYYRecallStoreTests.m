#import <Foundation/Foundation.h>
#import "DYYYRecallStore.h"
#import "DYYYRecallPolicy.h"

@interface DYYYRecallStoreTests : NSObject @end
@implementation DYYYRecallStoreTests
+ (void)check:(BOOL)value reason:(NSString *)reason { if(!value)[NSException raise:@"RegressionFailure" format:@"%@",reason]; }
+ (void)wait:(dispatch_semaphore_t)semaphore { [self check:dispatch_semaphore_wait(semaphore,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC))==0 reason:@"异步留存必须返回结果"]; }
+ (NSDictionary *)save:(NSDictionary *)record store:(DYYYRecallStore *)store {
    dispatch_semaphore_t semaphore=dispatch_semaphore_create(0);__block NSDictionary *saved;
    [store saveRecord:record completion:^(NSDictionary *result,NSString *error){saved=result;dispatch_semaphore_signal(semaphore);}];[self wait:semaphore];return saved;
}
+ (NSDictionary *)read:(DYYYRecallStore *)store account:(NSString *)account message:(NSString *)message server:(NSString *)server {
    dispatch_semaphore_t semaphore=dispatch_semaphore_create(0);__block NSDictionary *result;
    [store recordForAccount:account conversation:@"c" message:message server:server completion:^(NSDictionary *record){result=record;dispatch_semaphore_signal(semaphore);}];[self wait:semaphore];return result;
}
+ (void)run {
    NSURL *base=[[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:[@"DYadsRecallTests-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    DYYYRecallStore *store=[[DYYYRecallStore alloc]initWithDirectory:[base URLByAppendingPathComponent:@"Store"]];
    NSDictionary *record=@{@"account":@"a",@"conversation":@"c",@"message":@"local",@"server":@"123",@"sender":@"b",@"content":@{@"text":@"original"},@"uiClass":@"AWEIMTextMessage",@"recalled":@NO};
    [self check:[self save:record store:store]!=nil reason:@"保存真实消息快照"];
    NSMutableDictionary *recall=[record mutableCopy];recall[@"recalled"]=@YES;recall[@"recalledAt"]=@100;recall[@"content"]=@{@"text":@"Recall Content Hided"};
    NSDictionary *saved=[self save:recall store:store];[self check:[saved[@"content"][@"text"] isEqual:@"original"] && [saved[@"recalled"] boolValue] reason:@"撤回占位不能覆盖已保存原文"];
    [self save:record store:store];saved=[self read:store account:@"a" message:@"different-ui-id" server:@"123"];
    [self check:[saved[@"recalled"] boolValue] && [saved[@"recalledAt"] intValue]==100 reason:@"迟到普通更新不取消撤回标记，支持同账号服务器ID对齐"];
    [self check:[saved[@"uiClass"] isEqual:@"AWEIMTextMessage"] reason:@"SDK更新不能丢失已学到的原生UI类型"];
    [self check:![self read:store account:@"other-account" message:@"local" server:@"123"] reason:@"相同消息ID不能跨账号读取"];
    DYYYRecallStore *reopened=[[DYYYRecallStore alloc]initWithDirectory:[base URLByAppendingPathComponent:@"Store"]];
    [self check:[[self read:reopened account:@"a" message:@"local" server:@"123"][@"content"][@"text"] isEqual:@"original"] reason:@"重开留存库仍有真实原内容"];
    NSURL *image=[base URLByAppendingPathComponent:@"original-file-without-extension"];
    NSData *png=[[NSData alloc]initWithBase64EncodedString:@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=" options:0];[png writeToURL:image atomically:YES];
    dispatch_semaphore_t semaphore=dispatch_semaphore_create(0);__block NSDictionary *media;
    [store copyMediaAtPath:image.path record:record completion:^(NSDictionary *result,NSString *error){media=result;dispatch_semaphore_signal(semaphore);}];[self wait:semaphore];
    [self check:media!=nil && ![media[@"path"] isEqual:image.path] reason:@"真实图片单独复制，原缓存无扩展名仍可识别"];
    [NSFileManager.defaultManager removeItemAtURL:image error:nil];
    [self check:[[NSData dataWithContentsOfFile:media[@"path"]] isEqual:png] reason:@"删除抖音原缓存后独立媒体副本仍完整存在"];
    saved=[self read:reopened account:@"a" message:@"local" server:@"123"];
    [self check:[saved[@"media"] count]==1 reason:@"重开后恢复真实存在的媒体映射"];
    NSURL *fake=[base URLByAppendingPathComponent:@"not-real-image.jpg"];[@"not an image" writeToURL:fake atomically:YES encoding:NSUTF8StringEncoding error:nil];media=nil;semaphore=dispatch_semaphore_create(0);
    [store copyMediaAtPath:fake.path record:record completion:^(NSDictionary *result,NSString *error){media=result;dispatch_semaphore_signal(semaphore);}];[self wait:semaphore];[self check:!media reason:@"仅有图片扩展名或无法解码不能谎报保存成功"];
    semaphore=dispatch_semaphore_create(0);__block BOOL cleared=NO;
    [store clearAccount:@"a" completion:^(BOOL success){cleared=success;dispatch_semaphore_signal(semaphore);}];[self wait:semaphore];
    [self check:cleared && ![self read:store account:@"a" message:@"local" server:@"123"] reason:@"显式清理后记录消失"];
    [self check:![self save:record store:store] reason:@"迟到回调不能重新写回用户清理过的留存"];
    NSMutableDictionary *alias=[record mutableCopy];alias[@"message"]=@"new-local-id";
    [self check:![self save:alias store:store] reason:@"换成本机新ID也不能按相同服务器ID回灌已清理记录"];
    [NSFileManager.defaultManager removeItemAtURL:base error:nil];
    NSLog(@"DYYYRecallStore regression tests passed");
}
@end
int main(void){@autoreleasepool{[DYYYRecallStoreTests run];}return 0;}
