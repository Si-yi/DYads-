#import "AwemeHeaders.h"
#import "DYYYRefreshIndicatorStyle.h"
#import "DYYYChatEnhancementPolicy.h"
%group DYYYNoticeRefreshIndicatorHooks
%hook AWERefreshHeader
- (void)placeSubviews { %orig;[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
- (void)layoutSubviews { %orig;[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
- (void)didMoveToWindow { %orig;[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
- (void)setState:(long long)state { %orig(state);[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
- (void)setPullingPercent:(double)percent { %orig(percent);[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
- (void)setLoading:(UIView *)loading { %orig(loading);[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
- (void)scrollViewPanStateDidChange:(id)change { %orig(change);[DYYYRefreshIndicatorStyle synchronizeHeader:(UIView *)self]; }
%end
%end
@implementation DYYYRefreshIndicatorStyle (RuntimeHooks)
+ (void)installHooks {
    static BOOL installed;if(installed)return;
    @synchronized(self){if(installed)return;
    Class cls=NSClassFromString(@"AWERefreshHeader");
    if([cls isSubclassOfClass:UIView.class] && [DYYYChatEnhancementPolicy class:cls selector:@selector(scrollView) result:'@' arguments:@""] &&
       [DYYYChatEnhancementPolicy class:cls selector:@selector(loading) result:'@' arguments:@""] &&
       [DYYYChatEnhancementPolicy class:cls selector:@selector(isRefreshing) result:'B' arguments:@""] &&
       [DYYYChatEnhancementPolicy class:cls selector:@selector(setState:) result:'v' arguments:@"q"] &&
       [DYYYChatEnhancementPolicy class:cls selector:@selector(setPullingPercent:) result:'v' arguments:@"d"] &&
       [DYYYChatEnhancementPolicy class:cls selector:@selector(setLoading:) result:'v' arguments:@"@"] &&
       [DYYYChatEnhancementPolicy class:cls selector:@selector(scrollViewPanStateDidChange:) result:'v' arguments:@"@"]){%init(DYYYNoticeRefreshIndicatorHooks);installed=YES;}
    }
}
@end
%ctor { [DYYYRefreshIndicatorStyle installHooks]; }
