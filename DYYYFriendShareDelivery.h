#import <Foundation/Foundation.h>

@interface DYYYFriendShareDelivery : NSObject
/// 一次生成新列表，保留原视频顺序、去重，不依赖首页是否可见。
+ (NSArray *)feedWithOriginal:(NSArray *)original sharedModels:(NSDictionary *)models orderedIDs:(NSArray<NSString *> *)orderedIDs;
/// 补入迟到批次时同时排除已刷缓存与旧列表，只保留仍显示的当前已刷 Cell。
+ (NSArray *)feedWithOriginal:(NSArray *)original sharedModels:(NSDictionary *)models orderedIDs:(NSArray<NSString *> *)orderedIDs
                  watchedIDs:(NSSet<NSString *> *)watchedIDs currentItemID:(NSString *)currentItemID;
/// 在当前浏览位置前/后插入分享，保留此前的普通视频历史在当前位置之前。
+ (NSArray *)feedWithOriginal:(NSArray *)original sharedModels:(NSDictionary *)models orderedIDs:(NSArray<NSString *> *)orderedIDs
                  watchedIDs:(NSSet<NSString *> *)watchedIDs currentItemID:(NSString *)currentItemID
                anchorItemID:(NSString *)anchorItemID insertAfterAnchor:(BOOL)afterAnchor;
/// 通过原生数据源 setter 一次替换列表，再重算供首页播放的过滤列表。
+ (BOOL)replaceFeed:(NSArray *)feed controller:(id)controller;
/// 重载原生表格，再同步目标索引，避免只更新数据源仍显示旧 Cell。
+ (BOOL)reloadFeed:(id)feed atIndex:(NSUInteger)index;
/// 只准备并播放身份匹配的 Cell；allowed 由首页可见性及用户操作校验决定。
+ (BOOL)prepareAndPlayCell:(id)cell itemID:(NSString *)itemID allowed:(BOOL)allowed;
@end
