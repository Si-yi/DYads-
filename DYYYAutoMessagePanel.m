#import "DYYYAutoMessagePanel.h"
#import "DYYYAutoMessage.h"
#import "DYYYAutoMessageEditor.h"
#import "DYYYIMService.h"
#import "DYYYSettingsHelper.h"
#import "DYYYUtils.h"

@interface DYYYAutoMessagePanel () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic) BOOL pickingFriends;
@property(nonatomic) BOOL pickingTest;
@property(nonatomic) BOOL loadingFriends;
@property(nonatomic, strong) UIVisualEffectView *panel;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *helpButton;
@property(nonatomic, strong) UITableView *table;
@property(nonatomic, strong) UISearchBar *search;
@property(nonatomic, strong) UIStackView *footer;
@property(nonatomic, strong) UIStackView *selectionBar;
@property(nonatomic, strong) UIButton *saveButton;
@property(nonatomic, strong) UILabel *emptyLabel;
@property(nonatomic, strong) NSMutableArray<NSMutableDictionary *> *configs;
@property(nonatomic, strong) NSArray<NSDictionary *> *friends;
@property(nonatomic, strong) NSArray<NSArray<NSDictionary *> *> *groups;
@property(nonatomic, strong) NSMutableSet<NSString *> *selectedIDs;
@property(nonatomic, copy) void (^selectionCompletion)(NSArray<NSDictionary *> *friends);
@property(nonatomic, strong) NSCache<NSString *, UIImage *> *avatarCache;
@property(nonatomic, strong) NSMutableArray<NSURLSessionDataTask *> *avatarTasks;
@end

@implementation DYYYAutoMessagePanel

+ (void)showConfigsFrom:(UIViewController *)presenter {
    DYYYAutoMessagePanel *vc = [self new];
    vc.configs = [DYYYAutoMessage messageConfigs];
    [self presentPanel:vc from:presenter];
}

+ (void)showFriendsFrom:(UIViewController *)presenter selectedIDs:(NSArray<NSString *> *)ids
             completion:(void (^)(NSArray<NSDictionary *> *friends))completion {
    DYYYAutoMessagePanel *vc = [self new];
    vc.pickingFriends = YES;
    vc.loadingFriends = YES;
    vc.selectedIDs = [NSMutableSet setWithArray:ids ?: @[]];
    vc.selectionCompletion = completion;
    [self presentPanel:vc from:presenter];
    __weak DYYYAutoMessagePanel *weakVC = vc;
    [DYYYAutoMessage loadMutualFriends:^(NSArray<NSDictionary *> *friends) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DYYYAutoMessagePanel *strongVC = weakVC;
            if (!strongVC) return;
            strongVC.friends = friends;
            strongVC.loadingFriends = NO;
            [strongVC filterFriends];
        });
    }];
}

+ (void)presentPanel:(DYYYAutoMessagePanel *)panel from:(UIViewController *)presenter {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self presentPanel:panel from:presenter]; });
        return;
    }
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed)
        presenter = presenter.presentedViewController;
    panel.modalPresentationStyle = UIModalPresentationOverFullScreen;
    panel.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:panel animated:YES completion:nil];
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

