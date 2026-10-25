#import "DYYYCommentMenuMetrics.h"
#import <math.h>

@implementation DYYYCommentMenuMetrics
+ (double)compactHeightForContent:(double)content inset:(double)inset firstRowBottom:(double)rowBottom composerHeight:(double)composer maximum:(double)maximum {
    if (!isfinite(content) || !isfinite(inset) || !isfinite(rowBottom) || !isfinite(composer) || !isfinite(maximum) || maximum <= 0) return 0;
    double body = composer > 0 && rowBottom > 0 ? rowBottom + composer : content;
    return ceil(MIN(MAX(0, body) + MAX(0, inset), maximum));
}
@end
