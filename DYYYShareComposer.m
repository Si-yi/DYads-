#import "DYYYShareComposer.h"
#import "DYYYCommentMenuTheme.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>
#import <math.h>

static char kDYYYShareComposerStateKey;

@interface DYYYShareComposerState : NSObject
@property (nonatomic, weak) UITextView *input;
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, strong) UIColor *nativeColor;
@property (nonatomic, strong) UIColor *appliedColor;
@property (nonatomic, strong) NSMutableDictionary *changes;
@property (nonatomic, strong) NSArray *tokens;
@property (nonatomic, strong) CALayer *outline;
@property (nonatomic, assign) CGFloat nativeLeftInset;
@property (nonatomic, assign) CGFloat appliedLeftInset;
@property (nonatomic, assign) BOOL insetChanged;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) BOOL restoring;
@property (nonatomic, weak) UIImageView *preview;
@property (nonatomic, assign) CGAffineTransform nativePreviewTransform;
@property (nonatomic, assign) CGAffineTransform appliedPreviewTransform;
@property (nonatomic, assign) BOOL previewChanged;
@end
@implementation DYYYShareComposerState
- (void)dealloc {
    for (id token in _tokens) [NSNotificationCenter.defaultCenter removeObserver:token];
    CALayer *outline = _outline;
    if (NSThread.isMainThread) [outline removeFromSuperlayer];
    else dispatch_async(dispatch_get_main_queue(), ^{ [outline removeFromSuperlayer]; });
}
@end

@implementation DYYYShareComposer

+ (NSHashTable *)states {
    static NSHashTable *states;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ states = [NSHashTable weakObjectsHashTable]; });
    return states;
}

+ (UIView *)composerForInput:(UITextView *)input {
    Class editor = NSClassFromString(@"AWEIMShareImpl.ShareTextView");
    if (!editor || ![input isKindOfClass:editor]) return nil;
    for (UIView *view = input.superview; view; view = view.superview)
        if ([NSStringFromClass(view.class) isEqualToString:@"AWEIMShareImpl.ShareAdditionTextView"]) return view;
    return nil;
}

+ (BOOL)managedInput:(UITextView *)input {
    UIView *composer = [self composerForInput:input];
    return NSThread.isMainThread && input.window && !input.hidden && input.alpha > 0.01 &&
        composer && !composer.hidden && composer.alpha > 0.01 &&
        [NSUserDefaults.standardUserDefaults boolForKey:@"DYYYEnableCommentMenuBlur"] &&
        [DYYYCommentMenuTheme controllerForView:input];
}

+ (BOOL)equal:(id)a other:(id)b { return a == b || [a isEqual:b]; }

+ (UIColor *)neutralReplacement:(UIColor *)source target:(UIColor *)target {
    if (!source) return target;
    UIColor *resolved = [source resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:
        [DYYYUtils isDarkMode] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight]];
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![resolved getRed:&r green:&g blue:&b alpha:&a] || a <= 0.01 ||
        MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) >= 0.12) return source;
    return target;
}

+ (UIColor *)targetColor {
    return [UIColor colorWithWhite:[DYYYUtils isDarkMode] ? 0.96 : 0.14 alpha:1];
}

+ (DYYYShareComposerState *)stateForInput:(UITextView *)input create:(BOOL)create {
    DYYYShareComposerState *state = objc_getAssociatedObject(input, &kDYYYShareComposerStateKey);
    if (state || !create) return state;
    state = [DYYYShareComposerState new];
    state.input = input;
    state.controller = [DYYYCommentMenuTheme controllerForView:input];
    state.nativeColor = input.textColor;
    state.nativeLeftInset = input.textContainerInset.left;
    state.changes = [NSMutableDictionary dictionary];
    __weak DYYYShareComposerState *weakState = state;
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSNotificationName name in @[ UITextViewTextDidBeginEditingNotification, UITextViewTextDidChangeNotification, UITextViewTextDidEndEditingNotification ]) {
        id token = [NSNotificationCenter.defaultCenter addObserverForName:name object:input queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            DYYYShareComposerState *current = weakState;
            if (current && !current.busy) [self synchronizeInput:current.input];
        }];
        [tokens addObject:token];
    }
    state.tokens = tokens;
    objc_setAssociatedObject(input, &kDYYYShareComposerStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self states] addObject:state];
    return state;
}

