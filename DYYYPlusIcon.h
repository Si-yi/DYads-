//
//  DYYYPlusIcon.h
//  拍摄按钮：样式（默认 / 新图标 / 新双色图标 / 自定义图片）与自定义图标（相册选图 → 圆形裁剪 → 存盘）。
//  移植自 DYKiller 的 DKPlusIcon.xm，取代原来的「拍摄的图标」。
//

#ifndef DYYYPlusIcon_h
#define DYYYPlusIcon_h

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, DKPlusStyle) {
    DKPlusStyleDefault = 0,
    DKPlusStyleCamera = 1,
    DKPlusStyleBrand = 2,
    DKPlusStyleCustom = 3,
};

#ifdef __cplusplus
extern "C" {
#endif

/// 样式选项的显示文字，下标即 DKPlusStyle。
NSArray<NSString *> *DYYYPlusStyleTitles(void);

/// 实际生效的样式：选了「自定义图片」但没有图片时按默认；
/// 从未选过样式、但以前设过拍摄图标的老用户，按「自定义图片」沿用。
DKPlusStyle DKPlusCurrentStyle(void);

/// 用户设置的拍摄图标；未设置时为 nil。圆形 alpha 已烘进图内。
UIImage *DKPlusIconCustom(void);

/// 抖音原生底栏的拍摄按钮要换上的图：样式为「自定义图片」且有图时返回它，否则 nil（保持抖音原样）。
UIImage *DYYYPlusNativeImage(void);

/// 设置页「拍摄的图标」一行的副标题。
NSString *DYYYPlusIconDetail(void);

/// 设置页「拍摄的按钮」一行的副标题。
NSString *DYYYPlusStyleDetail(void);

/// 点「拍摄的按钮」：弹出样式单选；选「自定义图片」而还没有图片时先去选图，取消则保持原样式。
void DYYYPlusShowStyleChooser(UIViewController *presenter, void (^changed)(void));

/// 点「拍摄的图标」：预览 + 清除 / 选择 / 取消。
void DYYYPlusShowIconDialog(UIViewController *presenter, void (^changed)(void));

/// 按当前设置立刻重绘悬浮底栏上的拍摄键。
void DYYYPlusRefresh(void);

/// 由悬浮底栏实现提供；底栏没编进来时是空函数。
void DKGlassTabBarRefresh(void);

#ifdef __cplusplus
}
#endif

#endif /* DYYYPlusIcon_h */
