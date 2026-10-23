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
#import "AwemeHeaders.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <string.h>

static char kDYYYMenuPaletteChangesKey;
static char kDYYYMenuPaletteObjectsKey;
static char kDYYYMenuPaletteBusyKey;
static char kDYYYMenuPaletteShapeKey;
static char kDYYYMenuPaletteReportKey;

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

+ (void)synchronizeCell:(UIView *)cell {
    UIViewController *controller = [DYYYCommentMenuTheme controllerForView:cell];
    if (controller && cell.window) [self applyInView:cell controller:controller];
    else [self restoreView:cell];
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
    if ([icon isKindOfClass:UIImageView.class] && icon.image) {
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
            if (cardClass && [view isKindOfClass:cardClass] && [self applyCard:view controller:controller]) cards++;
            if ([view isKindOfClass:UIImageView.class]) continue;
            if (view.overrideUserInterfaceStyle == UIUserInterfaceStyleLight)
                [self write:@(UIUserInterfaceStyleDark) key:@"overrideUserInterfaceStyle" object:view controller:controller];
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
