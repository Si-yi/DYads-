#import "DYYYCommentMenuItems.h"

@protocol DYYYCommentMenuElementContent <NSObject>
- (id)elementContent;
@end

@implementation DYYYCommentMenuItems
+ (NSArray *)visibleModels:(NSArray *)models hidingFavorites:(BOOL)hide {
    if (!hide || ![models isKindOfClass:NSArray.class]) return models;
    NSMutableArray *visible = [NSMutableArray arrayWithCapacity:models.count];
    for (id model in models) {
        id content = [model respondsToSelector:@selector(elementContent)] ? [(id<DYYYCommentMenuElementContent>)model elementContent] : nil;
        NSString *title = [content isKindOfClass:NSAttributedString.class] ? [content string] :
            ([content isKindOfClass:NSString.class] ? content : nil);
        title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([title isEqualToString:@"收藏"] || [title isEqualToString:@"取消收藏"] || [title isEqualToString:@"已收藏"]) continue;
        [visible addObject:model];
    }
    return visible.count == models.count ? models : [visible copy];
}
+ (NSArray *)orderedModelsInSections:(NSArray<NSArray *> *)sections {
    NSMutableArray *normal = [NSMutableArray array];
    NSMutableArray *reports = [NSMutableArray array];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (NSArray *models in sections) {
        if (![models isKindOfClass:NSArray.class]) continue;
        for (id model in models) {
            if ([seen containsObject:model]) continue;
            [seen addObject:model];
            id content = [model respondsToSelector:@selector(elementContent)] ? [(id<DYYYCommentMenuElementContent>)model elementContent] : nil;
            NSString *title = [content isKindOfClass:NSAttributedString.class] ? [content string] :
                ([content isKindOfClass:NSString.class] ? content : nil);
            if ([[title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqualToString:@"举报"])
                [reports addObject:model];
            else [normal addObject:model];
        }
    }
    [normal addObjectsFromArray:reports];
    return [normal copy];
}
@end