- (UIStackView *)row:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.distribution = UIStackViewDistributionFillEqually;
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    BOOL dark = [DYYYUtils isDarkMode];
    self.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.22];
    self.avatarCache = [NSCache new];
    self.avatarCache.countLimit = 160;
    self.avatarTasks = [NSMutableArray array];
    self.friends = self.friends ?: @[];
    self.groups = @[@[], @[]];
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
    self.panel.clipsToBounds = YES;
    self.panel.layer.borderWidth = 0.5;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    [self.view addSubview:self.panel];
    UIView *content = self.panel.contentView;
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = UIColor.labelColor;
    [content addSubview:self.titleLabel];
    self.helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.helpButton setImage:[UIImage systemImageNamed:self.pickingFriends ? @"arrow.clockwise" : @"questionmark.circle"] forState:UIControlStateNormal];
    self.helpButton.tintColor = UIColor.labelColor;
    self.helpButton.accessibilityLabel = self.pickingFriends ? @"重新读取好友" : @"配置说明";
    [self.helpButton addTarget:self action:@selector(showHelp) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.helpButton];
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.backgroundColor = UIColor.clearColor;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.separatorColor = [UIColor colorWithWhite:1 alpha:0.18];
    self.table.tableFooterView = [UIView new];
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [content addSubview:self.table];
    self.emptyLabel = [UILabel new];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = UIColor.secondaryLabelColor;
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.table.backgroundView = self.emptyLabel;
    UIButton *close = [self button:self.pickingFriends ? @"取消" : @"关闭" color:UIColor.labelColor action:@selector(closePanel)];
    if (self.pickingFriends) {
        self.search = [UISearchBar new];
        self.search.placeholder = @"搜索好友备注、昵称或 ID";
        self.search.searchBarStyle = UISearchBarStyleMinimal;
        self.search.delegate = self;
        [content addSubview:self.search];
        self.selectionBar = [self row:@[
            [self button:@"全选" color:UIColor.labelColor action:@selector(selectAll)],
            [self button:@"全不选" color:UIColor.labelColor action:@selector(selectNone)]]];
        [content addSubview:self.selectionBar];
        self.saveButton = [self button:@"保存选中" color:UIColor.systemBlueColor action:@selector(saveSelection)];
        self.footer = [self row:@[self.saveButton, close]];
        [self filterFriends];
    } else if (self.pickingTest) {
        self.footer = [self row:@[close]];
        [self updateTitle];
    } else {
        UIStackView *top = [self row:@[
            [self button:@"添加配置" color:UIColor.systemBlueColor action:@selector(addConfig)],
            [self button:@"测试发送" color:UIColor.systemOrangeColor action:@selector(testConfig)]]];
        UIStackView *bottom = [self row:@[
            [self button:@"选择互关好友" color:UIColor.systemPinkColor action:@selector(addFriends)], close]];
        self.footer = [[UIStackView alloc] initWithArrangedSubviews:@[top, bottom]];
        self.footer.axis = UILayoutConstraintAxisVertical;
        self.footer.spacing = 10;
        self.footer.distribution = UIStackViewDistributionFillEqually;
        [self updateTitle];
    }
    [content addSubview:self.footer];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat width = MIN(360, CGRectGetWidth(safe) - 48);
    CGFloat height = MIN(self.pickingFriends ? 520 : 500, CGRectGetHeight(safe) - 40);
    CGFloat y = self.pickingTest ? CGRectGetMaxY(safe) - height - 12 : CGRectGetMidY(safe) - height / 2;
    self.panel.frame = CGRectMake(CGRectGetMidX(safe) - width / 2, y, width, height);
    self.titleLabel.frame = CGRectMake(14, 16, width - 56, 30);
    self.helpButton.frame = CGRectMake(width - 44, 14, 30, 32);
    CGFloat top = 58;
    if (self.pickingFriends) {
        self.search.frame = CGRectMake(10, top, width - 20, 48);
        top += 54;
        self.selectionBar.frame = CGRectMake(18, top, width - 36, 34);
        top += 42;
    }
    CGFloat footerHeight = (self.pickingFriends || self.pickingTest) ? 44 : 94;
    self.footer.frame = CGRectMake(18, height - footerHeight - 18, width - 36, footerHeight);
    self.table.frame = CGRectMake(0, top, width, MAX(0, CGRectGetMinY(self.footer.frame) - top - 12));
}

- (void)updateTitle {
    if (self.pickingFriends) {
        NSUInteger flame = 0;
        for (NSDictionary *friend in self.friends) if ([friend[@"hasFlame"] boolValue]) flame++;
        self.titleLabel.text = [NSString stringWithFormat:@"选择互关好友（%lu · 🔥%lu）", (unsigned long)self.friends.count, (unsigned long)flame];
        [self.saveButton setTitle:[NSString stringWithFormat:@"保存选中（%lu）", (unsigned long)self.selectedIDs.count] forState:UIControlStateNormal];
        self.emptyLabel.text = self.friends.count ? @"没有匹配的好友" : (self.loadingFriends ? @"正在读取互关好友…" : @"未读取到互关好友\n请先在抖音打开消息页后重试，原选择会保留。" );
        self.emptyLabel.hidden = self.groups.firstObject.count + self.groups.lastObject.count > 0;
    } else {
        self.titleLabel.text = self.pickingTest ? @"选择测试配置" : @"自动消息设置";
        self.emptyLabel.text = self.pickingTest ? @"当前账户还没有配置" : @"还没有配置\n点击下方添加，或选择互关好友";
        self.emptyLabel.hidden = self.configs.count > 0;
    }
}

