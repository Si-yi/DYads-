#import <Foundation/Foundation.h>
#import "DYYYPlaybackCatalogStore.h"

@interface DYYYPlaybackCatalogStoreTests : NSObject
+ (void)check:(BOOL)condition reason:(NSString *)reason;
@end
@implementation DYYYPlaybackCatalogStoreTests
+ (void)check:(BOOL)condition reason:(NSString *)reason { if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", reason]; }
+ (void)run {
    NSString *suite = [@"DYYY.CatalogTests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    [defaults setBool:YES forKey:@"DYYYHideFeedAnchorContainer"];
    [defaults setBool:YES forKey:@"DYYYHideTemplateVideo"];
    DYYYPlaybackCatalogStore *store = [[DYYYPlaybackCatalogStore alloc] initWithDefaults:defaults];
    [self check:[store masterMode:0] == 2 reason:@"旧锚点总开关升级为移除"];
    [defaults setObject:@"显示" forKey:[DYYYPlaybackCatalogStore masterKey:0]];
    [store reload];
    [self check:[store masterMode:0] == 0 reason:@"重新载入不得覆盖用户新总档位"];
    NSDictionary *collection = [DYYYPlaybackCatalogStore descriptorWithKind:1 identifier:@"video_collection" title:@"不同作品名称"];
    [self check:[collection[@"title"] isEqual:@"视频合集"] && [store modeForEntry:collection] == 2 reason:@"保留旧合集开关和语义名"];
    NSString *collectionKey = [DYYYPlaybackCatalogStore itemKey:1 identifier:collection[@"id"]];
    [defaults setObject:@"隐藏" forKey:collectionKey];
    [self check:[store modeForEntry:collection] == 1 reason:@"新单项档位优先旧布尔值"];
    [defaults setObject:@"移除" forKey:[DYYYPlaybackCatalogStore masterKey:1]];
    [self check:[store modeForEntry:collection] == 2 reason:@"总档位覆盖显示，但不修改单项偏好"];
    [defaults setObject:@"显示" forKey:[DYYYPlaybackCatalogStore masterKey:1]];
    [self check:[store modeForEntry:collection] == 1 reason:@"恢复总显示保留单项隐藏"];
    [self check:![DYYYPlaybackCatalogStore descriptorWithKind:0 identifier:@"openplatform_anchor" title:@"应用"] reason:@"开放平台缺少 client_key 不合并"];
    NSDictionary *app = [DYYYPlaybackCatalogStore descriptorWithKind:0 identifier:@"openplatform_anchor:a" title:@"第一个应用"];
    NSDictionary *other = [DYYYPlaybackCatalogStore descriptorWithKind:0 identifier:@"openplatform_anchor:b" title:@"第二个应用"];
    [self check:[store record:app] && [store record:other] reason:@"不同应用身份分开收录"];
    [self check:![store record:[DYYYPlaybackCatalogStore descriptorWithKind:0 identifier:@"openplatform_anchor:a" title:@"作品换名"]] reason:@"作品变化不产生新目录项，不改首次名称"];
    [self check:[store entries:0].count == 3 reason:@"预置旧定位项与两个应用，不按作品累积"];
    [self check:![DYYYPlaybackCatalogStore descriptorWithKind:8 identifier:@"x" title:@"名称"] && ![DYYYPlaybackCatalogStore descriptorWithKind:0 identifier:@"x" title:nil] reason:@"拒绝非法分组和无语义名称"];
    [self check:[DYYYPlaybackCatalogStore modeFromValue:@"YES"] == 0 && [DYYYPlaybackCatalogStore modeFromValue:@3] == 0 && [DYYYPlaybackCatalogStore modeFromValue:NSNull.null] == 0 reason:@"无效旧备份值安全回退显示"];
    [self check:[DYYYPlaybackCatalogStore modeFromValue:@2] == 2 reason:@"兼容合法数值档位"];
    [self check:![[DYYYPlaybackCatalogStore itemKey:0 identifier:@"a:b"] isEqual:[DYYYPlaybackCatalogStore itemKey:0 identifier:@"a%3Ab"]] reason:@"编码身份不冲突"];
    for (NSUInteger i = 0; i < 600; i++) [store record:[DYYYPlaybackCatalogStore descriptorWithKind:0 identifier:[NSString stringWithFormat:@"type%lu", (unsigned long)i] title:@"长驻类型"]];
    [self check:[store entries:0].count == 512 reason:@"动态目录容量上限"];
    [store reload];
    [self check:[store entries:0].count == 512 reason:@"重启保存且不重复"];
    // 模拟恢复旧备份：旧全局与旧单项仍保留，新的档位键不存在。
    [defaults removePersistentDomainForName:suite];
    [defaults setBool:YES forKey:@"DYYYHideFeedAnchorContainer"];
    [defaults setBool:YES forKey:@"DYYYHideBottomRelated"];
    [store reload];
    NSDictionary *related = [DYYYPlaybackCatalogStore descriptorWithKind:1 identifier:@"AWEPlayInteractionRelatedVideoNewBottomElement" title:nil];
    [self check:[store masterMode:0] == 2 && [store modeForEntry:related] == 2 reason:@"旧备份重新迁移，底部相关只迁移对应类型"];
    [self check:[store masterMode:1] == 0 reason:@"旧底部相关开关不扩大成全部栏目隐藏"];
    [defaults removePersistentDomainForName:suite];
    NSLog(@"DYYYPlaybackCatalogStore regression tests passed");
}
@end
int main(void) { @autoreleasepool { [DYYYPlaybackCatalogStoreTests run]; } return 0; }
