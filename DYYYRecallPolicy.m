#import "DYYYRecallPolicy.h"
#include <math.h>
#import <CommonCrypto/CommonDigest.h>

@implementation DYYYRecallPolicy
+ (NSString *)fingerprint:(NSDictionary *)record {
    NSData *data=[NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingSortedKeys error:nil];
    if(!data)return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
    return [[NSData dataWithBytes:digest length:sizeof(digest)] base64EncodedStringWithOptions:0];
}

+ (id)copyJSON:(id)value depth:(NSUInteger)depth budget:(NSUInteger *)budget {
    if (!*budget || depth > 12) return nil;
    (*budget)--;
    if ([value isKindOfClass:NSString.class]) return [value length] <= 65536 ? [value copy] : nil;
    if ([value isKindOfClass:NSNumber.class]) return isfinite([value doubleValue]) ? value : nil;
    if (value == NSNull.null) return value;
    if ([value isKindOfClass:NSArray.class]) {
        if ([value count] > 256) return nil;
        NSMutableArray *result = [NSMutableArray array];
        for (id child in value) { id copy = [self copyJSON:child depth:depth + 1 budget:budget]; if (!copy) return nil; [result addObject:copy]; }
        return [result copy];
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        if ([value count] > 256) return nil;
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        for (id key in value) {
            if (![key isKindOfClass:NSString.class] || [key length] > 256) return nil;
            id copy = [self copyJSON:value[key] depth:depth + 1 budget:budget]; if (!copy) return nil;
            result[[key copy]] = copy;
        }
        return [result copy];
    }
    return nil; // 不调用未知原生对象的 description / getter / 序列化。
}
+ (BOOL)hasPayload:(NSDictionary *)content depth:(NSUInteger)depth {
    if(depth>6)return NO;
    for(NSString *key in @[@"text",@"title",@"resource_url",@"url",@"url_list",@"uri",@"image",@"images",@"image_url",@"origin_url",@"video",@"audio",@"sticker",@"animated_url",@"display_name",@"itemId",@"aweme_id",@"location"]){
        id value=content[key];
        if(([value isKindOfClass:NSString.class] && [value length]) || ([value isKindOfClass:NSDictionary.class] && [value count]) || ([value isKindOfClass:NSArray.class] && [value count]) || ([value isKindOfClass:NSNumber.class] && [value longLongValue]>0))return YES;
    }
    return [content[@"content"] isKindOfClass:NSDictionary.class] && [self hasPayload:content[@"content"] depth:depth+1];
}
+ (NSDictionary *)contentSnapshot:(id)content {
    if (![content isKindOfClass:NSDictionary.class] || ![content count]) return nil;
    NSUInteger budget = 2048;
    NSDictionary *copy = nil;
    @try { copy = [self copyJSON:content depth:0 budget:&budget]; } @catch (__unused NSException *exception) { return nil; }
    if (!copy || [self isRecallPlaceholder:copy] || ![self hasPayload:copy depth:0]) return nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:copy options:0 error:nil];
    return data.length && data.length <= 256 * 1024 ? copy : nil;
}
+ (BOOL)isRecallPlaceholder:(id)content {
    return [content isKindOfClass:NSDictionary.class] && [content[@"text"] isKindOfClass:NSString.class] &&
        [content[@"text"] isEqualToString:@"Recall Content Hided"];
}
+ (BOOL)validIdentity:(id)value {
    return [value isKindOfClass:NSString.class] && [value length] && [value length] <= 512 && ![value isEqual:@"0"];
}
+ (BOOL)canProtectAccount:(NSString *)account sender:(NSString *)sender conversation:(NSString *)conversation message:(NSString *)message content:(NSDictionary *)content {
    return [self validIdentity:account] && [self validIdentity:sender] && ![account isEqual:sender] &&
        [self validIdentity:conversation] && [self validIdentity:message] && content.count > 0 && ![self isRecallPlaceholder:content];
}
+ (NSString *)keyForAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message {
    if (![self validIdentity:account] || ![self validIdentity:conversation] || ![self validIdentity:message]) return nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[account, conversation, message] options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}
+ (NSString *)textForContent:(NSDictionary *)content {
    if ([self isRecallPlaceholder:content]) return @"";
    id text = content[@"text"];
    return [text isKindOfClass:NSString.class] ? text : @"";
}
@end
