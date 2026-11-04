#import <Foundation/Foundation.h>
#import "DYYYUnreadProbe.h"

int main(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id saved = [defaults objectForKey:@"DYYYDebugInspectorEnabled"];
        [defaults setBool:YES forKey:@"DYYYDebugInspectorEnabled"];
        [DYYYUnreadProbe recordReceiver:defaults input:@"not_recorded" result:nil selector:@selector(objectForKey:)];
        NSDictionary *state = [DYYYUnreadProbe diagnostics];
        if (![state[@"suspended"] boolValue] || [state[@"enabled"] boolValue] ||
            [state[@"installed"] count] || [state[@"observations"] count] || [DYYYUnreadProbe observedClassNames].count)
            [NSException raise:@"RegressionFailure" format:@"生产隔离宏必须覆盖旧的调试偏好，且不记录调用"];
        if (saved) [defaults setObject:saved forKey:@"DYYYDebugInspectorEnabled"];
        else [defaults removeObjectForKey:@"DYYYDebugInspectorEnabled"];
        NSLog(@"DYYYUnreadIsolation regression tests passed");
    }
    return 0;
}
