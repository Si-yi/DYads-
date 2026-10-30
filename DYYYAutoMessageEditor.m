#import "DYYYAutoMessageEditor.h"
#import "DYYYAutoMessage.h"
#import "DYYYIMService.h"
#import "DYYYUtils.h"
#import <PhotosUI/PhotosUI.h>

@interface DYYYAutoMessageEditor () <PHPickerViewControllerDelegate, UITextViewDelegate>
@property (nonatomic, copy) NSDictionary *original;
@property (nonatomic, copy) void (^completion)(void);
@property (nonatomic, strong) NSMutableDictionary *draft;
@property (nonatomic, strong) UIVisualEffectView *panel;
@property (nonatomic, strong) UIStackView *body;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UITextField *recipient;
@property (nonatomic, strong) UITextField *displayName;
@property (nonatomic, strong) UITextView *message;
@property (nonatomic, strong) UISegmentedControl *sendMode;
@property (nonatomic, strong) UISegmentedControl *textMode;
@property (nonatomic, strong) UILabel *imageStatus;
@property (nonatomic, strong) UIImageView *imagePreview;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *testButton;
@property (nonatomic, strong) NSMutableArray<NSString *> *images;
@property (nonatomic, strong) NSMutableSet<NSString *> *createdFiles;
@property (nonatomic, copy) NSArray<NSString *> *tokens;
@property (nonatomic, strong) NSLayoutConstraint *bottom;
@property (nonatomic) BOOL busy;
@property (nonatomic) BOOL saved;
@property (nonatomic) BOOL helpOnly;
@property (nonatomic, copy) NSString *owner;
@property (nonatomic, copy) NSSet<NSString *> *batchUserIDs;
@end

@implementation DYYYAutoMessageEditor

+ (void)showFrom:(UIViewController *)presenter config:(NSDictionary *)config completion:(void (^)(void))completion {
    DYYYAutoMessageEditor *editor = [self new];
    editor.original = config;
    editor.completion = completion;
    [self present:editor from:presenter];
}
+ (void)showBatchFrom:(UIViewController *)presenter userIDs:(NSArray<NSString *> *)userIDs ownerID:(NSString *)ownerID completion:(void (^)(void))completion {
    if (!userIDs.count || !ownerID.length || ![ownerID isEqual:[DYYYIMService accountID]]) {
        [DYYYUtils showToast:@"登录账户已变化，请重新选择好友"]; return;
    }
    DYYYAutoMessageEditor *editor = [self new];
    editor.batchUserIDs = [NSSet setWithArray:userIDs];
    editor.owner = ownerID;
    editor.completion = completion;
    // 内容完全一致时预填；不同内容从空白开始，避免把某一好友的文字悄悄套给其他人。
    NSString *commonText = nil;
    BOOL commonRandom = NO, found = NO, same = YES;
    for (NSDictionary *row in [DYYYAutoMessage messageConfigs]) {
        if (![row[@"ownerID"] isEqual:ownerID] || ![editor.batchUserIDs containsObject:row[@"userID"]]) continue;
        if (!found) { commonText = row[@"message"]; commonRandom = [row[@"randomText"] boolValue]; found = YES; }
        else if (![row[@"message"] isEqual:commonText] || [row[@"randomText"] boolValue] != commonRandom) same = NO;
    }
    editor.draft = [@{ @"message": same ? (commonText ?: @"") : @"", @"randomText": @(same && commonRandom) } mutableCopy];
    [self present:editor from:presenter];
}
+ (void)showHelpFrom:(UIViewController *)presenter {
    DYYYAutoMessageEditor *editor = [self new];
    editor.helpOnly = YES;
    [self present:editor from:presenter];
}
+ (void)present:(UIViewController *)editor from:(UIViewController *)presenter {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self present:editor from:presenter]; });
        return;
    }
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) presenter = presenter.presentedViewController;
    editor.modalPresentationStyle = UIModalPresentationOverFullScreen;
    editor.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:editor animated:YES completion:nil];
}
- (UILabel *)label:(NSString *)text secondary:(BOOL)secondary {
    UILabel *label = [UILabel new];
    label.numberOfLines = 0;
    label.text = text;
    label.font = [UIFont systemFontOfSize:secondary ? 13 : 16];
    label.textColor = secondary ? UIColor.secondaryLabelColor : UIColor.labelColor;
    return label;
}
- (UIButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.backgroundColor = [color colorWithAlphaComponent:0.14];
    button.layer.cornerRadius = 10;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:40].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (UIStackView *)row:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 8;
    return row;
}
- (UITextField *)field:(NSString *)placeholder value:(NSString *)value {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.text = value;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.font = [UIFont systemFontOfSize:16];
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    [field.heightAnchor constraintEqualToConstant:44].active = YES;
    return field;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = [DYYYUtils isDarkMode] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    self.owner = self.owner ?: [DYYYIMService accountID];
    self.draft = self.draft ?: [self.original mutableCopy] ?: [@{@"enabled":@YES, @"message":@"[点火]", @"sendMode":@0, @"randomText":@NO} mutableCopy];
    self.images = [self.draft[@"imagePaths"] mutableCopy] ?: [NSMutableArray array];
    self.createdFiles = [NSMutableSet set];
    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        glass.interactive = NO;
        effect = glass;
    }
