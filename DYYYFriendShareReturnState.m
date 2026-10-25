#import "DYYYFriendShareReturnState.h"

@interface DYYYFriendShareReturnState ()
@property (nonatomic, readwrite, copy) NSString *itemID;
@property (nonatomic, readwrite) BOOL pending;
@property (nonatomic, readwrite) BOOL wasPlaying;
@end
@implementation DYYYFriendShareReturnState
- (void)beginLeavingItem:(NSString *)itemID playing:(BOOL)playing {
    if (self.pending || !itemID.length) return;
    self.pending = YES; self.itemID = itemID; self.wasPlaying = playing;
}
- (BOOL)consumeReturnToItem:(NSString *)itemID visible:(BOOL)visible playing:(BOOL)playing {
    if (!self.pending || !visible || !itemID.length) return NO;
    BOOL resume = self.wasPlaying && !playing && [self.itemID isEqual:itemID];
    [self reset]; // 已自行播放、换作品或原本暂停也结束快照；不能留到以后误播。
    return resume;
}
- (void)reset { self.itemID = nil; self.pending = NO; self.wasPlaying = NO; }
@end