+ (void)remember:(id)source applied:(id)value key:(NSString *)key state:(DYYYShareComposerState *)state {
    if ([self equal:source other:value]) return;
    NSDictionary *previous = state.changes[key];
    id original = previous && [self equal:source other:previous[@"applied"]] ? previous[@"original"] : (source ?: NSNull.null);
    state.changes[key] = @{ @"original": original, @"applied": value ?: NSNull.null };
}

+ (void)write:(id)value key:(NSString *)key state:(DYYYShareComposerState *)state {
    id current = [state.input valueForKey:key];
    if ([self equal:current other:value]) return;
    [self remember:current applied:value key:key state:state];
    [state.input setValue:value forKey:key];
}

+ (UIColor *)adjustTextColor:(UIColor *)color input:(UITextView *)input {
    DYYYShareComposerState *state = [self stateForInput:input create:NO];
    if (state.restoring || ![self managedInput:input]) return color;
    state = state ?: [self stateForInput:input create:YES];
    state.controller = [DYYYCommentMenuTheme controllerForView:input];
    UIColor *target = [self neutralReplacement:color target:[self targetColor]];
    if (!state.busy && ![self equal:color other:target]) {
        state.nativeColor = color;
        [self remember:color applied:target key:@"textColor" state:state];
    }
    return target;
}

+ (NSDictionary *)adjustTypingAttributes:(NSDictionary *)attributes input:(UITextView *)input {
    DYYYShareComposerState *state = [self stateForInput:input create:NO];
    if (state.restoring || ![self managedInput:input]) return attributes;
    state = state ?: [self stateForInput:input create:YES];
    state.controller = [DYYYCommentMenuTheme controllerForView:input];
    UIColor *source = attributes[NSForegroundColorAttributeName];
    if (source && ![source isKindOfClass:UIColor.class]) return attributes;
    UIColor *target = [self neutralReplacement:source target:[self targetColor]];
    if ([self equal:source other:target]) return attributes;
    NSMutableDictionary *result = [attributes mutableCopy] ?: [NSMutableDictionary dictionary];
    result[NSForegroundColorAttributeName] = target;
    if (!state.busy) [self remember:attributes applied:result key:@"typingAttributes" state:state];
    return result;
}

+ (void)paintNeutralRuns:(UITextView *)input target:(UIColor *)target restoring:(BOOL)restoring state:(DYYYShareComposerState *)state {
    if (input.markedTextRange || !input.textStorage.length) return;
    NSMutableArray *ranges = [NSMutableArray array];
    [input.textStorage enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, input.textStorage.length) options:0 usingBlock:^(id color, NSRange range, BOOL *stop) {
        if (![color isKindOfClass:UIColor.class]) return;
        UIColor *replacement = restoring ? ([self equal:color other:state.appliedColor] ? target : color) :
            [self neutralReplacement:color target:target];
        if (![self equal:color other:replacement]) [ranges addObject:@{ @"range": [NSValue valueWithRange:range], @"color": replacement }];
    }];
    if (!ranges.count) return;
    NSUndoManager *undo = input.undoManager;
    BOOL registration = undo.isUndoRegistrationEnabled;
    if (registration) [undo disableUndoRegistration];
    [input.textStorage beginEditing];
    @try {
        for (NSDictionary *run in ranges)
            [input.textStorage addAttribute:NSForegroundColorAttributeName value:run[@"color"] range:[run[@"range"] rangeValue]];
    } @finally {
        [input.textStorage endEditing];
        if (registration) [undo enableUndoRegistration];
    }
}

