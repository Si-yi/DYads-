#import <Foundation/Foundation.h>

/// 仅保存本次离页的播放意图，重复的父/子控制器回调不能覆盖第一次快照。
@interface DYYYFriendShareReturnState : NSObject
@property (nonatomic, readonly, copy) NSString *itemID;
@property (nonatomic, readonly) BOOL pending;
@property (nonatomic, readonly) BOOL wasPlaying;
- (void)beginLeavingItem:(NSString *)itemID playing:(BOOL)playing;
- (BOOL)consumeReturnToItem:(NSString *)itemID visible:(BOOL)visible playing:(BOOL)playing;
- (void)reset;
@end
