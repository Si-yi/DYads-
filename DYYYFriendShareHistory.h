#import <Foundation/Foundation.h>

/// 按账户保存未刷分享；播放进度和手势只影响已刷判定，不改聊天已读状态。
@interface DYYYFriendShareHistory : NSObject
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults account:(NSString *)account;
@property (nonatomic, readonly, copy) NSArray<NSDictionary *> *pendingRows;
@property (nonatomic, readonly, copy) NSSet<NSString *> *watchedItemIDs;
- (void)mergeRows:(NSArray<NSDictionary *> *)rows;
- (void)importLegacySources:(NSDictionary *)sources;
- (void)clearWatched;
- (NSDictionary *)diagnostics;
- (void)recordPlaybackForItemID:(NSString *)itemID time:(NSTimeInterval)time;
- (void)beginDraggingFromItemID:(NSString *)itemID;
/// 仅在确有播放进度、且垂直滑动切到另一个作品后返回刚记为已刷的 ID。
- (NSString *)finishDraggingToItemID:(NSString *)itemID;
- (BOOL)completeLoopForItemID:(NSString *)itemID;
- (void)resetPlayback;
@end
