#import <Foundation/Foundation.h>

/// 只保存本机实际收到的发送回执事实，不查询聊天历史、不修改抖音已读状态。
@interface DYYYIMSendLedger : NSObject
+ (NSString *)keyForAccount:(NSString *)account peer:(NSString *)peer date:(NSDate *)date calendar:(NSCalendar *)calendar;
+ (NSDictionary *)recordsByObservingOutgoing:(NSDictionary *)facts account:(NSString *)account peer:(NSString *)peer
                                        now:(NSDate *)now calendar:(NSCalendar *)calendar records:(NSDictionary *)records;
@end