+ (void)synchronizeInput:(UITextView *)input {
    if (!NSThread.isMainThread) return;
    if (![input isKindOfClass:UITextView.class]) return;
    if (![self managedInput:input]) { [self restoreInput:input]; return; }
    DYYYShareComposerState *state = [self stateForInput:input create:YES];
    if (state.busy) return;
    state.controller = [DYYYCommentMenuTheme controllerForView:input];
    state.busy = YES;
    @try {
        UIColor *target = [self targetColor];
        __block BOOL hasColoredRuns = NO;
        [input.textStorage enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, input.textStorage.length) options:0 usingBlock:^(id color, NSRange range, BOOL *stop) {
            if ([color isKindOfClass:UIColor.class] && ![self equal:[self neutralReplacement:color target:target] other:target]) { hasColoredRuns = YES; *stop = YES; }
        }];
        // 不替换 attributedText/text，不改光标、选区或 markedText。彩色提及保留原色。
        if (!hasColoredRuns && !input.markedTextRange) {
            UIColor *color = [self neutralReplacement:input.textColor target:target];
            [self write:color key:@"textColor" state:state];
        }
        NSMutableDictionary *typing = [input.typingAttributes mutableCopy] ?: [NSMutableDictionary dictionary];
        UIColor *source = typing[NSForegroundColorAttributeName];
        if (!source || [source isKindOfClass:UIColor.class]) {
            typing[NSForegroundColorAttributeName] = [self neutralReplacement:source target:target];
            [self write:typing key:@"typingAttributes" state:state];
        }
        [self paintNeutralRuns:input target:target restoring:NO state:state];
        state.appliedColor = target;
        UIView *composer = [self composerForInput:input];
        UIView *host = [composer isKindOfClass:UIVisualEffectView.class] ? ((UIVisualEffectView *)composer).contentView : composer;
        CGRect rect = [input convertRect:input.bounds toView:host];
        CGFloat leading = 16;
        for (UIView *view in host.subviews)
            if ([view isKindOfClass:UIStackView.class] && CGRectGetHeight(view.bounds) >= 36) { leading = CGRectGetMinX(view.frame); break; }
        CGFloat right = CGRectGetMaxX(host.bounds) - leading;
        CGRect frame = CGRectMake(leading, CGRectGetMinY(rect) + 4, right - leading, CGRectGetHeight(rect) - 8);
        if (frame.size.width < 80 || frame.size.height < 24) return;
        UIImageView *preview = nil;
        for (UIView *view in host.subviews)
            if ([view isKindOfClass:UIImageView.class] && !view.hidden && view.alpha > 0.01 &&
                view.bounds.size.width >= 24 && CGRectGetMinX(view.frame) > CGRectGetMidX(host.bounds)) { preview = (id)view; break; }
        if (state.preview != preview && state.previewChanged) [self restorePreview:state];
        if (preview) {
            CGAffineTransform current = preview.transform;
            CGAffineTransform original = state.previewChanged && CGAffineTransformEqualToTransform(current, state.appliedPreviewTransform) ? state.nativePreviewTransform : current;
            CGFloat nativeRight = preview.center.x + preview.bounds.size.width * 0.5;
            CGAffineTransform applied = original;
            applied.tx += MIN(0, CGRectGetMaxX(frame) - 8 - nativeRight);
            state.preview = preview;
            state.nativePreviewTransform = original;
            state.appliedPreviewTransform = applied;
            state.previewChanged = YES;
            if (!CGAffineTransformEqualToTransform(current, applied)) preview.transform = applied;
        }
        UIEdgeInsets inset = input.textContainerInset;
        if (!state.insetChanged || fabs(inset.left - state.appliedLeftInset) > 0.1) state.nativeLeftInset = inset.left;
        CGFloat left = MAX(state.nativeLeftInset, leading - CGRectGetMinX(rect) + 8 - input.textContainer.lineFragmentPadding);
        if (fabs(inset.left - left) > 0.1) { inset.left = left; input.textContainerInset = inset; }
        state.appliedLeftInset = left;
        state.insetChanged = YES;
        if (!state.outline) {
            state.outline = [CALayer layer];
            state.outline.name = @"DYYY.CommentMenu.ShareInput";
            state.outline.cornerCurve = kCACornerCurveContinuous;
            [host.layer insertSublayer:state.outline atIndex:0];
        } else if (state.outline.superlayer != host.layer) [host.layer insertSublayer:state.outline atIndex:0];
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        if (!CGRectEqualToRect(state.outline.frame, frame)) state.outline.frame = frame;
        state.outline.cornerRadius = 10;
        BOOL dark = [DYYYUtils isDarkMode];
        CGFloat opacity = [DYYYUtils sharedBlurTransparency];
        state.outline.backgroundColor = [UIColor colorWithWhite:dark ? 0.22 : 1 alpha:0.40 * opacity].CGColor;
        state.outline.borderColor = [UIColor colorWithWhite:dark ? 1 : 0 alpha:(dark ? 0.20 : 0.12) * opacity].CGColor;
        state.outline.borderWidth = 1 / MAX(input.window.screen.scale, 1);
        [CATransaction commit];
    } @finally { state.busy = NO; }
}

