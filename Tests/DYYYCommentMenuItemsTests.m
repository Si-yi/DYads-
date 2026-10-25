#import <Foundation/Foundation.h>
#import "DYYYCommentMenuItems.h"

@interface MenuItem : NSObject
@property (nonatomic, strong) id elementContent;
@property (nonatomic, copy) void (^action)(void);
@end
@implementation MenuItem
@end

int main(void) {
    @autoreleasepool {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *title in @[ @"转发评论到日常", @"复制该评论", @"收藏", @"保存到相册", @"举报", @"发作品回复", @"搜索" ]) {
            MenuItem *item = [MenuItem new];
            item.elementContent = title;
            [items addObject:item];
        }
        __block NSUInteger calls = 0;
        ((MenuItem *)items[4]).action = ^{ calls++; };
        NSArray *a = [items subarrayWithRange:NSMakeRange(0, 4)];
        NSArray *b = @[ items[4] ];
        NSArray *c = [items subarrayWithRange:NSMakeRange(5, 2)];
        NSArray *ordered = [DYYYCommentMenuItems orderedModelsInSections:@[ a, b, c ]];
        NSArray *expected = @[ items[0], items[1], items[2], items[3], items[5], items[6], items[4] ];
        NSCAssert([ordered isEqualToArray:expected], @"Cross-section pairing must place report after all other actions");
        NSCAssert(a.count == 4 && b[0] == items[4] && c[0] == items[5], @"Source arrays must not be mutated");
        NSCAssert(ordered.lastObject == items[4], @"Move the native object, not a copied action");
        ((MenuItem *)ordered.lastObject).action();
        NSCAssert(calls == 1, @"The original action remains bound to the moved model");
        NSDictionary *attributes = @{ @"nativeColor": @"red" };
        NSAttributedString *rich = [[NSAttributedString alloc] initWithString:@"举报" attributes:attributes];
        ((MenuItem *)items[4]).elementContent = rich;
        ordered = [DYYYCommentMenuItems orderedModelsInSections:@[ b, c, a ]];
        NSCAssert(ordered.lastObject == items[4] && ((MenuItem *)ordered.lastObject).elementContent == rich, @"Keep attributed red report content intact");
        NSObject *unknown = [NSObject new];
        ordered = [DYYYCommentMenuItems orderedModelsInSections:@[ @[ unknown ], @[], a, b, c ]];
        NSCAssert(ordered.firstObject == unknown && ordered.count == 8, @"Unknown actions are retained without interpretation");
        ordered = [DYYYCommentMenuItems orderedModelsInSections:@[ a, a, b, c ]];
        NSCAssert(ordered.count == 7, @"The same model from a rendering snapshot must not be inserted twice");
        MenuItem *sameTitle = [MenuItem new];
        sameTitle.elementContent = @"复制该评论";
        ordered = [DYYYCommentMenuItems orderedModelsInSections:@[ @[ items[1], sameTitle ] ]];
        NSCAssert(ordered.count == 2 && ordered[1] == sameTitle, @"Distinct native actions with the same title must both survive");
        NSCAssert([DYYYCommentMenuItems orderedModelsInSections:@[]].count == 0, @"Empty menus remain empty");
        ordered = [DYYYCommentMenuItems orderedModelsInSections:@[ c, a ]];
        NSCAssert(ordered.firstObject == items[5] && ordered.lastObject == items[3], @"Without report, relative order remains unchanged");
        NSLog(@"DYYYCommentMenuItems regression tests passed");
    }
    return 0;
}
