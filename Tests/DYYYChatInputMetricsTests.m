#import <Foundation/Foundation.h>
#import "DYYYChatInputMetrics.h"
#import <math.h>

int main(void) {
    @autoreleasepool {
        // 58476BAB：列表止于 y858，输入 64pt，底部安全区 34pt。开关清底已生效，但列表没有后景。
        double extension = [DYYYChatInputMetrics bottomExtensionForHostBottom:956 listTop:106 listBottom:858
            inputTop:858 inputBottom:922 folded:YES];
        NSCAssert(extension == 98, @"The message viewport must reach the physical bottom behind the entire input and safe area");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:956 listTop:106 listBottom:858
            inputTop:858 inputBottom:922 folded:NO] == 0, @"Keyboard and panels retain the native viewport");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:844 listTop:96 listBottom:746
            inputTop:746 inputBottom:810 folded:YES] == 98, @"The extension follows measured native coordinates on other devices");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:956 listTop:106 listBottom:956
            inputTop:858 inputBottom:922 folded:YES] == 0, @"An already extended viewport cannot accumulate another reserve");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:956 listTop:106 listBottom:520
            inputTop:520 inputBottom:584 folded:YES] == 0, @"A lifted input cannot stretch the message list through the keyboard or a panel");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:956 listTop:106 listBottom:858
            inputTop:800 inputBottom:864 folded:YES] == 0, @"Unknown nonadjacent list and input geometry is not guessed");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:956 listTop:850 listBottom:858
            inputTop:858 inputBottom:922 folded:YES] == 0, @"Transient partial lists do not become a full-screen viewport");
        NSCAssert([DYYYChatInputMetrics bottomExtensionForHostBottom:NAN listTop:106 listBottom:858
            inputTop:858 inputBottom:922 folded:YES] == 0, @"Invalid geometry cannot enter a frame or inset write");
        NSCAssert([DYYYChatInputMetrics canReuseTopExtension:106 bottomExtension:0 topWanted:YES bottomWanted:YES
            previousTopWanted:YES previousBottomWanted:YES], @"底侧由原生占满时，零底部扩展不能让顶部每轮撤回重加");
        NSCAssert([DYYYChatInputMetrics canReuseTopExtension:0 bottomExtension:98 topWanted:YES bottomWanted:YES
            previousTopWanted:YES previousBottomWanted:YES], @"原生顶部已满时，零顶部扩展不能让底部每轮撤回重加");
        NSCAssert(![DYYYChatInputMetrics canReuseTopExtension:106 bottomExtension:98 topWanted:NO bottomWanted:YES
            previousTopWanted:YES previousBottomWanted:YES], @"关闭顶部必须退出旧配置并恢复自有扩展");
        NSCAssert(![DYYYChatInputMetrics canReuseTopExtension:NAN bottomExtension:98 topWanted:YES bottomWanted:YES
            previousTopWanted:YES previousBottomWanted:YES], @"非法扩展不可复用");
        NSLog(@"DYYYChatInputMetrics regression tests passed");
    }
    return 0;
}
