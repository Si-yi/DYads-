#import <Foundation/Foundation.h>

// 目录只保存类型身份与首次名称，不保存作品、作者或消息数据。
@interface DYYYPlaybackCatalogStore : NSObject
+ (instancetype)sharedStore;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
+ (NSInteger)modeFromValue:(id)value;
+ (NSString *)masterKey:(NSUInteger)kind;
+ (NSString *)itemKey:(NSUInteger)kind identifier:(NSString *)identifier;
+ (NSDictionary *)descriptorWithKind:(NSUInteger)kind identifier:(NSString *)identifier title:(NSString *)title;
- (NSArray<NSDictionary *> *)entries:(NSUInteger)kind;
- (BOOL)record:(NSDictionary *)entry;
- (NSInteger)modeForEntry:(NSDictionary *)entry;
- (NSInteger)masterMode:(NSUInteger)kind;
- (void)reload;
@end
