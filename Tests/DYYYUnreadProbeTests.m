#import <Foundation/Foundation.h>
#import "DYYYUnreadProbe.h"

@interface DYYYUnreadProbeDouble : NSObject
- (id)echo:(id)object;
- (id)scalar:(long long)value;
- (BOOL)flag:(id)object;
@end
@implementation DYYYUnreadProbeDouble
- (id)echo:(id)object { return object; }
- (id)scalar:(long long)value { return nil; }
- (BOOL)flag:(id)object { return YES; }
- (NSString *)description { [NSException raise:@"UnsafeDescription" format:@"不得读取描述或正文"]; return nil; }
@end
@interface DYYYUnreadProbeTests : NSObject
+ (void)run;
@end
@implementation DYYYUnreadProbeTests
+ (void)check:(BOOL)condition reason:(NSString *)reason {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason];
}
+ (void)run {
    Class cls = DYYYUnreadProbeDouble.class;
    [self check:[DYYYUnreadProbe canObserveClass:cls selector:@selector(echo:) arguments:3 result:'@'] reason:@"确认对象参数与返回类型后才允许安装"];
    [self check:![DYYYUnreadProbe canObserveClass:cls selector:@selector(echo:) arguments:4 result:'@'] reason:@"参数数量不符禁止安装"];
    [self check:![DYYYUnreadProbe canObserveClass:cls selector:@selector(scalar:) arguments:3 result:'@'] reason:@"整数参数不能按对象访问"];
    [self check:![DYYYUnreadProbe canObserveClass:cls selector:@selector(flag:) arguments:3 result:'@'] reason:@"布尔返回不能当对象读取"];
    [self check:![DYYYUnreadProbe canObserveClass:Nil selector:@selector(echo:) arguments:3 result:'@'] reason:@"类缺失时不安装"];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id saved = [defaults objectForKey:@"DYYYDebugInspectorEnabled"];
    [defaults setBool:NO forKey:@"DYYYDebugInspectorEnabled"];
    DYYYUnreadProbeDouble *object = [DYYYUnreadProbeDouble new];
    [DYYYUnreadProbe recordReceiver:object input:object result:object selector:@selector(echo:)];
    [self check:[[DYYYUnreadProbe diagnostics][@"observations"] count] == 0 reason:@"调试关闭不记录"];
    [defaults setBool:YES forKey:@"DYYYDebugInspectorEnabled"];
    [DYYYUnreadProbe recordReceiver:object input:@"private-message-123" result:object selector:@selector(echo:)];
    [DYYYUnreadProbe recordReceiver:object input:@"private-message-456" result:object selector:@selector(echo:)];
    NSArray *rows = [DYYYUnreadProbe diagnostics][@"observations"];
    [self check:rows.count == 1 && [rows[0][@"calls"] unsignedIntegerValue] == 2 reason:@"同类型记录合并，不保留传入内容"];
    NSData *json = [NSJSONSerialization dataWithJSONObject:[DYYYUnreadProbe diagnostics] options:0 error:nil];
    NSString *text = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    [self check:![text containsString:@"private-message"] reason:@"导出不含消息正文，不调用描述方法"];
    for (NSUInteger index = 0; index < 100; index++) {
        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"observed%lu:", (unsigned long)index]);
        [DYYYUnreadProbe recordReceiver:object input:nil result:nil selector:selector];
    }
    [self check:[[DYYYUnreadProbe diagnostics][@"observations"] count] == 32 reason:@"内存记录有固定上限"];
    [self check:[[DYYYUnreadProbe observedClassNames] containsObject:NSStringFromClass(cls)] reason:@"实际模型类可加入接口导出"];
    [self check:![[DYYYUnreadProbe diagnostics][@"timeFilterActive"] boolValue] reason:@"接口检查不能冒充已实现时间过滤"];
    if (saved) [defaults setObject:saved forKey:@"DYYYDebugInspectorEnabled"];
    else [defaults removeObjectForKey:@"DYYYDebugInspectorEnabled"];
    NSLog(@"DYYYUnreadProbe regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYUnreadProbeTests run]; } return 0; }
