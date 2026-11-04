#import "DYYYChatEnhancementPolicy.h"
#import <objc/runtime.h>
#include <string.h>

@implementation DYYYChatEnhancementPolicy
+ (BOOL)type:(const char *)type matches:(char)expected {
    if (!type || !*type) return NO;
    while (*type && strchr("rnNoORV", *type)) type++;
    if (expected == '@') return *type == '@' && type[1] != '?';
    if (expected == 'B') return *type == 'B' || *type == 'c';
    return *type == expected && type[1] == '\0';
}
+ (BOOL)signature:(NSMethodSignature *)signature result:(char)result arguments:(NSString *)arguments {
    if (!signature || signature.numberOfArguments != arguments.length + 2 ||
        ![self type:signature.methodReturnType matches:result]) return NO;
    for (NSUInteger i = 0; i < arguments.length; i++)
        if (![self type:[signature getArgumentTypeAtIndex:i + 2] matches:(char)[arguments characterAtIndex:i]]) return NO;
    return YES;
}
+ (BOOL)class:(Class)cls selector:(SEL)selector result:(char)result arguments:(NSString *)arguments {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;
    if (!encoding) return NO;
    @try { return [self signature:[NSMethodSignature signatureWithObjCTypes:encoding] result:result arguments:arguments]; }
    @catch (__unused NSException *exception) { return NO; }
}
@end

@interface DYYYChatTranslationLedger ()
@property (nonatomic, copy) NSString *account;
@property (nonatomic, strong) NSMutableSet<NSArray<NSString *> *> *keys;
@end
@implementation DYYYChatTranslationLedger
- (BOOL)reserveAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message {
    // 不把缺失 ID 合并为同一个对象；切账号后不复用另一账号的去重状态。
    for (id value in @[account ?: @"", conversation ?: @"", message ?: @""])
        if (![value isKindOfClass:NSString.class] || ![value length] || [value length] > 512) return NO;
    if (![self.account isEqual:account]) { self.account = account; self.keys = [NSMutableSet set]; }
    NSArray *key = @[conversation, message];
    if (self.keys.count >= 256 || [self.keys containsObject:key]) return NO;
    [self.keys addObject:key];
    return YES;
}
- (NSUInteger)count { return self.keys.count; }
@end
