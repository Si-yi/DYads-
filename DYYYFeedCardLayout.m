/*
  POI 卡片底部约束让位参考 DYKiller：
  src/Features/PlaybackClean/DKFeedCardFit.m
  src/Features/PlaybackClean/DKPlaybackCleanRules.m
  https://github.com/HierarchThurs/DYKiller/tree/bb11ab1d9cba9733d6720f0e2746dec21d6c6fe4

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
#import "DYYYFeedCardLayout.h"
#import "DYYYFeedCardPolicy.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYCardTableKey, kDYYYCardTableBusyKey, kDYYYCardControllerKey;
static NSUInteger DYYYCardFits, DYYYCardMissingConstraints;
@interface DYYYCardTableState : NSObject
@property (nonatomic, assign) CGRect nativeFrame;
@property (nonatomic, assign) CGRect appliedFrame;
@end
@implementation DYYYCardTableState
@end
@interface DYYYCardFitState : NSObject
@property (nonatomic, weak) NSLayoutConstraint *constraint;
@property (nonatomic, assign) CGFloat nativeConstant;
@property (nonatomic, assign) CGFloat appliedConstant;
@property (nonatomic, weak) UIView *container;
@property (nonatomic, strong) NSMapTable<UIView *, NSDictionary *> *children;
@end
@implementation DYYYCardFitState
@end
@implementation DYYYFeedCardLayout
+ (NSHashTable *)controllers {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}
+ (BOOL)isHome:(UIView *)view {
    Class root = NSClassFromString(@"AWEFeedRootViewController");
    UIResponder *next = view.nextResponder;
    for (NSUInteger i = 0; next && i < 40; i++, next = next.nextResponder) if (root && [next isKindOfClass:root]) return YES;
    return NO;
}
+ (void)rememberFrame:(CGRect)frame table:(UIView *)table {
    if (!NSThread.isMainThread || objc_getAssociatedObject(table, &kDYYYCardTableBusyKey) ||
        !isfinite(frame.size.height) || !isfinite(frame.size.width) || frame.size.height <= 0 || frame.size.width <= 0) return;
    DYYYCardTableState *state = objc_getAssociatedObject(table, &kDYYYCardTableKey);
    // 不把本轮拉满结果重新当成原高；新的原生窗口宽度/高度写入会自然更新基线。
    if (state && CGRectEqualToRect(frame, state.appliedFrame)) return;
    if (!state) { state = [DYYYCardTableState new]; objc_setAssociatedObject(table, &kDYYYCardTableKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    state.nativeFrame = frame;
    state.appliedFrame = CGRectNull;
}
+ (void)applyFrame:(CGRect)frame table:(UIView *)table {
    if (!NSThread.isMainThread || CGRectEqualToRect(frame, table.frame)) return;
    DYYYCardTableState *state = objc_getAssociatedObject(table, &kDYYYCardTableKey);
    if (!state) { [self rememberFrame:table.frame table:table]; state = objc_getAssociatedObject(table, &kDYYYCardTableKey); }
    state.appliedFrame = frame;
    objc_setAssociatedObject(table, &kDYYYCardTableBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try { table.frame = frame; }
    @finally { objc_setAssociatedObject(table, &kDYYYCardTableBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
+ (CGFloat)insetForView:(UIView *)view {
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableFullScreen"] || ![self isHome:view]) return 0;
    Class tableClass = NSClassFromString(@"AWEFeedTableView");
    UITableViewCell *cell = nil;
    UIView *table = view.superview;
    for (NSUInteger depth = 0; table && depth < 20; depth++, table = table.superview) {
        if ([table isKindOfClass:UITableViewCell.class]) cell = (id)table;
        if (tableClass && [table isKindOfClass:tableClass]) break;
    }
    if (!table || !cell || ![table isKindOfClass:tableClass]) return 0;
    DYYYCardTableState *state = objc_getAssociatedObject(table, &kDYYYCardTableKey);
    if (!state || !isfinite(state.nativeFrame.size.height) || state.nativeFrame.size.height <= 0 ||
        fabs(state.nativeFrame.size.width - table.bounds.size.width) > 1) return 0;
    CGPoint bottom = [cell convertPoint:CGPointMake(0, state.nativeFrame.size.height) toView:view];
    CGFloat inset = CGRectGetMaxY(view.bounds) - bottom.y;
    return isfinite(inset) && inset > 0.5 ? MIN(inset, view.bounds.size.height) : 0;
}
+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    DYYYCardFitState *state = objc_getAssociatedObject(controller, &kDYYYCardControllerKey);
    if (!state) return;
    if (state.constraint && fabs(state.constraint.constant - state.appliedConstant) <= 0.5) state.constraint.constant = state.nativeConstant;
    for (UIView *child in state.children) {
        NSDictionary *frames = [state.children objectForKey:child];
        if (child.superview == state.container && CGRectEqualToRect(child.frame, [frames[@"applied"] CGRectValue])) child.frame = [frames[@"native"] CGRectValue];
    }
    objc_setAssociatedObject(controller, &kDYYYCardControllerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (void)layoutController:(UIViewController *)controller afterLayout:(BOOL)afterLayout {
    if (!NSThread.isMainThread || !controller.isViewLoaded) return;
    UIView *container = nil;
    Class cls = NSClassFromString(@"AWEDynamicCardContainer");
    for (UIView *view in controller.view.subviews) if (cls && [view isKindOfClass:cls]) { container = view; break; }
    CGFloat inset = [self insetForView:container.superview];
    DYYYCardFitState *state = objc_getAssociatedObject(controller, &kDYYYCardControllerKey);
    if (!container || inset <= 0 || (state && state.container != container)) {
        [self restoreController:controller];
        if (!container || inset <= 0) return;
        state = nil;
    }
    if (afterLayout) {
        if (!state.constraint.active) return;
        // 仅同步实际的内容根，最多 16 项；不遍历 Lynx 内部节点、不强制 layoutIfNeeded。
        NSUInteger count = 0;
        for (UIView *child in container.subviews) {
            if (++count > 16) break;
            CGRect target = container.bounds;
            if (!CGRectEqualToRect(child.frame, target)) {
                NSDictionary *saved = [state.children objectForKey:child];
                CGRect native = saved && CGRectEqualToRect(child.frame, [saved[@"applied"] CGRectValue]) ? [saved[@"native"] CGRectValue] : child.frame;
                [state.children setObject:@{@"native": [NSValue valueWithCGRect:native], @"applied": [NSValue valueWithCGRect:target]} forKey:child];
                child.frame = target;
            }
        }
        return;
    }
    NSLayoutConstraint *bottom = nil;
    BOOL reversed = NO;
    UIView *anchor = container.superview;
    for (NSUInteger depth = 0; anchor && depth < 8; depth++, anchor = anchor.superview) {
        for (NSLayoutConstraint *constraint in anchor.constraints) {
            if (!constraint.active || constraint.relation != NSLayoutRelationEqual || constraint.multiplier != 1 || constraint.firstAttribute != NSLayoutAttributeBottom || constraint.secondAttribute != NSLayoutAttributeBottom) continue;
            if (constraint.firstItem == container && constraint.secondItem == anchor) { bottom = constraint; break; }
            if (constraint.firstItem == anchor && constraint.secondItem == container) { bottom = constraint; reversed = YES; break; }
        }
        if (bottom || [anchor isKindOfClass:UITableViewCell.class]) break;
    }
    if (!bottom) { DYYYCardMissingConstraints++; [self restoreController:controller]; return; }
    if (state && state.constraint != bottom) { [self restoreController:controller]; state = nil; }
    if (!state) {
        state = [DYYYCardFitState new]; state.constraint = bottom; state.nativeConstant = bottom.constant; state.appliedConstant = bottom.constant;
        state.container = container; state.children = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(controller, &kDYYYCardControllerKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self controllers] addObject:controller];
    }
    // 接受原生晚写的新常量，不能在每轮布局把自己的偏移再次扣除。
    if (fabs(bottom.constant - state.appliedConstant) > 0.5) state.nativeConstant = bottom.constant;
    state.appliedConstant = [DYYYFeedCardPolicy bottomConstant:state.nativeConstant inset:inset reversed:reversed];
    if (fabs(bottom.constant - state.appliedConstant) > 0.5) { bottom.constant = state.appliedConstant; DYYYCardFits++; }
}
+ (void)refresh {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; }); return; }
    for (UIViewController *controller in [self controllers].allObjects) {
        [self restoreController:controller]; [controller.viewIfLoaded setNeedsLayout];
    }
}
+ (NSDictionary *)diagnostics {
    return @{@"poiClassAvailable": @(NSClassFromString(@"AWEFeedPOIDynamicCardCellViewController") != nil), @"fits": @(DYYYCardFits), @"missingBottomConstraint": @(DYYYCardMissingConstraints)};
}
@end
