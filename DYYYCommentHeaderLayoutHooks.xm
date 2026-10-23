#import "AwemeHeaders.h"
#import "DYYYCommentHeaderLayout.h"
#import <objc/runtime.h>

%group DYYYCommentHeaderLayoutHooks
%hook DYYYCommentHeaderSectionController
- (void)setDidUpdateHeight:(DYYYCommentHeaderHeightCallback)callback {
    DYYYCommentHeaderHeightCallback wrapped = [DYYYCommentHeaderLayout heightCallback:callback section:self];
    %orig(wrapped);
}
- (void)setDidTopBarUpdate:(DYYYCommentHeaderTopCallback)callback {
    DYYYCommentHeaderTopCallback wrapped = [DYYYCommentHeaderLayout topCallback:callback section:self];
    %orig(wrapped);
}
- (double)currentHeight {
    double nativeHeight = %orig;
    return [DYYYCommentHeaderLayout height:nativeHeight section:self];
}
- (CGSize)sizeForItemAtIndex:(NSInteger)index model:(id)model collectionViewSize:(CGSize)size {
    CGSize nativeSize = %orig(index, model, size);
    return [DYYYCommentHeaderLayout size:nativeSize model:model section:self];
}
- (void)configCell:(UICollectionViewCell *)cell index:(NSInteger)index model:(id)model {
    [DYYYCommentHeaderLayout bindCell:cell model:model section:self];
    %orig(cell, index, model);
    (void)[(DYYYCommentHeaderSectionController *)self currentHeight];
    [DYYYCommentHeaderLayout synchronizeCell:cell];
}
%end

%hook DYYYCommentHeaderCell
- (void)layoutSubviews {
    %orig;
    [DYYYCommentHeaderLayout synchronizeCell:(UICollectionViewCell *)self];
}
%end

%hook AWEShowPlayletCommentHeaderView
- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
    if (hidden) [DYYYCommentHeaderLayout businessViewDidHide:(UIView *)self];
}
%end
%end

%group DYYYCommentHeaderTopHeightHooks
%hook DYYYCommentHeaderInnerController
- (double)autoFullScreen_topContainerTotalHeight {
    double nativeHeight = %orig;
    return [DYYYCommentHeaderLayout topHeight:nativeHeight controller:(UIViewController *)self];
}
- (double)pinchFullScreen_topContainerTotalHeight {
    double nativeHeight = %orig;
    return [DYYYCommentHeaderLayout topHeight:nativeHeight controller:(UIViewController *)self];
}
%end
%end

%ctor {
    Class section = NSClassFromString(@"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderSectionController");
    Class cell = NSClassFromString(@"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderNewCell");
    Class inner = NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController");
    BOOL sectionReady = section && cell &&
        class_getInstanceMethod(section, @selector(configCell:index:model:)) &&
        class_getInstanceMethod(section, @selector(sizeForItemAtIndex:model:collectionViewSize:)) &&
        class_getInstanceMethod(section, @selector(currentHeight)) &&
        class_getInstanceMethod(section, @selector(setDidUpdateHeight:)) &&
        class_getInstanceMethod(section, @selector(setDidTopBarUpdate:)) &&
        class_getInstanceMethod(section, @selector(updateLayout:completion:));
    if (sectionReady) {
        %init(DYYYCommentHeaderLayoutHooks, DYYYCommentHeaderSectionController = section, DYYYCommentHeaderCell = cell);
    }
    if (sectionReady && inner && class_getInstanceMethod(inner, @selector(heightForSegmentedControl)) &&
        class_getInstanceMethod(inner, @selector(autoFullScreen_topContainerTotalHeight)) &&
        class_getInstanceMethod(inner, @selector(pinchFullScreen_topContainerTotalHeight))) {
        %init(DYYYCommentHeaderTopHeightHooks, DYYYCommentHeaderInnerController = inner);
    }
}