- (void)filterFriends {
    NSString *query = self.search.text.lowercaseString ?: @"";
    NSMutableArray *flame = [NSMutableArray array], *other = [NSMutableArray array];
    for (NSDictionary *friend in self.friends) {
        NSArray *aliases = [friend[@"aliases"] isKindOfClass:NSArray.class] ? friend[@"aliases"] : @[];
        NSString *haystack = [[NSString stringWithFormat:@"%@ %@ %@ %@", friend[@"name"], friend[@"userID"],
            friend[@"displayID"] ?: @"", [aliases componentsJoinedByString:@" "]] lowercaseString];
        if (query.length && ![haystack containsString:query]) continue;
        [([friend[@"hasFlame"] boolValue] ? flame : other) addObject:friend];
    }
    self.groups = @[flame, other];
    [self.table reloadData];
    [self updateTitle];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text { [self filterFriends]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.pickingFriends ? 2 : 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.pickingFriends ? self.groups[section].count : self.configs.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!self.pickingFriends || !self.groups[section].count) return nil;
    return section == 0 ? @"🔥 火花好友" : @"互关好友";
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if (!title.length) return nil;
    UIView *header = [UIView new];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(18, 0, MAX(0, tableView.bounds.size.width - 36), 34)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.text = title;
    label.textColor = UIColor.secondaryLabelColor;
    label.font = [UIFont systemFontOfSize:14];
    [header addSubview:label];
    return header;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView titleForHeaderInSection:section].length ? 34 : 0.01;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return self.pickingFriends ? 64 : 58; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DYYY.AutoMessage.Row"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DYYY.AutoMessage.Row"];
    NSDictionary *row = self.pickingFriends ? self.groups[indexPath.section][indexPath.row] : self.configs[indexPath.row];
    cell.textLabel.text = row[@"name"] ?: row[@"userID"];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.backgroundColor = UIColor.clearColor;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.image = nil;
    cell.accessibilityIdentifier = row[@"userID"];
    if (self.pickingFriends) {
        BOOL selected = [self.selectedIDs containsObject:row[@"userID"]];
        cell.backgroundColor = selected ? [UIColor.systemOrangeColor colorWithAlphaComponent:0.88] : UIColor.clearColor;
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.tintColor = UIColor.whiteColor;
        NSInteger days = [row[@"flameDays"] integerValue];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", days > 0 ? [NSString stringWithFormat:@"火花 %ld 天 · ", (long)days] : @"", row[@"displayID"] ?: row[@"userID"]];
        UIImage *placeholder = [UIImage systemImageNamed:@"person.crop.circle.fill"];
        UIGraphicsImageRenderer *placeholderRenderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(36, 36)];
        cell.imageView.image = [placeholderRenderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [placeholder drawInRect:CGRectMake(0, 0, 36, 36)];
        }];
        NSString *url = row[@"avatar"];
        UIImage *cached = url.length ? [self.avatarCache objectForKey:url] : nil;
        if (cached) cell.imageView.image = cached;
        else if (url.length) {
            NSURL *avatarURL = [NSURL URLWithString:url];
            NSString *scheme = avatarURL.scheme.lowercaseString;
            if ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) {
                __weak typeof(self) weakSelf = self;
                __weak UITableViewCell *weakCell = cell;
                NSString *uid = row[@"userID"];
                NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:avatarURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    UIImage *image = data ? [UIImage imageWithData:data] : nil;
                    if (!image) return;
                    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(36, 36)];
                    UIImage *thumb = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
                        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 36, 36)] addClip];
                        [image drawInRect:CGRectMake(0, 0, 36, 36)];
                    }];
                    [weakSelf.avatarCache setObject:thumb forKey:url];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([weakCell.accessibilityIdentifier isEqualToString:uid]) { weakCell.imageView.image = thumb; [weakCell setNeedsLayout]; }
                    });
                }];
                [self.avatarTasks addObject:task];
                [task resume];
            }
        }
    } else {
        NSInteger mode = [row[@"sendMode"] integerValue];
        NSString *type = mode == 2 ? @"仅图片" : (mode == 1 ? @"文字＋图" : ([row[@"randomText"] boolValue] ? @"每日随机" : @"固定文字"));
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", type, mode == 2 ? [NSString stringWithFormat:@"%lu 张", (unsigned long)[row[@"imagePaths"] count]] : (row[@"message"] ?: @"")];
        if (self.pickingTest) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        else {
            UISwitch *toggle = [UISwitch new];
            toggle.tag = indexPath.row;
            toggle.on = [row[@"enabled"] boolValue];
            [toggle addTarget:self action:@selector(configToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.pickingFriends) {
        NSString *uid = self.groups[indexPath.section][indexPath.row][@"userID"];
        if ([self.selectedIDs containsObject:uid]) [self.selectedIDs removeObject:uid]; else [self.selectedIDs addObject:uid];
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateTitle];
    } else if (self.pickingTest) {
        NSDictionary *config = [self.configs[indexPath.row] copy];
        [self dismissViewControllerAnimated:YES completion:^{
            [DYYYUtils showToast:@"正在请求测试发送，等待抖音回执"];
            [DYYYAutoMessage sendConfig:config manualTest:YES completion:^(BOOL success, NSString *reason) {
                [DYYYUtils showToast:reason];
            }];
        }];
    } else {
        __weak typeof(self) weakSelf = self;
        [DYYYAutoMessage editConfigFrom:self existing:self.configs[indexPath.row] completion:^{ [weakSelf reloadConfigs]; }];
    }
}
- (void)configToggled:(UISwitch *)toggle {
    if (toggle.tag >= self.configs.count) return;
    self.configs[toggle.tag][@"enabled"] = @(toggle.on);
    if (![self.configs[toggle.tag][@"ownerID"] length]) self.configs[toggle.tag][@"ownerID"] = [DYYYIMService accountID];
    [DYYYAutoMessage saveMessageConfigs:self.configs];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return !self.pickingFriends && !self.pickingTest; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete || self.pickingFriends || self.pickingTest) return;
    [self.configs removeObjectAtIndex:indexPath.row];
    [DYYYAutoMessage saveMessageConfigs:self.configs];
    [tableView reloadData];
    [self updateTitle];
}
- (void)reloadConfigs { self.configs = [DYYYAutoMessage messageConfigs]; [self.table reloadData]; [self updateTitle]; }
- (void)addConfig {
    __weak typeof(self) weakSelf = self;
    [DYYYAutoMessage editConfigFrom:self existing:nil completion:^{ [weakSelf reloadConfigs]; }];
}
- (void)addFriends {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *config in self.configs) [ids addObject:config[@"userID"]];
    __weak typeof(self) weakSelf = self;
    [DYYYAutoMessagePanel showFriendsFrom:self selectedIDs:ids completion:^(NSArray<NSDictionary *> *friends) {
        [DYYYSettingsHelper showTextInputAlert:@"消息内容" defaultText:@"[点火]" placeholder:@"为选中好友设置发送内容" onConfirm:^(NSString *text) {
            NSMutableArray *configs = [DYYYAutoMessage messageConfigs];
            NSMutableSet *existing = [NSMutableSet set];
            for (NSDictionary *config in configs) if ([config[@"ownerID"] isEqual:[DYYYIMService accountID]]) [existing addObject:config[@"userID"]];
            for (NSDictionary *friend in friends) {
                if ([existing containsObject:friend[@"userID"]]) continue;
                [configs addObject:[@{ @"userID":friend[@"userID"], @"ownerID":[DYYYIMService accountID], @"name":friend[@"name"], @"message":text ?: @"", @"enabled":@YES } mutableCopy]];
            }
            [DYYYAutoMessage saveMessageConfigs:configs];
            [weakSelf reloadConfigs];
        } onCancel:nil];
    }];
}
- (void)testConfig {
    NSString *account = [DYYYIMService accountID];
    if (!account.length) { [DYYYUtils showToast:@"当前登录账户尚未就绪"]; return; }
    NSMutableArray *configs = [NSMutableArray array];
    for (NSDictionary *row in [DYYYAutoMessage messageConfigs])
        if ([row[@"ownerID"] isEqual:account]) [configs addObject:row];
    if (!configs.count) { [DYYYUtils showToast:@"请先为当前账户添加配置"]; return; }
    DYYYAutoMessagePanel *picker = [DYYYAutoMessagePanel new];
    picker.pickingTest = YES;
    picker.configs = configs;
    [DYYYAutoMessagePanel presentPanel:picker from:self];
}
- (void)selectAll { for (NSArray *group in self.groups) for (NSDictionary *row in group) [self.selectedIDs addObject:row[@"userID"]]; [self.table reloadData]; [self updateTitle]; }
- (void)selectNone { [self.selectedIDs removeAllObjects]; [self.table reloadData]; [self updateTitle]; }
- (void)saveSelection {
    NSMutableArray *selected = [NSMutableArray array];
    NSMutableSet *resolved = [NSMutableSet set];
    for (NSDictionary *row in self.friends) if ([self.selectedIDs containsObject:row[@"userID"]]) { [selected addObject:row]; [resolved addObject:row[@"userID"]]; }
    // 联系人缓存暂不可用时仍保留之前选中的 ID，不能因列表加载失败而清空原配置。
    for (NSString *uid in self.selectedIDs) if (![resolved containsObject:uid]) [selected addObject:@{ @"userID":uid, @"name":uid }];
    void (^completion)(NSArray *) = self.selectionCompletion;
    [self dismissViewControllerAnimated:YES completion:^{ if (completion) completion(selected); }];
}
- (void)closePanel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)showHelp {
    if (!self.pickingFriends) {
        [DYYYAutoMessageEditor showHelpFrom:self];
        return;
    }
    self.loadingFriends = YES;
    [self updateTitle];
    __weak typeof(self) weakSelf = self;
    [DYYYAutoMessage loadMutualFriends:^(NSArray<NSDictionary *> *friends) {
        weakSelf.friends = friends;
        weakSelf.loadingFriends = NO;
        [weakSelf filterFriends];
    }];
}
- (void)dealloc { for (NSURLSessionDataTask *task in self.avatarTasks) [task cancel]; }
@end

