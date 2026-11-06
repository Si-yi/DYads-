#import <Foundation/Foundation.h>

@interface DYYYRecallPolicy : NSObject
+ (NSDictionary *)contentSnapshot:(id)content;
+ (BOOL)isRecallPlaceholder:(id)content;
+ (BOOL)canProtectAccount:(NSString *)account sender:(NSString *)sender conversation:(NSString *)conversation message:(NSString *)message content:(NSDictionary *)content;
+ (NSString *)keyForAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message;
+ (NSString *)textForContent:(NSDictionary *)content;
@end
