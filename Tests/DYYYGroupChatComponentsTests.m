#import <Foundation/Foundation.h>
#import "DYYYGroupChatComponents.h"

int main(void) {
    @autoreleasepool {
        NSString *toggle = @"AWEIMMessageListNaviBarGroupZoneToggleComponent";
        NSString *detail = @"AWEIMMessageListNaviBarChatDetailComponent";
        NSArray *nativeGroup = @[@"Title", toggle, @"Messages"];
        id off = [DYYYGroupChatComponents navigationComponents:nativeGroup enabled:NO];
        NSCAssert(off == nativeGroup, @"关闭时原始配置身份保持不变");
        NSArray *on = [DYYYGroupChatComponents navigationComponents:nativeGroup enabled:YES];
        NSCAssert(([on isEqual:@[@"Title", detail, @"Messages"]]), @"由原生管理器创建详情组件，其他组件和顺序不变");
        NSCAssert([nativeGroup[1] isEqual:toggle], @"不能改写原始共享配置");
        NSCAssert([DYYYGroupChatComponents navigationComponents:on enabled:YES] == on, @"嵌套配置入口重复处理应幂等");
        NSArray *nativeMore = @[@"Title", @"VoIP", detail, @"Messages"];
        NSCAssert([DYYYGroupChatComponents navigationComponents:nativeMore enabled:YES] == nativeMore, @"原生电话和三个点布局保留");
        NSArray *alreadyRegistered = @[toggle, @"Title", detail, toggle];
        NSArray *result = [DYYYGroupChatComponents navigationComponents:alreadyRegistered enabled:YES];
        NSCAssert(([result isEqual:@[@"Title", detail]]), @"已有详情组件时不重复注册，也不丢失其他组件");
        NSArray *unknown = @[@[@"nested"], @17, @"unknown"];
        NSCAssert([DYYYGroupChatComponents navigationComponents:unknown enabled:YES] == unknown, @"不猜测未知配置结构");
        NSCAssert([DYYYGroupChatComponents navigationComponents:nil enabled:YES] == nil, @"空配置透传");
        NSCAssert([[DYYYGroupChatComponents navigationComponents:@"unknown" enabled:YES] isEqual:@"unknown"], @"非数组透传");
        NSLog(@"DYYYGroupChatComponents regression tests passed");
    }
    return 0;
}
