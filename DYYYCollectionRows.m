/*
  合集整行显隐适配自 DYKiller：
  src/Features/Interaction/DKElementRowHiding.xm
  src/Features/PlaybackClean/DKPlaybackCleanRules.m
  https://github.com/HierarchThurs/DYKiller/tree/a2a74b70c0f23d456c0331a67a24dc3e351ed2c1

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
#import "DYYYCollectionRows.h"
#import "AwemeHeaders.h"
#import <objc/runtime.h>

static char kDYYYCollectionRowHostKey;
static char kDYYYCollectionRowRemovedKey;
static char kDYYYCollectionRowBusyKey;
static char kDYYYCollectionStackBusyKey;
static char kDYYYCollectionLookupBusyKey;
static char kDYYYCollectionTemplateKindKey;

@implementation DYYYCollectionRows

+ (id)value:(id)object key:(NSString *)key {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *exception) { return nil; }
}
+ (NSUInteger)flags {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return ([defaults boolForKey:@"DYYYHideTemplateVideo"] ? 1 : 0) | ([defaults boolForKey:@"DYYYHideTemplatePlaylet"] ? 2 : 0);
}
// 只读原生元素身份；不查找控制器、创建容器，也不遍历 UILabel。
+ (NSUInteger)elementKind:(UIView *)row {
    Class rowClass = NSClassFromString(@"AWEBaseElementView");
    if (!rowClass || ![row isKindOfClass:rowClass]) return 0;
    if (objc_getAssociatedObject(row, &kDYYYCollectionLookupBusyKey)) return 0;
    objc_setAssociatedObject(row, &kDYYYCollectionLookupBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        id element = [self value:row key:@"element"];
        if (!element) return 0;
        Class mixClass = NSClassFromString(@"AWEPlayInteractionNewMixVideoInfoElement");
        if (mixClass && [element isKindOfClass:mixClass]) return 1;
        Class templateClass = NSClassFromString(@"AWETemplateNewBottomElement");
        if (templateClass && [element isKindOfClass:templateClass] && [[self value:element key:@"identifier"] isEqual:@"playlet_bar"]) return 2;
        return 0;
    } @finally {
        objc_setAssociatedObject(row, &kDYYYCollectionLookupBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
+ (BOOL)removeRow:(UIView *)row {
    NSUInteger flags = [self flags];
    if (!flags) return NO;
    NSUInteger elementKind = [self elementKind:row];
    if (elementKind == 1) return (flags & 1) != 0;
    if (elementKind != 2) return NO;
    if (flags == 3) return YES;
    // DYK 将 playlet_bar 统一归为合集；DYYY 保留两个开关，在布局入口缓存普通合集/短剧分类。
    NSUInteger kind = [objc_getAssociatedObject(row, &kDYYYCollectionTemplateKindKey) unsignedIntegerValue];
    return kind && (flags & kind) != 0;
}
+ (BOOL)requestedHidden:(BOOL)hidden row:(UIView *)row {
    if (!NSThread.isMainThread || objc_getAssociatedObject(row, &kDYYYCollectionRowBusyKey)) return hidden;
    objc_setAssociatedObject(row, &kDYYYCollectionRowBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        BOOL remove = [self removeRow:row];
        // 未接管时也记录原生请求，避免复用后拿到上个内容的显隐状态。
        objc_setAssociatedObject(row, &kDYYYCollectionRowHostKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(row, &kDYYYCollectionRowRemovedKey, remove ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return hidden || remove;
    } @finally {
        objc_setAssociatedObject(row, &kDYYYCollectionRowBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
+ (void)syncRow:(UIView *)row {
    BOOL removed = objc_getAssociatedObject(row, &kDYYYCollectionRowRemovedKey) != nil;
    BOOL remove = [self removeRow:row];
    if (!removed && !remove) return;
    NSNumber *host = objc_getAssociatedObject(row, &kDYYYCollectionRowHostKey);
    BOOL hostHidden = host ? host.boolValue : row.hidden;
    if (removed != remove || row.hidden != (hostHidden || remove)) row.hidden = hostHidden;
}
+ (void)applyStack:(UIView *)stack {
    if (!NSThread.isMainThread || objc_getAssociatedObject(stack, &kDYYYCollectionStackBusyKey) ||
        ![stack respondsToSelector:@selector(arrangedSubviews)]) return;
    objc_setAssociatedObject(stack, &kDYYYCollectionStackBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        id arranged = ((UIStackView *)stack).arrangedSubviews;
        if (![arranged isKindOfClass:NSArray.class]) return;
        NSArray *rows = [arranged copy];
        // 单独启用一个开关时，才在原生布局开始前读取已存在的交互模型，绝不在 setHidden 内读取它。
        NSUInteger flags = [self flags];
        NSUInteger templateKind = 0;
        BOOL lookedUpModel = NO;
        for (UIView *row in rows) {
            NSUInteger elementKind = [self elementKind:row];
            if (elementKind == 2 && (flags == 1 || flags == 2)) {
                if (!lookedUpModel) {
                    lookedUpModel = YES;
                    Class interactionClass = NSClassFromString(@"AWEPlayInteractionViewController");
                    for (UIResponder *responder = stack.nextResponder; responder; responder = responder.nextResponder) {
                        if (interactionClass && [responder isKindOfClass:interactionClass]) {
                            id model = ((AWEPlayInteractionViewController *)responder).model;
                            if (model) {
                                id playlet = [self value:model key:@"playletInfoModel"];
                                templateKind = playlet && playlet != NSNull.null ? 2 : 1;
                            }
                            break;
                        }
                    }
                }
                objc_setAssociatedObject(row, &kDYYYCollectionTemplateKindKey, templateKind ? @(templateKind) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else if (elementKind != 2) {
                objc_setAssociatedObject(row, &kDYYYCollectionTemplateKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (elementKind || objc_getAssociatedObject(row, &kDYYYCollectionRowRemovedKey)) [self syncRow:row];
        }
    } @finally {
        objc_setAssociatedObject(stack, &kDYYYCollectionStackBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
@end
