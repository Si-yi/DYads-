/*
 两列功能菜单沿用 DYKiller DKCommentMenuGrid.xm 的原生分区尺寸接口与内容对齐方式。
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
#import "DYYYCommentMenuGrid.h"
#import "DYYYCommentMenuTheme.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYCommentGridInfoKey;
static char kDYYYCommentGridTransformKey;

@implementation DYYYCommentMenuGrid

+ (BOOL)enabledForSection:(DYYYCommentMenuNormalSection *)section {
    UIViewController *controller = section.viewController;
    return NSThread.isMainThread && [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] &&
        ([DYYYCommentMenuTheme menuControllerForController:controller] != nil ||
         [NSStringFromClass(controller.class) isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCollectionViewController"]);
}

+ (CGSize)sizeForSection:(id)section index:(NSInteger)index original:(CGSize)original collectionSize:(CGSize)size {
    if (![self enabledForSection:section]) return original;
    NSInteger count = [(DYYYCommentMenuNormalSection *)section numberOfItems];
    if (count <= 0 || index < 0 || index >= count || size.width < 280 || original.height < 36) return original;
    // 两列共用原生分区。奇数末项补满，避免流式布局居中、拉开或留下可点击的空白半格。
    if (index == count - 1 && index % 2 == 0) return CGSizeMake(size.width, original.height);
    CGFloat left = floor((size.width - 32) * 0.5) + 16;
    return CGSizeMake(index % 2 == 0 ? left : size.width - left, original.height);
}

+ (UIView *)mainViewForCell:(UIView *)cell {
    Class base = NSClassFromString(@"CommentLongPressPanelNormalBaseCell");
    Ivar ivar = base ? class_getInstanceVariable(base, "$__lazy_storage_$_mainView") : NULL;
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if (!ivar || !type || type[0] != '@' || ![cell isKindOfClass:base]) return nil;
    id main = object_getIvar(cell, ivar);
    return [main isKindOfClass:UIView.class] ? main : nil;
}

+ (void)configureCell:(UIView *)cell section:(id)section index:(NSInteger)index {
    if (![cell isKindOfClass:UIView.class]) return;
    if (![self enabledForSection:section]) { [self restoreCell:cell]; return; }
    NSArray *info = @[ @(index), @([(DYYYCommentMenuNormalSection *)section numberOfItems]) ];
    if ([objc_getAssociatedObject(cell, &kDYYYCommentGridInfoKey) isEqual:info]) return;
    [self restoreContentInCell:cell];
    objc_setAssociatedObject(cell, &kDYYYCommentGridInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cell setNeedsLayout];
}

+ (void)restoreContentInCell:(UIView *)cell {
    NSDictionary *saved = objc_getAssociatedObject(cell, &kDYYYCommentGridTransformKey);
    UIView *main = [self mainViewForCell:cell];
    if (saved && main && CGAffineTransformEqualToTransform(main.transform, [saved[@"applied"] CGAffineTransformValue]))
        main.transform = [saved[@"original"] CGAffineTransformValue];
    objc_setAssociatedObject(cell, &kDYYYCommentGridTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)layoutCell:(UIView *)cell {
    NSArray *info = objc_getAssociatedObject(cell, &kDYYYCommentGridInfoKey);
    UIViewController *menu = [DYYYCommentMenuTheme controllerForView:cell];
    if (!info || ![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] || (!menu && cell.window)) {
        [self restoreCell:cell]; return;
    }
    if (!menu) return; // 创建期间先保留分区信息，实际挂入菜单后再对齐。
    UIView *main = [self mainViewForCell:cell];
    if (!main || !main.superview || cell.bounds.size.width < 100) return;
    // 右列内容左移 12pt；只叠加可恢复 transform，原生约束、文字大小和点击逻辑继续生效。
    CGFloat target = [info[0] integerValue] % 2 == 0 ? 16 : 4;
    CGPoint origin = [main.superview convertPoint:CGPointMake(main.center.x - main.bounds.size.width * 0.5,
        main.center.y - main.bounds.size.height * 0.5) toView:cell];
    NSDictionary *saved = objc_getAssociatedObject(cell, &kDYYYCommentGridTransformKey);
    CGAffineTransform current = main.transform;
    CGAffineTransform original = saved && CGAffineTransformEqualToTransform(current, [saved[@"applied"] CGAffineTransformValue]) ?
        [saved[@"original"] CGAffineTransformValue] : current;
    CGAffineTransform applied = original;
    applied.tx += target - origin.x;
    if (!CGAffineTransformEqualToTransform(current, applied)) {
        objc_setAssociatedObject(cell, &kDYYYCommentGridTransformKey,
            @{ @"original": [NSValue valueWithCGAffineTransform:original], @"applied": [NSValue valueWithCGAffineTransform:applied] },
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        main.transform = applied;
    }
}

+ (void)restoreCell:(UIView *)cell {
    [self restoreContentInCell:cell];
    objc_setAssociatedObject(cell, &kDYYYCommentGridInfoKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
