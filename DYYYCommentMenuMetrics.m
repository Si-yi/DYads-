#import "DYYYCommentMenuMetrics.h"
#import <math.h>

@implementation DYYYCommentMenuMetrics
+ (double)contentHeightForActionBottom:(double)bottom safeAreaBottom:(double)safeArea rawContent:(double)raw {
    if (!isfinite(bottom) || bottom <= 0 || !isfinite(safeArea)) return raw;
    // 原生列表可能残留 160pt 选人占位。只保留实际功能项及底部安全距离。
    return bottom + MAX(20, safeArea);
}
+ (BOOL)needsUpdateForTarget:(double)target propertyHeight:(double)property renderedHeight:(double)rendered {
    if (!isfinite(target) || target <= 0 || !isfinite(property) || !isfinite(rendered)) return NO;
    return fabs(property - target) >= 0.5 || (rendered > 0 && fabs(rendered - target) >= 0.5);
}
+ (double)compactHeightForContent:(double)content inset:(double)inset firstRowBottom:(double)rowBottom composerHeight:(double)composer maximum:(double)maximum {
    if (!isfinite(content) || !isfinite(inset) || !isfinite(rowBottom) || !isfinite(composer) || !isfinite(maximum) || maximum <= 0) return 0;
    double body = composer > 0 && rowBottom > 0 ? rowBottom + composer : content;
    return ceil(MIN(MAX(0, body) + MAX(0, inset), maximum));
}
@end
