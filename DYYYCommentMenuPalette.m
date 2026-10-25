/*
 原生卡片绘制成员适配参考 DYKiller DKSharePanelGlass.xm / DKCommentMenuGrid.xm。
 https://github.com/HierarchThurs/DYKiller

 MIT License
 Copyright (c) 2026 Hierarch

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*/
#import "DYYYCommentMenuPalette.h"
#import "DYYYCommentMenuTheme.h"
#import "DYYYPanelBlur.h"
#import "AwemeHeaders.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <string.h>
#import <math.h>

static char kDYYYMenuPaletteChangesKey;
static char kDYYYMenuPaletteObjectsKey;
static char kDYYYMenuPaletteBusyKey;
static char kDYYYMenuPaletteShapeKey;
static char kDYYYMenuPaletteReportKey;
static char kDYYYMenuActionOverlayKey;
static char kDYYYMenuNativeActionIconKey;
static char kDYYYMenuSelectionBusyKey;
static char kDYYYMenuSelectionScheduledKey;
static char kDYYYMenuSelectionOverlayKey;
static char kDYYYMenuSelectionRowsKey;
static char kDYYYMenuSelectionOverlayMarkerKey;

@implementation DYYYCommentMenuPalette

+ (NSHashTable *)objectsForController:(UIViewController *)controller {
    NSHashTable *objects = objc_getAssociatedObject(controller, &kDYYYMenuPaletteObjectsKey);
    if (!objects) {
        objects = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(controller, &kDYYYMenuPaletteObjectsKey, objects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return objects;
}

+ (BOOL)equal:(id)a other:(id)b {
    return a == b || [a isEqual:b];
}

+ (void)write:(id)value key:(NSString *)key object:(id)object controller:(UIViewController *)controller {
    if (!object || !value) return;
    @try {
        id current = [object valueForKey:key] ?: NSNull.null;
        NSMutableDictionary *changes = objc_getAssociatedObject(object, &kDYYYMenuPaletteChangesKey);
        NSDictionary *previous = changes[key];
        if ([self equal:current other:value]) return;
        if (!changes) {
            changes = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(object, &kDYYYMenuPaletteChangesKey, changes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        id original = previous && [self equal:current other:previous[@"applied"]] ? previous[@"original"] : current;
        changes[key] = @{ @"original": original, @"applied": value };
        [[self objectsForController:controller] addObject:object];
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {}
}

+ (BOOL)isNeutral:(UIColor *)color minimum:(CGFloat)minimum opaque:(BOOL)opaque {
    if (!color) return NO;
    CGFloat r, g, b, a;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;
    return a > (opaque ? 0.9 : 0.01) && MAX(r, MAX(g, b)) >= minimum &&
        MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) < 0.12;
}

+ (id)ivar:(const char *)name inCell:(UIView *)cell {
    // 这三个绘制成员由 DYKiller DKCommentMenuGrid.xm 的原生行布局适配确认。
    Class base = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
    Ivar ivar = base ? class_getInstanceVariable(base, name) : NULL;
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if (!ivar || !type || type[0] != '@' || ![cell isKindOfClass:base]) return nil;
    return object_getIvar(cell, ivar);
}

+ (UIColor *)readableTextColor:(UIColor *)color {
    if (!color) return nil;
    UIColor *resolved = [color resolvedColorWithTraitCollection:
        [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]];
    CGFloat r, g, b, a;
    if (![resolved getRed:&r green:&g blue:&b alpha:&a] || a <= 0.01) return nil;
    // 抖音的正文是略带蓝色的深灰，不能只匹配纯黑；火花、警告等彩色文字保留。
    if (MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) >= 0.12) return nil;
    if (MIN(r, MIN(g, b)) >= 0.78 && a >= 0.9) return nil;
    // 主文字与辅助文字都使用不透明颜色，避免旧的 60% 黑色在黑底上消失。
    return [UIColor colorWithWhite:a < 0.85 ? 0.78 : 0.96 alpha:1];
}

+ (void)applyLabel:(UILabel *)label controller:(UIViewController *)controller {
    // 富文本只改对应的颜色段，不再调用 textColor setter 覆盖彩色火花或原始样式。
    NSAttributedString *originalText = label.attributedText;
    if (originalText.length) {
        NSMutableAttributedString *text = [originalText mutableCopy];
        __block BOOL changed = NO;
        [originalText enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, originalText.length) options:0 usingBlock:^(id color, NSRange range, BOOL *stop) {
            UIColor *source = [color isKindOfClass:UIColor.class] ? color : label.textColor;
            UIColor *target = [self readableTextColor:source];
            if (target) {
                [text addAttribute:NSForegroundColorAttributeName value:target range:range];
                changed = YES;
            }
        }];
        if (changed) [self write:text key:@"attributedText" object:label controller:controller];
        return;
    }
    UIColor *target = [self readableTextColor:label.textColor];
    if (target) [self write:target key:@"textColor" object:label controller:controller];
}

+ (UIImageView *)actionIconInCell:(UIView *)cell {
    UIImageView *icon = [self ivar:"$__lazy_storage_$_iconImage" inCell:cell];
    if ([icon isKindOfClass:UIImageView.class]) return icon;
    // 39.5.0 导出中功能图标为行首 20×20 的 UIImageView；Swift 成员不可读时局部回退。
    // 仅从功能行内找小图标，不接管好友头像、火花和识图缩略图。
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cell];
    for (NSUInteger index = 0; index < queue.count && index < 32; index++) {
        UIView *view = queue[index];
        if (view == objc_getAssociatedObject(cell, &kDYYYMenuActionOverlayKey)) continue;
        if ([view isKindOfClass:UIImageView.class]) {
            CGRect frame = [view convertRect:view.bounds toView:cell];
            if (frame.size.width >= 16 && frame.size.width <= 24 &&
                frame.size.height >= 16 && frame.size.height <= 24 &&
                CGRectGetMinX(frame) >= 0 && CGRectGetMaxX(frame) <= 44)
                return (UIImageView *)view;
            continue;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

+ (void)removeActionOverlayFromObject:(id)object {
    UIImageView *overlay = objc_getAssociatedObject(object, &kDYYYMenuActionOverlayKey);
    if (!overlay) return;
    UIImageView *native = objc_getAssociatedObject(overlay, &kDYYYMenuNativeActionIconKey);
    objc_setAssociatedObject(object, &kDYYYMenuActionOverlayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [overlay removeFromSuperview];
    if (native) [self restoreObject:native];
}

+ (UIImage *)whiteActionSymbolNamed:(NSString *)name {
    static NSDictionary<NSString *, UIImage *> *symbols;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *images = [NSMutableDictionary dictionary];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        for (NSString *key in @[ @"doc.on.doc", @"star", @"star.fill", @"magnifyingglass" ]) {
            UIImage *image = [UIImage systemImageNamed:key withConfiguration:config];
            if (image) images[key] = [image imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        symbols = [images copy];
    });
    return symbols[name];
}

+ (UIImage *)disabledActionSymbolNamed:(NSString *)name {
    static NSDictionary<NSString *, UIImage *> *symbols;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *images = [NSMutableDictionary dictionary];
        UIColor *color = [UIColor colorWithWhite:0.78 alpha:1];
        for (NSString *key in @[ @"doc.on.doc", @"star", @"star.fill", @"magnifyingglass" ]) {
            UIImage *image = [[self whiteActionSymbolNamed:key] imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
            if (image) images[key] = image;
        }
        symbols = [images copy];
    });
    return symbols[name];
}

// 普通功能行与选人遮罩共用同一组动作识别，不能把好友昵称当作动作。
+ (NSString *)actionSymbolForTitle:(NSString *)title {
    if ([title hasPrefix:@"复制"]) return @"doc.on.doc";
    if ([title isEqualToString:@"收藏"]) return @"star";
    if ([title isEqualToString:@"取消收藏"] || [title isEqualToString:@"已收藏"]) return @"star.fill";
    if ([title isEqualToString:@"搜索"]) return @"magnifyingglass";
    return nil;
}

+ (UILabel *)actionLabelInCell:(UIView *)cell {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cell];
    for (NSUInteger index = 0; index < queue.count && index < 32; index++) {
        UIView *view = queue[index];
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            if ([self actionSymbolForTitle:label.text ?: label.attributedText.string]) return label;
        }
        if (![view isKindOfClass:UIImageView.class]) [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

+ (BOOL)applyReadableActionIconInCell:(UIView *)cell controller:(UIViewController *)controller {
    // 原生图片可能在布局之后重新着色。已确认的三个动作独立绘制白色符号，避免只改 tintColor 后仍变黑。
    UILabel *actionLabel = [self actionLabelInCell:cell];
    NSString *symbolName = [self actionSymbolForTitle:actionLabel.text ?: actionLabel.attributedText.string];
    UIImageView *overlay = objc_getAssociatedObject(cell, &kDYYYMenuActionOverlayKey);
    if (!symbolName) {
        [self removeActionOverlayFromObject:cell];
        return NO;
    }
    UIImageView *nativeIcon = [self actionIconInCell:cell];
    CGRect frame = nativeIcon ? [nativeIcon convertRect:nativeIcon.bounds toView:cell] : CGRectZero;
    if (CGRectIsEmpty(frame)) {
        // 私有成员名变化时，以原生文字的行首留白定位，不改文字、行高或点击区域。
        CGRect labelFrame = [actionLabel convertRect:actionLabel.bounds toView:cell];
        frame = CGRectMake(CGRectGetMinX(labelFrame) - 32, CGRectGetMidY(labelFrame) - 10, 20, 20);
    }
    UIImage *symbol = [self whiteActionSymbolNamed:symbolName];
    if (CGRectIsEmpty(frame) || !CGRectContainsRect(cell.bounds, frame) || !symbol) {
        [self removeActionOverlayFromObject:cell];
        return NO;
    }
    if (!overlay) {
        overlay = [[UIImageView alloc] initWithFrame:frame];
        overlay.userInteractionEnabled = NO;
        overlay.isAccessibilityElement = NO;
        overlay.contentMode = UIViewContentModeScaleAspectFit;
        objc_setAssociatedObject(cell, &kDYYYMenuActionOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self objectsForController:controller] addObject:cell];
        [cell addSubview:overlay];
    }
    UIImageView *previousIcon = objc_getAssociatedObject(overlay, &kDYYYMenuNativeActionIconKey);
    if (previousIcon != nativeIcon) {
        if (previousIcon) [self restoreObject:previousIcon];
        objc_setAssociatedObject(overlay, &kDYYYMenuNativeActionIconKey, nativeIcon, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!CGRectEqualToRect(overlay.frame, frame)) overlay.frame = frame;
    if (overlay.image != symbol) overlay.image = symbol;
    [cell bringSubviewToFront:overlay];
    if (nativeIcon) [self write:@0 key:@"alpha" object:nativeIcon controller:controller];
    return YES;
}

+ (void)synchronizeCell:(UIView *)cell {
    UIViewController *controller = [DYYYCommentMenuTheme controllerForView:cell];
    if (controller && cell.window) [self applyInView:cell controller:controller];
    else [self restoreView:cell];
    [DYYYPanelBlur synchronizeView:cell];
}

// 选人回调及遮罩创建时机参考 DYKiller DKShareSelectionHooks.xm，沿用本文件 MIT 声明。
+ (void)refreshSelectionController:(UIViewController *)controller {
    if (!controller.viewIfLoaded.window || objc_getAssociatedObject(controller, &kDYYYMenuSelectionBusyKey)) return;
    objc_setAssociatedObject(controller, &kDYYYMenuSelectionBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try { [DYYYCommentMenuTheme prepareController:controller]; }
    @finally { objc_setAssociatedObject(controller, &kDYYYMenuSelectionBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}

+ (void)synchronizeSelectionSection:(id)section overlay:(UIView *)overlay {
    if (!NSThread.isMainThread) return;
    UIViewController *content = [section respondsToSelector:@selector(viewController)] ?
        [(DYYYCommentMenuSelectionSection *)section viewController] : nil;
    UIViewController *controller = [DYYYCommentMenuTheme menuControllerForController:content] ?:
        (overlay ? [DYYYCommentMenuTheme controllerForView:overlay] : nil);
    if (!controller || objc_getAssociatedObject(controller, &kDYYYMenuSelectionBusyKey)) return;
    [self refreshSelectionController:controller];
    if (objc_getAssociatedObject(controller, &kDYYYMenuSelectionScheduledKey)) return;
    objc_setAssociatedObject(controller, &kDYYYMenuSelectionScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIViewController *weakController = controller;
    // 同轮原生回调可能稍后才写昵称颜色/添加遮罩，只合并一次补同步，不轮询。
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *menu = weakController;
        if (!menu) return;
        objc_setAssociatedObject(menu, &kDYYYMenuSelectionScheduledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self refreshSelectionController:menu];
    });
}

+ (void)synchronizeContentController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    UIViewController *menu = [DYYYCommentMenuTheme menuControllerForController:controller];
    if (menu) [self refreshSelectionController:menu];
}

+ (BOOL)isSelectionMask:(UIView *)view controller:(UIViewController *)controller {
    if (view.hidden || view.alpha <= 0.01 || [view isKindOfClass:UIControl.class] ||
        [view isKindOfClass:UIScrollView.class] || [view isKindOfClass:UIVisualEffectView.class] ||
        [view isKindOfClass:UIImageView.class] || [view isKindOfClass:UILabel.class]) return NO;
    UIView *host = view.superview;
    if (!host || CGRectGetWidth(view.bounds) < CGRectGetWidth(host.bounds) * 0.9 ||
        CGRectGetHeight(view.bounds) < 16 || fabs(CGRectGetMinX(view.frame) - CGRectGetMinX(host.bounds)) > 1) return NO;
    UIViewController *owner = [host.nextResponder isKindOfClass:UIViewController.class] ? (id)host.nextResponder : nil;
    if (![NSStringFromClass(owner.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCollectionViewController"] ||
        [DYYYCommentMenuTheme menuControllerForController:owner] != controller || host != owner.viewIfLoaded) return NO;
    Class composer = NSClassFromString(@"AWEIMShareImpl.ShareAdditionTextView");
    for (UIView *sibling in host.subviews) {
        if (!composer || ![sibling isKindOfClass:composer] || sibling.hidden || sibling.alpha <= 0.01) continue;
        // 真机遮罩位于好友行下方、发送输入区上方，不能把普通白底或按钮当作遮罩。
        if (CGRectGetWidth(sibling.bounds) >= CGRectGetWidth(host.bounds) * 0.9 &&
            fabs(CGRectGetMaxY(view.frame) - CGRectGetMinY(sibling.frame)) <= 1.5) return YES;
    }
    return NO;
}

+ (BOOL)isManagedSelectionOverlay:(UIView *)view {
    return [objc_getAssociatedObject(view, &kDYYYMenuSelectionOverlayMarkerKey) boolValue];
}

+ (void)removeSelectionOverlayFromObject:(id)object {
    UIView *overlay = objc_getAssociatedObject(object, &kDYYYMenuSelectionOverlayKey);
    [overlay removeFromSuperview];
    objc_setAssociatedObject(object, &kDYYYMenuSelectionOverlayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)synchronizeSelectionMask:(UIView *)mask controller:(UIViewController *)controller {
    // 原生遮罩仍负责禁用动作；只在它的内容层镜像可辨认的灰白字，不改变命中、alpha 或显隐。
    UIView *overlay = objc_getAssociatedObject(mask, &kDYYYMenuSelectionOverlayKey);
    if (!overlay) {
        overlay = [[UIView alloc] initWithFrame:mask.bounds];
        overlay.userInteractionEnabled = NO;
        overlay.accessibilityIdentifier = @"DYYY.CommentMenu.SelectionReadability";
        overlay.accessibilityElementsHidden = YES;
        overlay.isAccessibilityElement = NO;
        overlay.clipsToBounds = YES;
        objc_setAssociatedObject(overlay, &kDYYYMenuSelectionOverlayMarkerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(overlay, &kDYYYMenuSelectionRowsKey, [NSMapTable weakToStrongObjectsMapTable], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(mask, &kDYYYMenuSelectionOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self objectsForController:controller] addObject:mask];
        [mask addSubview:overlay];
    }
    if (!CGRectEqualToRect(overlay.frame, mask.bounds)) overlay.frame = mask.bounds;
    NSMapTable *rows = objc_getAssociatedObject(overlay, &kDYYYMenuSelectionRowsKey);
    NSMutableSet<UIView *> *visibleParts = [NSMutableSet set];
    Class cardClass = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
    UIColor *disabledText = [UIColor colorWithWhite:0.78 alpha:1];
    for (UIView *sibling in mask.superview.subviews) {
        if (![sibling isKindOfClass:UICollectionView.class]) continue;
        // 只镜像原生禁用遮罩覆盖的可见功能行，不处理发送区或好友 Cell。
        for (UICollectionViewCell *cell in ((UICollectionView *)sibling).visibleCells) {
            if (!cardClass || ![cell isKindOfClass:cardClass] || cell.hidden || cell.alpha <= 0.01) continue;
            UILabel *source = [self actionLabelInCell:cell];
            if (!source || source.hidden || source.alpha <= 0.01) continue;
            CGRect titleFrame = [source convertRect:source.bounds toView:overlay];
            if (!CGRectIntersectsRect(overlay.bounds, titleFrame)) continue;
            NSString *title = source.text ?: source.attributedText.string;
            NSString *symbolName = [self actionSymbolForTitle:title];
            NSDictionary *parts = [rows objectForKey:source];
            if (!parts) {
                UILabel *label = [UILabel new];
                UIImageView *icon = [UIImageView new];
                label.isAccessibilityElement = NO;
                icon.isAccessibilityElement = NO;
                icon.userInteractionEnabled = NO;
                icon.contentMode = UIViewContentModeScaleAspectFit;
                parts = @{ @"label": label, @"icon": icon };
                [rows setObject:parts forKey:source];
                [overlay addSubview:label];
                [overlay addSubview:icon];
            }
            UILabel *label = parts[@"label"];
            UIImageView *icon = parts[@"icon"];
            if (!CGRectEqualToRect(label.frame, titleFrame)) label.frame = titleFrame;
            if (![label.text isEqualToString:title]) label.text = title;
            label.font = source.font;
            label.textAlignment = source.textAlignment;
            label.numberOfLines = source.numberOfLines;
            label.lineBreakMode = source.lineBreakMode;
            label.textColor = disabledText;
            UIImageView *native = [self actionIconInCell:cell];
            CGRect iconFrame = native ? [native convertRect:native.bounds toView:overlay] :
                CGRectMake(CGRectGetMinX(titleFrame) - 32, CGRectGetMidY(titleFrame) - 10, 20, 20);
            if (!CGRectEqualToRect(icon.frame, iconFrame)) icon.frame = iconFrame;
            UIImage *symbol = [self disabledActionSymbolNamed:symbolName];
            if (icon.image != symbol) icon.image = symbol;
            [visibleParts addObject:label];
            [visibleParts addObject:icon];
        }
    }
    // 复用、滚动及取消选择时清理旧镜像；不安排额外布局或轮询。
    for (UIView *part in overlay.subviews.copy)
        if (![visibleParts containsObject:part]) [part removeFromSuperview];
    for (UILabel *source in rows.keyEnumerator.allObjects) {
        NSDictionary *parts = [rows objectForKey:source];
        if (![visibleParts containsObject:parts[@"label"]]) [rows removeObjectForKey:source];
    }
    if (!visibleParts.count) [self removeSelectionOverlayFromObject:mask];
}

+ (BOOL)applySelectionMask:(UIView *)view controller:(UIViewController *)controller {
    if (![self isSelectionMask:view controller:controller]) {
        [self removeSelectionOverlayFromObject:view];
        return NO;
    }
    UIColor *resolved = [view.backgroundColor resolvedColorWithTraitCollection:
        [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]];
    CGFloat r = 0, g = 0, b = 0, alpha = 0;
    if (![resolved getRed:&r green:&g blue:&b alpha:&alpha] || alpha <= 0.01 || alpha > 0.9 ||
        MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) >= 0.12) {
        [self removeSelectionOverlayFromObject:view];
        return NO;
    }
    // 保留原生遮罩的不透明度与触摸拦截，只改成同主题深色，不清空或移除遮罩。
    if (MAX(r, MAX(g, b)) >= 0.8)
        [self write:[UIColor colorWithWhite:0.10 alpha:alpha] key:@"backgroundColor" object:view controller:controller];
    [self synchronizeSelectionMask:view controller:controller];
    return YES;
}

+ (BOOL)applyCard:(UIView *)cell controller:(UIViewController *)controller {
    BOOL handled = NO;
    // 卡片白底直接画在 CAShapeLayer 上，修改 UIView 的主题不会改变它。
    CALayer *layer = [self cardLayerInCell:cell];
    if ([layer isKindOfClass:CALayer.class]) {
        BOOL shape = [layer isKindOfClass:CAShapeLayer.class];
        CGColorRef fill = shape ? ((CAShapeLayer *)layer).fillColor : layer.backgroundColor;
        UIColor *current = fill ? [UIColor colorWithCGColor:fill] : nil;
        NSDictionary *saved = objc_getAssociatedObject(layer, &kDYYYMenuPaletteShapeKey);
        UIColor *target = [UIColor colorWithWhite:0.17 alpha:1];
        if (saved || [self isNeutral:current minimum:0.8 opaque:YES]) {
            handled = YES;
            id original = saved && [self equal:current other:saved[@"applied"]] ? saved[@"original"] : (current ?: NSNull.null);
            objc_setAssociatedObject(layer, &kDYYYMenuPaletteShapeKey,
                @{ @"original": original, @"applied": target, @"shape": @(shape) }, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [[self objectsForController:controller] addObject:layer];
            if (![self equal:current other:target]) {
                if (shape) ((CAShapeLayer *)layer).fillColor = target.CGColor;
                else layer.backgroundColor = target.CGColor;
            }
        }
    }
    // 只接管功能行的专用图标；好友头像和识图缩略图保持原图。
    UIImageView *icon = [self actionIconInCell:cell];
    if (![self applyReadableActionIconInCell:cell controller:controller] && [icon isKindOfClass:UIImageView.class] && icon.image) {
        if (icon.image.renderingMode != UIImageRenderingModeAlwaysTemplate)
            [self write:[icon.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] key:@"image" object:icon controller:controller];
        [self write:UIColor.whiteColor key:@"tintColor" object:icon controller:controller];
    }
    return handled;
}

+ (CALayer *)cardLayerInCell:(UIView *)cell {
    id direct = [self ivar:"contentShapeLayer" inCell:cell];
    if ([direct isKindOfClass:CALayer.class]) return direct;
    // 成员名变化时，只在这一功能行内找大块中性白色绘制层，不处理图片视图的图层。
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cell];
    for (NSUInteger index = 0; index < queue.count && index < 32; index++) {
        UIView *view = queue[index];
        if ([view isKindOfClass:UIImageView.class]) continue;
        for (CALayer *layer in view.layer.sublayers) {
            if ([layer.delegate isKindOfClass:UIView.class]) continue;
            BOOL shape = [layer isKindOfClass:CAShapeLayer.class];
            CGColorRef fill = shape ? ((CAShapeLayer *)layer).fillColor : layer.backgroundColor;
            CGRect rect = layer.bounds;
            if (shape && ((CAShapeLayer *)layer).path) rect = CGPathGetBoundingBox(((CAShapeLayer *)layer).path);
            if (rect.size.width < cell.bounds.size.width * 0.5 || rect.size.height < 16) continue;
            if (objc_getAssociatedObject(layer, &kDYYYMenuPaletteShapeKey) ||
                (fill && [self isNeutral:[UIColor colorWithCGColor:fill] minimum:0.8 opaque:YES])) return layer;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

+ (void)applyInView:(UIView *)root controller:(UIViewController *)controller {
    if (!NSThread.isMainThread || !root || !controller) return;
    if ([DYYYCommentMenuTheme styleForController:controller] != UIUserInterfaceStyleDark) {
        [self restoreController:controller];
        return;
    }
    if (objc_getAssociatedObject(controller, &kDYYYMenuPaletteBusyKey)) return;
    objc_setAssociatedObject(controller, &kDYYYMenuPaletteBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try {
        UIColor *panel = [UIColor colorWithWhite:0.10 alpha:1];
        Class cardClass = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
        NSUInteger backgrounds = 0, labels = 0, cards = 0;
        for (NSUInteger index = 0; index < queue.count && index < 400; index++) {
            UIView *view = queue[index];
            if ([DYYYPanelBlur isManagedEffectView:view] || [self isManagedSelectionOverlay:view]) continue;
            if (cardClass && [view isKindOfClass:cardClass] && [self applyCard:view controller:controller]) cards++;
            if ([view isKindOfClass:UIImageView.class]) continue;
            if (view.overrideUserInterfaceStyle == UIUserInterfaceStyleLight)
                [self write:@(UIUserInterfaceStyleDark) key:@"overrideUserInterfaceStyle" object:view controller:controller];
            if ([self applySelectionMask:view controller:controller]) backgrounds++;
            if ([self isNeutral:view.backgroundColor minimum:0.8 opaque:YES]) {
                [self write:panel key:@"backgroundColor" object:view controller:controller]; backgrounds++;
            }
            if ([view isKindOfClass:UILabel.class]) {
                [self applyLabel:(UILabel *)view controller:controller];
                labels++;
            }
            if ([view isKindOfClass:UIVisualEffectView.class]) {
                UIVisualEffectView *effectView = (UIVisualEffectView *)view;
                if ([effectView.effect isKindOfClass:UIBlurEffect.class]) {
                    NSDictionary *saved = objc_getAssociatedObject(view, &kDYYYMenuPaletteChangesKey);
                    if (!saved[@"effect"])
                        [self write:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark] key:@"effect" object:view controller:controller];
                }
                // 效果视图内部是 UIKit 绘制层，只处理其 contentView。
                [queue addObject:effectView.contentView];
                continue;
            }
            [queue addObjectsFromArray:view.subviews];
        }
        NSNumber *signature = @(backgrounds + labels * 1000 + cards * 1000000);
        if (root == controller.viewIfLoaded && ![objc_getAssociatedObject(controller, &kDYYYMenuPaletteReportKey) isEqual:signature]) {
            objc_setAssociatedObject(controller, &kDYYYMenuPaletteReportKey, signature, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [NSNotificationCenter.defaultCenter postNotificationName:@"DYYYCommentInputThemeDidChange" object:nil userInfo:@{
                @"phase": @"commentMenuNativePaletteApplied", @"backgrounds": @(backgrounds), @"labels": @(labels), @"cards": @(cards)
            }];
        }
    } @finally {
        [CATransaction commit];
        objc_setAssociatedObject(controller, &kDYYYMenuPaletteBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (void)restoreObject:(id)object {
    [self removeSelectionOverlayFromObject:object];
    [self removeActionOverlayFromObject:object];
    NSDictionary *changes = objc_getAssociatedObject(object, &kDYYYMenuPaletteChangesKey);
    objc_setAssociatedObject(object, &kDYYYMenuPaletteChangesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSString *key in changes) {
        @try {
            NSDictionary *change = changes[key];
            if ([self equal:[object valueForKey:key] other:change[@"applied"]])
                [object setValue:change[@"original"] == NSNull.null ? nil : change[@"original"] forKey:key];
        } @catch (__unused NSException *exception) {}
    }
    NSDictionary *shape = objc_getAssociatedObject(object, &kDYYYMenuPaletteShapeKey);
    if (shape && [object isKindOfClass:CALayer.class]) {
        CALayer *layer = object;
        UIColor *original = shape[@"original"] == NSNull.null ? nil : shape[@"original"];
        BOOL isShape = [shape[@"shape"] boolValue];
        CGColorRef current = isShape ? ((CAShapeLayer *)layer).fillColor : layer.backgroundColor;
        if (current && [[UIColor colorWithCGColor:current] isEqual:shape[@"applied"]]) {
            if (isShape) ((CAShapeLayer *)layer).fillColor = original.CGColor;
            else layer.backgroundColor = original.CGColor;
        }
        objc_setAssociatedObject(object, &kDYYYMenuPaletteShapeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread || !controller) return;
    NSHashTable *objects = objc_getAssociatedObject(controller, &kDYYYMenuPaletteObjectsKey);
    for (id object in objects.allObjects) [self restoreObject:object];
    [objects removeAllObjects];
}

+ (void)restoreView:(UIView *)root {
    if (!NSThread.isMainThread || !root) return;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger index = 0; index < queue.count && index < 80; index++) {
        UIView *view = queue[index];
        [self restoreObject:view];
        id layer = [self cardLayerInCell:view];
        if ([layer isKindOfClass:CALayer.class]) [self restoreObject:layer];
        [queue addObjectsFromArray:view.subviews];
    }
}
@end