+ (void)restorePreview:(DYYYShareComposerState *)state {
    if (state.previewChanged && CGAffineTransformEqualToTransform(state.preview.transform, state.appliedPreviewTransform))
        state.preview.transform = state.nativePreviewTransform;
    state.previewChanged = NO;
    state.preview = nil;
}

+ (void)restoreInput:(UITextView *)input {
    if (!NSThread.isMainThread) return;
    DYYYShareComposerState *state = [self stateForInput:input create:NO];
    if (!state || state.busy) return;
    state.busy = YES;
    state.restoring = YES;
    @try {
        [state.outline removeFromSuperlayer];
        state.outline = nil;
        [self restorePreview:state];
        [self paintNeutralRuns:input target:state.nativeColor ?: UIColor.labelColor restoring:YES state:state];
        __block BOOL hasColoredRuns = NO;
        [input.textStorage enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, input.textStorage.length) options:0 usingBlock:^(id color, NSRange range, BOOL *stop) {
            if ([color isKindOfClass:UIColor.class] && ![self equal:[self neutralReplacement:color target:[self targetColor]] other:[self targetColor]]) { hasColoredRuns = YES; *stop = YES; }
        }];
        for (NSString *key in state.changes) {
            if ([key isEqualToString:@"textColor"] && (hasColoredRuns || input.markedTextRange)) continue;
            NSDictionary *change = state.changes[key];
            id current = [input valueForKey:key] ?: NSNull.null;
            if ([self equal:current other:change[@"applied"]])
                [input setValue:change[@"original"] == NSNull.null ? nil : change[@"original"] forKey:key];
        }
        UIEdgeInsets inset = input.textContainerInset;
        if (state.insetChanged && fabs(inset.left - state.appliedLeftInset) < 0.1) { inset.left = state.nativeLeftInset; input.textContainerInset = inset; }
        objc_setAssociatedObject(input, &kDYYYShareComposerStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally { state.restoring = NO; state.busy = NO; }
}

+ (void)restoreController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return;
    for (DYYYShareComposerState *state in [self states].allObjects)
        if (state.controller == controller) [self restoreInput:state.input];
}

+ (NSArray *)colorSummary:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color isKindOfClass:UIColor.class] || ![color getRed:&r green:&g blue:&b alpha:&a]) return @[];
    return @[ @(r), @(g), @(b), @(a) ];
}

+ (NSDictionary *)diagnosticsForController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return @{ @"mainThread": @NO };
    NSMutableArray *inputs = [NSMutableArray array];
    for (DYYYShareComposerState *state in [self states].allObjects) {
        if (state.controller != controller || !state.input) continue;
        [inputs addObject:@{ @"class": NSStringFromClass(state.input.class), @"borderFrame": NSStringFromCGRect(state.outline.frame),
            @"attached": @(state.outline.superlayer != nil), @"previewIncluded": @(state.preview != nil), @"marked": @(state.input.markedTextRange != nil),
            @"dark": @([DYYYUtils isDarkMode]), @"leftInset": @(state.input.textContainerInset.left),
            @"foreground": [self colorSummary:state.input.textColor],
            @"typingForeground": [self colorSummary:state.input.typingAttributes[NSForegroundColorAttributeName]] }];
    }
    return @{ @"inputs": inputs };
}
@end
