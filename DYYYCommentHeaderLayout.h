#import <UIKit/UIKit.h>

typedef void (^DYYYCommentHeaderHeightCallback)(double);
typedef void (^DYYYCommentHeaderTopCallback)(BOOL, BOOL);

@interface DYYYCommentHeaderLayout : NSObject
+ (void)bindCell:(UICollectionViewCell *)cell model:(id)model section:(id)section;
+ (void)synchronizeCell:(UICollectionViewCell *)cell;
+ (void)businessViewDidHide:(UIView *)view;
+ (double)height:(double)height section:(id)section;
+ (CGSize)size:(CGSize)size model:(id)model section:(id)section;
+ (DYYYCommentHeaderHeightCallback)heightCallback:(DYYYCommentHeaderHeightCallback)callback section:(id)section;
+ (DYYYCommentHeaderTopCallback)topCallback:(DYYYCommentHeaderTopCallback)callback section:(id)section;
+ (double)topHeight:(double)height controller:(UIViewController *)controller;
@end
