#import "DYYYChatLifecycle.h"

@implementation DYYYChatLifecycle
- (void)resume {
    _generation++;
    _active = YES;
}
- (void)suspend {
    _generation++;
    _active = NO;
}
- (BOOL)acceptsGeneration:(NSUInteger)generation {
    return self.active && generation == self.generation;
}
@end
