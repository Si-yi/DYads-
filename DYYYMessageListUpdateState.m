#import "DYYYMessageListUpdateState.h"
@implementation DYYYMessageListUpdateState
- (NSUInteger)beginUpdate { _depth++; return _generation; }
- (BOOL)endUpdate:(NSUInteger)generation {
    if(generation!=_generation || !_depth)return NO;
    _depth--;return _depth==0;
}
- (void)invalidate { _generation++;_depth=0; }
@end
