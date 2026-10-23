#import "DYYYAutoMessageQuietHoursPanel.h"
#import "DYYYAutoMessage.h"
#import "DYYYUtils.h"

@interface DYYYAutoMessageQuietHoursPanel () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIVisualEffectView *panel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *noteLabel;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIStackView *footer;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *periods;
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, strong) UIView *editorShade;
@property (nonatomic, strong) UIView *editor;
@property (nonatomic, strong) UILabel *editorTitle;
@property (nonatomic, strong) UIScrollView *editorBody;
@property (nonatomic, strong) UILabel *editorNote;
@property (nonatomic, strong) UITextField *startField;
@property (nonatomic, strong) UITextField *endField;
@property (nonatomic, strong) UIStackView *editorButtons;
@property (nonatomic) NSUInteger editingIndex;
@property (nonatomic) CGRect keyboardFrame;
@end

@implementation DYYYAutoMessageQuietHoursPanel

+ (void)showFrom:(UIViewController *)presenter onChange:(void (^)(void))onChange {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showFrom:presenter onChange:onChange]; }); return;
    }
    if (!presenter) return;
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed)
        presenter = presenter.presentedViewController;
    DYYYAutoMessageQuietHoursPanel *vc = [self new];
    vc.periods = [DYYYAutoMessage noSendTimePeriods];
    vc.onChange = onChange;
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:vc animated:YES completion:nil];
}
- (UIButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    button.backgroundColor = [color colorWithAlphaComponent:0.16];
    button.layer.cornerRadius = 10;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = [DYYYUtils isDarkMode] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.22];
    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        glass.interactive = NO;
        effect = glass;
    }
