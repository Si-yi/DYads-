#import <UIKit/UIKit.h>

@interface DYYYCommentMenuGrid : NSObject
+ (CGSize)sizeForSection:(id)section index:(NSInteger)index original:(CGSize)original collectionSize:(CGSize)size;
+ (void)configureCell:(UIView *)cell section:(id)section index:(NSInteger)index model:(id)model;
+ (void)restoreContentInCell:(UIView *)cell;
+ (void)layoutCell:(UIView *)cell;
+ (void)restoreCell:(UIView *)cell;
+ (id)registerSections:(NSArray *)sections list:(id)list;
+ (BOOL)isManagedSectionModel:(id)section;
+ (NSArray *)modelsForSection:(id)section incoming:(NSArray *)models;
+ (void)didReplaceModelsInSection:(id)section;
+ (BOOL)isComposerVisible:(UIView *)composer;
+ (BOOL)isMenuLayout:(UICollectionViewLayout *)layout;
+ (UICollectionViewLayoutAttributes *)adjustAttributes:(UICollectionViewLayoutAttributes *)attributes layout:(UICollectionViewLayout *)layout;
+ (UICollectionView *)collectionForController:(UIViewController *)controller;
+ (void)synchronizeMenuControllerImmediately:(UIViewController *)controller;
+ (void)synchronizeMenuController:(UIViewController *)controller;
+ (void)synchronizeController:(UIViewController *)controller;
+ (CGFloat)constrainedMinimumHeight:(CGFloat)height controller:(UIViewController *)controller;
+ (CGFloat)constrainedHeight:(CGFloat)height controller:(UIViewController *)controller;
+ (void)restoreController:(UIViewController *)controller;
+ (NSDictionary *)lastClosedDiagnostics;
+ (NSDictionary *)diagnosticsForController:(UIViewController *)controller;
@end
