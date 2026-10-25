#import <Foundation/Foundation.h>

/// 按账户保存未刷分享；播放进度和手势只影响已刷判定，不改聊天已读状态。
@interface DYYYFriendShareHistory : NSObject
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults account:(NSString *)account;
@property (nonatomic, readonly, copy) NSArray<NSDictionary *> *pendingRows;
@property (nonatomic, readonly, copy) NSSet<NSString *> *watchedItemIDs;
- (void)mergeRows:(NSArray<NSDictionary *> *)rows;
/// 只撤销来源好友匹配、尚未保存直接分享凭据的旧误判，不改已刷记录。
- (NSSet<NSString *> *)discardUnverifiedRows:(NSArray<NSDictionary *> *)rows;
- (void)importLegacySources:(NSDictionary *)sources;
- (void)clearWatched;
- (NSDictionary *)diagnostics;
- (void)recordPlaybackForItemID:(NSString *)itemID time:(NSTimeInterval)time;
- (void)beginDraggingFromItemID:(NSString *)itemID;
/// 从实际可见 Cell 开始的手动垂直滑动完成后记已刷；不依赖播放进度回调。
- (NSString *)finishDraggingToItemID:(NSString *)itemID;
- (BOOL)completeLoopForItemID:(NSString *)itemID;
- (void)resetPlayback;
@end
