#import <Foundation/Foundation.h>
@interface DYYYMessageListUpdateState : NSObject
@property (nonatomic, readonly) NSUInteger depth;
@property (nonatomic, readonly) NSUInteger generation;
- (NSUInteger)beginUpdate;
- (BOOL)endUpdate:(NSUInteger)generation;
- (void)invalidate;
@end
