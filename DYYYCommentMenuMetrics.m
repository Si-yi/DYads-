#import "DYYYCommentMenuMetrics.h"
#import <math.h>

@implementation DYYYCommentMenuMetrics
+ (double)contentInsetForShellTop:(double)shellTop contentTop:(double)contentTop {
    double inset = contentTop - shellTop;
    return isfinite(inset) && inset >= 0 && inset <= 64 ? inset : NAN;
}
+ (double)contentHeightForActionBottom:(double)bottom safeAreaBottom:(double)safeArea rawContent:(double)raw {
    if (!isfinite(bottom) || bottom <= 0 || !isfinite(safeArea)) return raw;
    // 原生列表可能残留 160pt 选人占位。只保留实际功能项及底部安全距离。
    return bottom + MAX(20, safeArea);
}
+ (BOOL)needsUpdateForTarget:(double)target propertyHeight:(double)property renderedHeight:(double)rendered {
    if (!isfinite(target) || target <= 0 || !isfinite(property) || !isfinite(rendered)) return NO;
    return fabs(property - target) >= 0.5 || (rendered > 0 && fabs(rendered - target) >= 0.5);
}
+ (double)composerHeightForBounds:(double)bounds contentBottom:(double)bottom safeAreaBottom:(double)safeArea active:(BOOL)active {
    if (!active || !isfinite(bounds) || !isfinite(bottom) || !isfinite(safeArea)) return 0;
    // 39.5 导出中原生发送区正常为 126pt，底部控件距边缘 6pt。全隐藏时 bounds 可被挤成 0。
    return MAX(126, MAX(MAX(0, bounds), MAX(0, bottom) + 6)) + MAX(0, safeArea);
}
+ (double)heightLimitForOriginal:(double)original nativeMinimum:(double)minimum screenLimit:(double)screenLimit composerActive:(BOOL)active {
    if (!isfinite(original) || !isfinite(minimum) || !isfinite(screenLimit) || screenLimit <= 0) return 0;
    // 无功能项时未选人菜单只有 184pt，不能用这个高度封死随后添加的原生发送区。
    return MIN(MAX(0, active ? MAX(original, minimum) : original), screenLimit);
}
+ (double)compactHeightForContent:(double)content inset:(double)inset firstRowBottom:(double)rowBottom composerHeight:(double)composer maximum:(double)maximum {
    if (!isfinite(content) || !isfinite(inset) || !isfinite(rowBottom) || !isfinite(composer) || !isfinite(maximum) || maximum <= 0) return 0;
    double body = composer > 0 ? MAX(0, rowBottom) + composer : content;
    return ceil(MIN(MAX(0, body) + MAX(0, inset), maximum));
}
+ (double)constrainedSheetHeight:(double)height target:(double)target composerActive:(BOOL)active {
    if (!isfinite(height) || height <= 0 || !isfinite(target) || target <= 0) return height;
    // 选人态的旧模型仍可能只报好友行高度，不能再次把已恢复的发送区压扁。
    return active ? target : MIN(height, target);
}
+ (double)constrainedNativeHeight:(double)height target:(double)target managed:(BOOL)managed {
    if (!managed || !isfinite(height) || height < 0 || !isfinite(target) || target <= 0) return height;
    return MIN(height, target);
}
@end
