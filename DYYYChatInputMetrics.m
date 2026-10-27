#import "DYYYChatInputMetrics.h"
#import <math.h>

@implementation DYYYChatInputMetrics
+ (double)bottomExtensionForHostBottom:(double)hostBottom listTop:(double)listTop listBottom:(double)listBottom
                             inputTop:(double)inputTop inputBottom:(double)inputBottom folded:(BOOL)folded {
    if (!folded || !isfinite(hostBottom) || !isfinite(listTop) || !isfinite(listBottom) ||
        !isfinite(inputTop) || !isfinite(inputBottom) || hostBottom <= 0 || listTop < 0 ||
        listBottom - listTop < hostBottom * 0.4 || fabs(listBottom - inputTop) > 1 ||
        inputBottom - inputTop < 32 || inputBottom - inputTop > 120 ||
        inputBottom > hostBottom + 1 || hostBottom - inputBottom > 80) return 0;
    double extension = hostBottom - listBottom;
    return extension >= 1 && extension <= 128 ? extension : 0;
}
@end
