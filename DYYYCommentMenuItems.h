#import <Foundation/Foundation.h>

@interface DYYYCommentMenuItems : NSObject
+ (NSArray *)visibleModels:(NSArray *)models hidingFavorites:(BOOL)hide;
+ (NSArray *)orderedModelsInSections:(NSArray<NSArray *> *)sections;
@end
