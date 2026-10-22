//
//  DYYYVideoFeedTable.h
//  视频表撑高与 HUD（文案、进度条那一层）钉位。移植自 DYKiller 的 DKVideoFeedTable。
//
//  首页全屏把视频表撑到整屏高，但文案、昵称、进度条所在的 HUD 必须仍停在撑高之前的高度，
//  否则会被底栏挡住或与进度条之间空出一块。这里记下每张表撑高前的高度，HUD 一律钉在这个高度上，
//  不再按页面类型去猜。
//

#ifndef DYYYVideoFeedTable_h
#define DYYYVideoFeedTable_h

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 写入拦截：HUD 根视图被写成撑高后的满高时，改成表撑高前的高度。
/// tabBarDelta 为「自定义底栏高度 - 原生底栏高度」（没改底栏高度传 0），HUD 底边随它一起抬或落。
/// 返回 CGRectNull 表示放行。
CGRect DYYYFeedHUDAdjustFrame(UIView *view, CGRect frame, CGFloat tabBarDelta);

/// HUD 控制器布局后的兜底：HUD 在撑高过的表内且尺寸不对时改回去。
/// 返回 YES 表示这个 HUD 在撑高过的表内，已由这里负责，调用方不要再按页面类型调整它的高度。
BOOL DYYYFeedHUDApplyPin(UIView *hudView, CGFloat tabBarDelta);

#ifdef __cplusplus
}
#endif

#endif /* DYYYVideoFeedTable_h */