#endif
    self.panel = [[UIVisualEffectView alloc] initWithEffect:effect];
    self.panel.layer.cornerRadius = 26;
    self.panel.layer.cornerCurve = kCACornerCurveContinuous;
    self.panel.layer.borderWidth = 0.5;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    self.panel.clipsToBounds = YES;
    [self.view addSubview:self.panel];
    UIView *content = self.panel.contentView;
    self.titleLabel = [UILabel new];
    self.titleLabel.text = @"不发送时间段设置";
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:self.titleLabel];
    self.noteLabel = [UILabel new];
    self.noteLabel.text = @"在这些时间段内，即使今天还没有自动发送过消息，也不会发送自动消息";
    self.noteLabel.numberOfLines = 0;
    self.noteLabel.textAlignment = NSTextAlignmentCenter;
    self.noteLabel.font = [UIFont systemFontOfSize:13];
    self.noteLabel.textColor = UIColor.secondaryLabelColor;
    [content addSubview:self.noteLabel];
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.backgroundColor = UIColor.clearColor;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 54;
    self.table.separatorColor = [UIColor colorWithWhite:1 alpha:0.18];
    self.table.tableFooterView = [UIView new];
    [content addSubview:self.table];
    self.emptyLabel = [UILabel new];
    self.emptyLabel.text = @"暂无时间段\n点击下方按钮添加";
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = UIColor.secondaryLabelColor;
    self.table.backgroundView = self.emptyLabel;
    self.footer = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self button:@"添加时间段" color:UIColor.systemBlueColor action:@selector(addPeriod)],
        [self button:@"关闭" color:UIColor.labelColor action:@selector(closePanel)]]];
    self.footer.axis = UILayoutConstraintAxisHorizontal;
    self.footer.spacing = 40;
    self.footer.distribution = UIStackViewDistributionFillEqually;
    [content addSubview:self.footer];
    [self reloadRows];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillHideNotification object:nil];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat width = MIN(320, MAX(0, CGRectGetWidth(safe) - 40));
    CGFloat height = MIN(500, MAX(0, CGRectGetHeight(safe) - 32));
    self.panel.frame = CGRectMake(CGRectGetMidX(safe) - width / 2, CGRectGetMidY(safe) - height / 2, width, height);
    self.titleLabel.frame = CGRectMake(14, 16, width - 28, 28);
    self.noteLabel.frame = CGRectMake(18, 48, width - 36, 44);
    self.footer.frame = CGRectMake(20, height - 64, width - 40, 44);
    self.table.frame = CGRectMake(0, 100, width, MAX(0, CGRectGetMinY(self.footer.frame) - 112));
    if (!self.editorShade) return;
    self.editorShade.frame = self.view.bounds;
    CGRect available = safe;
    if (self.view.window && !CGRectIsEmpty(self.keyboardFrame)) {
        CGRect keyboard = [self.view convertRect:self.keyboardFrame fromCoordinateSpace:self.view.window.screen.coordinateSpace];
        CGRect overlap = CGRectIntersection(safe, keyboard);
        if (!CGRectIsNull(overlap) && CGRectGetWidth(overlap) > CGRectGetWidth(safe) * 0.5)
            available.size.height = MAX(0, CGRectGetMinY(overlap) - CGRectGetMinY(safe));
    }
    CGFloat editorWidth = MIN(300, MAX(0, CGRectGetWidth(available) - 24));
    CGFloat editorHeight = MIN(300, MAX(120, CGRectGetHeight(available) - 16));
    self.editor.frame = CGRectMake(CGRectGetMidX(available) - editorWidth / 2, CGRectGetMinY(available) + MAX(8, (CGRectGetHeight(available) - editorHeight) / 2), editorWidth, editorHeight);
    self.editorTitle.frame = CGRectMake(16, 16, editorWidth - 32, 26);
    self.editorBody.frame = CGRectMake(20, 50, editorWidth - 40, MAX(0, editorHeight - 108));
    CGFloat bodyWidth = CGRectGetWidth(self.editorBody.bounds);
    self.editorNote.frame = CGRectMake(0, 0, bodyWidth, 32);
    self.startField.frame = CGRectMake(0, 44, bodyWidth, 40);
    self.endField.frame = CGRectMake(0, 94, bodyWidth, 40);
    self.editorBody.contentSize = CGSizeMake(bodyWidth, 146);
    self.editorButtons.frame = CGRectMake(0, editorHeight - 52, editorWidth, 52);
}
- (void)keyboardChanged:(NSNotification *)note {
    if (!self.editorShade || !self.view.window) return;
    self.keyboardFrame = [note.name isEqualToString:UIKeyboardWillHideNotification] ? CGRectZero : [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = ([note.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16) | UIViewAnimationOptionBeginFromCurrentState;
    [self.view setNeedsLayout];
    [UIView animateWithDuration:duration delay:0 options:options animations:^{ [self.view layoutIfNeeded]; } completion:nil];
}
- (void)reloadRows {
    self.emptyLabel.hidden = self.periods.count > 0;
    [self.table reloadData];
}
- (void)persist {
    [DYYYAutoMessage saveNoSendTimePeriods:self.periods];
    [self reloadRows];
    if (self.onChange) self.onChange();
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.periods.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"QuietHours"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"QuietHours"];
    NSDictionary *period = self.periods[indexPath.row];
    BOOL enabled = [period[@"enabled"] boolValue];
    cell.textLabel.text = [NSString stringWithFormat:@"%02ld:00 - %02ld:00", (long)[period[@"startHour"] integerValue], (long)[period[@"endHour"] integerValue]];
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.backgroundColor = enabled ? [UIColor.systemGreenColor colorWithAlphaComponent:0.12] : UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *toggle = [UISwitch new];
    toggle.on = enabled;
    toggle.onTintColor = UIColor.systemGreenColor;
    toggle.tag = indexPath.row;
    toggle.accessibilityLabel = [cell.textLabel.text stringByAppendingString:@"不发送"];
    [toggle addTarget:self action:@selector(togglePeriod:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)togglePeriod:(UISwitch *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.periods.count) return;
    self.periods[sender.tag][@"enabled"] = @(sender.on);
    [self persist];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { [self editPeriodAtIndex:indexPath.row]; }
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath { return @"删除"; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.row < self.periods.count) {
        [self.periods removeObjectAtIndex:indexPath.row]; [self persist];
    }
}
- (UITextField *)hourField:(NSString *)placeholder {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.font = [UIFont systemFontOfSize:16];
    field.textColor = UIColor.labelColor;
    field.backgroundColor = UIColor.secondarySystemFillColor;
    field.layer.cornerRadius = 9;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.keyboardAppearance = self.overrideUserInterfaceStyle == UIUserInterfaceStyleDark ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    field.delegate = self;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    return field;
}
- (void)addPeriod { [self editPeriodAtIndex:NSNotFound]; }
- (void)editPeriodAtIndex:(NSUInteger)index {
    if (self.editorShade || (index != NSNotFound && index >= self.periods.count)) return;
    self.editingIndex = index;
    self.keyboardFrame = CGRectZero;
    self.editorShade = [[UIView alloc] initWithFrame:self.view.bounds];
    self.editorShade.backgroundColor = [UIColor colorWithWhite:0 alpha:0.22];
    self.editorShade.accessibilityViewIsModal = YES;
    [self.view addSubview:self.editorShade];
    self.editor = [UIView new];
    self.editor.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.editor.layer.cornerRadius = 13;
    self.editor.clipsToBounds = YES;
    [self.editorShade addSubview:self.editor];
    self.editorTitle = [UILabel new];
    self.editorTitle.text = index == NSNotFound ? @"添加时间段" : @"编辑时间段";
    self.editorTitle.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.editorTitle.textColor = UIColor.labelColor;
    self.editorTitle.textAlignment = NSTextAlignmentCenter;
    [self.editor addSubview:self.editorTitle];
    self.editorBody = [UIScrollView new];
    [self.editor addSubview:self.editorBody];
    self.editorNote = [UILabel new];
    self.editorNote.text = @"输入时间段（24小时制）";
    self.editorNote.font = [UIFont systemFontOfSize:13];
    self.editorNote.textColor = UIColor.secondaryLabelColor;
    self.editorNote.textAlignment = NSTextAlignmentCenter;
    self.editorNote.numberOfLines = 0;
    [self.editorBody addSubview:self.editorNote];
    self.startField = [self hourField:@"开始小时（0–23）"];
    self.endField = [self hourField:@"结束小时（0–23）"];
    [self.editorBody addSubview:self.startField]; [self.editorBody addSubview:self.endField];
    if (index != NSNotFound) {
        self.startField.text = [NSString stringWithFormat:@"%02ld", (long)[self.periods[index][@"startHour"] integerValue]];
        self.endField.text = [NSString stringWithFormat:@"%02ld", (long)[self.periods[index][@"endHour"] integerValue]];
    }
    UIButton *cancel = [self button:@"取消" color:UIColor.secondaryLabelColor action:@selector(cancelEditor)];
    UIButton *save = [self button:@"确定" color:UIColor.labelColor action:@selector(saveEditor)];
    cancel.layer.cornerRadius = 0; save.layer.cornerRadius = 0;
    self.editorButtons = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, save]];
    self.editorButtons.axis = UILayoutConstraintAxisHorizontal;
    self.editorButtons.distribution = UIStackViewDistributionFillEqually;
    self.editorButtons.spacing = 0.5;
    [self.editor addSubview:self.editorButtons];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    [self.startField becomeFirstResponder];
}
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *current = textField.text ?: @"";
    if (NSMaxRange(range) > current.length) return NO;
    NSString *next = [current stringByReplacingCharactersInRange:range withString:string];
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    return next.length <= 2 && [next rangeOfCharacterFromSet:invalid].location == NSNotFound;
}
- (void)textFieldDidBeginEditing:(UITextField *)textField { [self.editorBody scrollRectToVisible:CGRectInset(textField.frame, 0, -8) animated:YES]; }
- (void)saveEditor {
    NSString *startText = self.startField.text ?: @"", *endText = self.endField.text ?: @"";
    NSInteger start = startText.integerValue, end = endText.integerValue;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    if (!startText.length || !endText.length || startText.length > 2 || endText.length > 2 ||
        [startText rangeOfCharacterFromSet:invalid].location != NSNotFound || [endText rangeOfCharacterFromSet:invalid].location != NSNotFound ||
        start < 0 || start > 23 || end < 0 || end > 23) {
        [DYYYUtils showToast:@"请输入 0–23 之间的开始小时和结束小时"]; return;
    }
    if (start == end) { [DYYYUtils showToast:@"开始小时和结束小时不能相同"]; return; }
    if (self.editingIndex != NSNotFound && self.editingIndex >= self.periods.count) return;
    NSMutableDictionary *period = self.editingIndex == NSNotFound ? [@{ @"id": NSUUID.UUID.UUIDString, @"enabled": @YES } mutableCopy] : self.periods[self.editingIndex];
    period[@"startHour"] = @(start); period[@"endHour"] = @(end);
    if (self.editingIndex == NSNotFound) [self.periods addObject:period];
    [self cancelEditor]; [self persist];
}
- (void)cancelEditor {
    UIView *shade = self.editorShade;
    self.editorShade = nil;
    [shade endEditing:YES]; [shade removeFromSuperview];
    self.editor = nil; self.editorBody = nil; self.editorTitle = nil; self.editorNote = nil;
    self.startField = nil; self.endField = nil; self.editorButtons = nil;
    self.keyboardFrame = CGRectZero;
}
- (void)closePanel { [self.view endEditing:YES]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
