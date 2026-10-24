#import <Foundation/Foundation.h>

@interface DYYYFriendShareDelivery : NSObject
/// 一次生成新列表，保留原视频顺序、去重，不依赖首页是否可见。
+ (NSArray *)feedWithOriginal:(NSArray *)original sharedModels:(NSDictionary *)models orderedIDs:(NSArray<NSString *> *)orderedIDs;
/// 只准备并播放身份匹配的 Cell；allowed 由首页可见性及用户操作校验决定。
+ (BOOL)prepareAndPlayCell:(id)cell itemID:(NSString *)itemID allowed:(BOOL)allowed;
@end
