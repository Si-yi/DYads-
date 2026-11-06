#import "DYYYChatLifecycle.h"

@implementation DYYYChatLifecycle
- (void)beginAppearance {
    if (self.preparing || self.active) return;
    _generation++;
    _preparing = YES;
}
- (BOOL)canStyleTop { return self.preparing || self.active; }
- (void)resume {
    _generation++;
    _active = YES;
    _preparing = NO;
}
- (void)suspend {
    _generation++;
    _active = NO;
    _preparing = NO;
}
- (BOOL)acceptsGeneration:(NSUInteger)generation {
    return self.active && generation == self.generation;
}
- (BOOL)acceptsTopGeneration:(NSUInteger)generation {
    return self.canStyleTop && generation == self.generation;
}
@end