#endif
    self.panel = [[UIVisualEffectView alloc] initWithEffect:effect];
    self.panel.translatesAutoresizingMaskIntoConstraints = NO;
    self.panel.layer.cornerRadius = 26;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    self.panel.layer.borderWidth = 0.5;
    self.panel.clipsToBounds = YES;
    [self.view addSubview:self.panel];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.bottom = [self.panel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12];
    NSLayoutConstraint *width = [self.panel.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.9];
    width.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.panel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18], self.bottom,
        [self.panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.panel.widthAnchor constraintLessThanOrEqualToConstant:440],
        width
    ]];
    UILabel *title = [self label:self.helpOnly ? @"使用说明" : (self.batchUserIDs ? @"批量修改文字内容" : (self.original ? @"好友发送配置" : @"添加自动消息配置")) secondary:NO];
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
    UIButton *close = [self button:@"关闭" color:UIColor.secondaryLabelColor action:@selector(close)];
    UIStackView *header = [self row:@[title, close]];
    header.distribution = UIStackViewDistributionFill;
    [close.widthAnchor constraintEqualToConstant:56].active = YES;
    self.scroll = [UIScrollView new];
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.body = [UIStackView new];
    self.body.axis = UILayoutConstraintAxisVertical;
    self.body.spacing = 12;
    self.body.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.body];
    [NSLayoutConstraint activateConstraints:@[
        [self.body.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor],
        [self.body.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-12],
        [self.body.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor],
        [self.body.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor],
        [self.body.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor]
    ]];
    UIStackView *container = [[UIStackView alloc] initWithArrangedSubviews:@[header, self.scroll]];
    container.axis = UILayoutConstraintAxisVertical;
    container.spacing = 14;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel.contentView addSubview:container];
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.panel.contentView.topAnchor constant:16],
        [container.bottomAnchor constraintEqualToAnchor:self.panel.contentView.bottomAnchor constant:-16],
        [container.leadingAnchor constraintEqualToAnchor:self.panel.contentView.leadingAnchor constant:16],
        [container.trailingAnchor constraintEqualToAnchor:self.panel.contentView.trailingAnchor constant:-16]
    ]];
    if (self.helpOnly) { [self buildHelp]; return; }
    if (self.batchUserIDs) {
        [self.body addArrangedSubview:[self label:[NSString stringWithFormat:@"已选 %lu 位好友。统一修改文字及固定/每日随机方式，其余配置保留。", (unsigned long)self.batchUserIDs.count] secondary:YES]];
    } else {
        if (!self.original) [self.body addArrangedSubview:[self label:@"支持用户 ID、抖音号、昵称、备注名及当前账户的一对一会话 ID。重名时请使用用户 ID。" secondary:YES]];
        [self.body addArrangedSubview:[self label:@"用户 ID / 会话 ID" secondary:YES]];
        self.recipient = [self field:@"用户 ID / 抖音号 / 昵称 / 备注名" value:self.draft[@"userID"]];
        self.recipient.enabled = self.original == nil;
        [self.body addArrangedSubview:self.recipient];
        [self.body addArrangedSubview:[self label:@"显示名称" secondary:YES]];
        self.displayName = [self field:@"用户名（显示用）" value:self.draft[@"name"]];
        [self.body addArrangedSubview:self.displayName];
        self.sendMode = [[UISegmentedControl alloc] initWithItems:@[@"仅文字", @"文字＋图", @"仅图片"]];
        self.sendMode.selectedSegmentIndex = MIN(2, MAX(0, [self.draft[@"sendMode"] integerValue]));
        [self.sendMode addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
        [self.body addArrangedSubview:self.sendMode];
    }
    [self.body addArrangedSubview:[self label:@"文字内容" secondary:YES]];
    self.textMode = [[UISegmentedControl alloc] initWithItems:@[@"固定", @"每日随机"]];
    self.textMode.selectedSegmentIndex = [self.draft[@"randomText"] boolValue] ? 1 : 0;
    [self.body addArrangedSubview:self.textMode];
    self.message = [UITextView new];
    self.message.font = [UIFont systemFontOfSize:16];
    self.message.text = self.draft[@"message"] ?: @"";
    self.message.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.5];
    self.message.layer.cornerRadius = 12;
    self.message.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);
    self.message.delegate = self;
    [self.message.heightAnchor constraintEqualToConstant:160].active = YES;
    [self.body addArrangedSubview:self.message];
    [self.body addArrangedSubview:[self label:@"快速插入参数" secondary:YES]];
    NSArray *labels = @[@"序号{n}", @"天数{d}", @"备注", @"日期", @"星期", @"年", @"月", @"日", @"时", @"分", @"秒", @"换行"];
    self.tokens = @[@"{n}", @"{d}", @"{remark}", @"{date}", @"{weekday}", @"{year}", @"{month}", @"{day}", @"{hour}", @"{minute}", @"{second}", @"\n"];
    for (NSUInteger start = 0; start < labels.count; start += 4) {
        NSMutableArray *buttons = [NSMutableArray array];
        for (NSUInteger i = start; i < MIN(start + 4, labels.count); i++) {
            UIButton *button = [self button:labels[i] color:UIColor.systemBlueColor action:@selector(insertToken:)];
            button.tag = i;
            [buttons addObject:button];
        }
        [self.body addArrangedSubview:[self row:buttons]];
    }
    [self.body addArrangedSubview:[self label:@"每日随机：每行一条；多行内容可用 1.、2.、3. 开头分组。同一天固定选择同一条。\n{n} 为本配置成功发送序号，{d} 为创建后的日历天数。自定义日期可写 {datetime:yyyy年MM月dd日}。" secondary:YES]];
    if (!self.batchUserIDs) {
        [self.body addArrangedSubview:[self label:@"图片" secondary:YES]];
        self.imageStatus = [self label:@"" secondary:YES];
        [self.body addArrangedSubview:self.imageStatus];
        self.imagePreview = [UIImageView new];
        self.imagePreview.contentMode = UIViewContentModeScaleAspectFit;
        self.imagePreview.clipsToBounds = YES;
        NSLayoutConstraint *previewHeight = [self.imagePreview.heightAnchor constraintEqualToConstant:100];
        previewHeight.priority = UILayoutPriorityDefaultHigh;
        previewHeight.active = YES;
        [self.body addArrangedSubview:self.imagePreview];
        [self.body addArrangedSubview:[self row:@[
            [self button:@"选择图片" color:UIColor.systemBlueColor action:@selector(pickImages)],
            [self button:@"清除图片" color:UIColor.systemRedColor action:@selector(clearImages)]
        ]]];
        [self.body addArrangedSubview:[self label:@"图片可选择、预览及保存。当前尚未接通抖音原生图片上传接口，含图模式会停止发送并提示，不会只发文字或显示成功。" secondary:YES]];
    }
    NSString *saveTitle = self.batchUserIDs ? [NSString stringWithFormat:@"保存到 %lu 位好友", (unsigned long)self.batchUserIDs.count] : (self.original ? @"保存" : @"添加");
    self.saveButton = [self button:saveTitle color:UIColor.systemGreenColor action:@selector(save)];
    if (self.batchUserIDs) [container addArrangedSubview:self.saveButton];
    else {
        self.testButton = [self button:@"测试发送" color:UIColor.systemOrangeColor action:@selector(testSend)];
        [container addArrangedSubview:[self row:@[self.testButton, self.saveButton]]];
    }
    [self modeChanged];
    [self updateImages];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)buildHelp {
    [self.body addArrangedSubview:[self label:@"功能逻辑\n首次打开或返回抖音时检查已启用配置，每位好友每天最多一次。已有本插件发送或待确认记录，或本机已观察到当天原生发送回执时不重复发送。不会主动读取聊天历史；其他设备或停用期间发出的消息无法据此判断。\n\n添加配置\n填写用户 ID 或从互关好友中选择。支持按抖音号、昵称及备注匹配本地好友；重名时请使用 ID。完整或简化的一对一会话 ID 必须包含当前账户。群聊尚未适配。\n\n配置管理\n点击好友编辑，左滑删除；开关控制是否参与自动发送。批量修改内容可选择部分或全部已添加好友，统一替换固定/每日随机文字，保存后用于后续发送；备注、启用状态、图片和已有发送记录保留。测试按钮会实际请求发送，可随时重复测试，不受每日次数、启用开关及免打扰时段限制，也不写入自动发送的每日记录。\n\n文字\n支持固定内容、每日随机及日期等变量。随机内容每天保持一致。{n} 为成功发送序号，{d} 为配置创建后的日历天数。\n\n图片\n支持本地选择、预览和保存；原生图片上传发送尚未接通，含图模式不会发送。\n\n账户\n配置绑定保存时的登录账户，切换账户不会发送给另一账户的联系人。" secondary:NO]];
}
- (void)modeChanged {
    BOOL imageOnly = self.sendMode.selectedSegmentIndex == 2;
    self.message.editable = !imageOnly;
    self.message.alpha = imageOnly ? 0.45 : 1;
    self.textMode.enabled = !imageOnly;
}
- (void)insertToken:(UIButton *)button {
    if (!self.message.editable) return;
    NSRange range = self.message.selectedRange;
    if (range.location == NSNotFound || NSMaxRange(range) > self.message.text.length) range = NSMakeRange(self.message.text.length, 0);
    NSString *token = self.tokens[button.tag];
    self.message.text = [self.message.text stringByReplacingCharactersInRange:range withString:token];
    self.message.selectedRange = NSMakeRange(range.location + token.length, 0);
    [self.message becomeFirstResponder];
}
- (void)keyboardChanged:(NSNotification *)note {
    CGRect screenFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = [self.view convertRect:screenFrame fromView:nil];
    CGFloat overlap = MAX(0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(frame) - self.view.safeAreaInsets.bottom);
    self.bottom.constant = -MAX(12, overlap + 8);
    [UIView animateWithDuration:[note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] animations:^{ [self.view layoutIfNeeded]; }];
}
- (void)textViewDidBeginEditing:(UITextView *)textView {
    dispatch_async(dispatch_get_main_queue(), ^{ [self.scroll scrollRectToVisible:[textView convertRect:textView.bounds toView:self.body] animated:YES]; });
}
- (void)pickImages {
    [self.view endEditing:YES];
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.filter = PHPickerFilter.imagesFilter;
    configuration.selectionLimit = 4;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!results.count) return;
    [self setBusy:YES];
    NSMutableArray *paths = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    NSString *folder = [DYYYAutoMessage imageDirectory];
    if (![NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil]) {
        [self setBusy:NO];
        [DYYYUtils showToast:@"无法创建图片保存目录"]; return;
    }
    __weak typeof(self) weakSelf = self;
    for (PHPickerResult *result in results) {
        if (![result.itemProvider canLoadObjectOfClass:UIImage.class]) continue;
        dispatch_group_enter(group);
        [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            @autoreleasepool {
                UIImage *image = [object isKindOfClass:UIImage.class] ? (UIImage *)object : nil;
                if (image && image.size.width > 0 && image.size.height > 0) {
                    CGFloat scale = MIN(1, 1600 / MAX(image.size.width, image.size.height));
                    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
                    format.scale = 1;
                    CGSize size = CGSizeMake(image.size.width * scale, image.size.height * scale);
                    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
                    UIImage *resized = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [image drawInRect:(CGRect){CGPointZero, size}]; }];
                    NSData *data = UIImageJPEGRepresentation(resized, 0.8);
                    NSString *path = [folder stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".jpg"]];
                    if (data && [data writeToFile:path atomically:YES]) { @synchronized (paths) { [paths addObject:path]; } }
                }
                dispatch_group_leave(group);
            }
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        DYYYAutoMessageEditor *editor = weakSelf;
        if (!editor) { for (NSString *path in paths) [NSFileManager.defaultManager removeItemAtPath:path error:nil]; return; }
        [editor.createdFiles addObjectsFromArray:paths];
        [editor setBusy:NO];
        if (!paths.count) { [DYYYUtils showToast:@"未能读取所选图片，请重试"]; return; }
        editor.images = [paths mutableCopy];
        [editor updateImages];
    });
}
- (void)clearImages { [self.images removeAllObjects]; [self updateImages]; }
- (void)updateImages {
    self.imageStatus.text = self.images.count ? [NSString stringWithFormat:@"已选择 %lu 张图片（预览第一张）", (unsigned long)self.images.count] : @"尚未选择图片";
    self.imagePreview.image = self.images.count ? [UIImage imageWithContentsOfFile:self.images.firstObject] : nil;
    self.imagePreview.hidden = self.images.count == 0;
}
- (void)setBusy:(BOOL)busy {
    _busy = busy;
    self.saveButton.enabled = !busy;
    self.testButton.enabled = !busy;
    self.view.userInteractionEnabled = !busy;
}
- (void)resolveDraft:(void (^)(NSMutableDictionary *))completion {
    [self.view endEditing:YES];
    if (self.busy) return;
    if (!self.owner.length || ![self.owner isEqual:[DYYYIMService accountID]]) { [DYYYUtils showToast:@"登录账户已变化，请关闭并重新打开配置"]; return; }
    if (self.original && ![self.original[@"ownerID"] isEqual:self.owner] && [self.original[@"ownerID"] length]) { [DYYYUtils showToast:@"此配置属于另一账户，不能在当前账户修改或发送"]; return; }
    NSString *input = [self.recipient.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!input.length) { [DYYYUtils showToast:@"请填写用户 ID 或选择好友"]; return; }
    if (self.sendMode.selectedSegmentIndex != 2 && ![self.message.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) { [DYYYUtils showToast:@"请填写消息内容"]; return; }
    if (self.sendMode.selectedSegmentIndex != 0 && !self.images.count) { [DYYYUtils showToast:@"请先选择图片"]; return; }
    [self setBusy:YES];
    __weak typeof(self) weakSelf = self;
    [DYYYAutoMessage resolveRecipient:input completion:^(NSDictionary *friend, NSString *error) {
        DYYYAutoMessageEditor *editor = weakSelf;
        if (!editor) return;
        [editor setBusy:NO];
        if (!friend) { [DYYYUtils showToast:error ?: @"未找到用户"]; return; }
        if (![editor.owner isEqual:[DYYYIMService accountID]]) { [DYYYUtils showToast:@"登录账户已变化，请重新打开配置"]; return; }
        NSMutableDictionary *config = [editor.draft mutableCopy];
        config[@"userID"] = friend[@"userID"];
        config[@"ownerID"] = editor.owner;
        NSString *name = [editor.displayName.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        config[@"name"] = name.length ? name : (friend[@"name"] ?: friend[@"userID"]);
        config[@"message"] = editor.message.text ?: @"";
        config[@"randomText"] = @(editor.textMode.selectedSegmentIndex == 1);
        config[@"sendMode"] = @(editor.sendMode.selectedSegmentIndex);
        config[@"imagePaths"] = [editor.images copy];
        config[@"createdAt"] = config[@"createdAt"] ?: @(NSDate.date.timeIntervalSince1970);
        completion(config);
    }];
}
- (void)save {
    if (self.batchUserIDs) {
        [self.view endEditing:YES];
        if (self.busy) return;
        if (![self.message.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) { [DYYYUtils showToast:@"请填写消息内容"]; return; }
        [self setBusy:YES];
        NSUInteger count = [DYYYAutoMessage updateText:self.message.text randomText:(self.textMode.selectedSegmentIndex == 1) userIDs:self.batchUserIDs ownerID:self.owner];
        if (count == NSNotFound) { [self setBusy:NO]; [DYYYUtils showToast:@"登录账户已变化，请重新选择好友"]; return; }
        if (!count) { [self setBusy:NO]; [DYYYUtils showToast:@"所选好友的配置已移除，请重新选择"]; return; }
        self.saved = YES;
        void (^completion)(void) = self.completion;
        [self dismissViewControllerAnimated:YES completion:^{
            if (completion) completion();
            [DYYYUtils showToast:[NSString stringWithFormat:@"已更新 %lu 位好友的文字内容", (unsigned long)count]];
        }];
        return;
    }
    [self resolveDraft:^(NSMutableDictionary *config) {
        NSMutableArray *configs = [DYYYAutoMessage messageConfigs];
        NSUInteger index = [configs indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
            BOOL sameOwner = [row[@"ownerID"] isEqual:config[@"ownerID"]];
            BOOL legacy = self.original && ![self.original[@"ownerID"] length] && ![row[@"ownerID"] length];
            return [row[@"userID"] isEqual:config[@"userID"]] && (sameOwner || legacy);
        }];
        if (index != NSNotFound && !self.original) { [DYYYUtils showToast:@"该好友已有配置，请返回列表点击编辑"]; return; }
        if (index != NSNotFound) configs[index] = config; else [configs addObject:config];
        [DYYYAutoMessage saveMessageConfigs:configs];
        self.saved = YES;
        self.draft = config;
        void (^completion)(void) = self.completion;
        [self dismissViewControllerAnimated:YES completion:completion];
    }];
}
- (void)testSend {
    if (self.batchUserIDs) return;
    [self resolveDraft:^(NSMutableDictionary *config) {
        [self setBusy:YES];
        [DYYYUtils showToast:@"正在请求发送，等待抖音回执"];
        [DYYYAutoMessage sendConfig:config manualTest:YES completion:^(BOOL success, NSString *reason) {
            [self setBusy:NO];
            [DYYYUtils showToast:reason];
        }];
    }];
}
- (void)close {
    if (self.busy) return;
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    // 取消或换图后删除本次生成但未保存的文件；不删除其他配置的图片。
    NSSet *kept = self.saved ? [NSSet setWithArray:self.draft[@"imagePaths"] ?: @[]] : [NSSet set];
    for (NSString *path in self.createdFiles) if (![kept containsObject:path]) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}
@end
