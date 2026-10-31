#import <Foundation/Foundation.h>
@class AWESettingItemModel;

@interface DYYYUnreadExpiry : NSObject
+ (void)installHooks;
+ (void)settingsChanged;
+ (void)schedule;
+ (void)learnConversation:(id)conversation receiver:(id)receiver mode:(unsigned long long)mode completion:(id)completion;
+ (void)observeHintType:(long long)hint manager:(id)manager;
+ (BOOL)matchesClass:(Class)cls selector:(SEL)selector arguments:(NSString *)arguments;
+ (NSArray<AWESettingItemModel *> *)settingsItems;
+ (NSDictionary *)diagnostics;
@end
