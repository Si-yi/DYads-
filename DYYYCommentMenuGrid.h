#import <UIKit/UIKit.h>

@interface DYYYCommentMenuGrid : NSObject
+ (CGSize)sizeForSection:(id)section index:(NSInteger)index original:(CGSize)original collectionSize:(CGSize)size;
+ (void)configureCell:(UIView *)cell section:(id)section index:(NSInteger)index;
+ (void)restoreContentInCell:(UIView *)cell;
+ (void)layoutCell:(UIView *)cell;
+ (void)restoreCell:(UIView *)cell;
@end
