# DYYY AI Agent 提示文档

本项目是基于 Theos/Logos 的抖音 UI 调整 Tweak。当前仓库 README 标注仅在 **抖音 36.5.0** 版本测试；回答需求时请以仓库现状为准，不要沿用旧版本描述。

## 工程关键点
- **昵称上方标签与头像光圈**：`DYYYFeedTagGlass.(h/m)` 默认给原生标签行的点击推荐、好友推荐、通用/轮播标签等铺深色薄毛玻璃，固定 alpha 为 0.9、不跟随共享透明度设置；只替换已有背景槽，保留内容、点击和原生尺寸。不得给整条元素栈铺满背景，离开视频交互层时恢复。`DYYYAvatarRing.(h/m)` 仅管理作者头像内的 `AFDColorRingView` 绘制子视图，不能隐藏光圈根视图、改根 alpha 或移除手势；开关 `DYYYHideAvatarColorRing` 默认关闭，直接平铺在隐藏设置的「视频播放界面」分组，与头像相关开关相邻，不新增二级菜单。原生配置/动画更新前恢复、结束后重新应用，嵌套更新只在最外层处理，关闭/复用恢复原生显隐。推荐入口及好友推荐标签需在原生模型、背景、文字和动画更新前恢复样式、最外层结束后重铺；同轮状态变化仅合并一次主队列补同步，不能依赖切换视频触发布局，不轮询或挂全局视图 Hook。共享 Hook 见 `DYYYFeedDecorationsHooks.xm`。
- **39.5 分享控制器与调试玻璃**：录制确认实际分享控制器为 `AWESharePanelController`，需与新版容器并行适配；仅在该控制器内按半屏根视图或底部宽面板识别背景宿主，不猜私有字段、不把玻璃铺满整屏遮罩。新版分享页把玻璃挂在实际内容控制器根视图，原生 `contentColor` 源值需保存、清除和恢复。调试菜单默认使用独立毛玻璃背景层，共用透明度，文字与按钮在上层保持可读；材质在非零尺寸时创建。轻量导出包含 `panelBlur` 的宿主、挂载状态和透明度，便于核查未适配层级。
- **分享与评论长按毛玻璃**：`DYYYPanelBlur.(h/m)` 和 Hooks 分别使用 `DYYYEnableSharePanelBlur`、`DYYYEnableCommentMenuBlur` 两个独立开关，默认关闭；位于界面设置的透明度设置内。与评论区、通知栏共用 `DYYYCommentBlurTransparent`，由 `DYYYUtils.sharedBlurTransparency` 统一校验（默认 0.9，允许 0–1）。只在面板外壳内铺一层普通毛玻璃并清理中性底板，不能修改整个面板或文字图标的 alpha；保留好友头像、彩色图标与外部遮罩。复用/关闭/离页时先恢复毛玻璃接管值，再恢复菜单调色值，避免残留底色。共享原生 Cell 的布局时只处理当前面板，不挂全局 UIView/CALayer 写入 Hook。
- **首页文章底栏黑边**：`DYYYArticleBackdrop.(h/m)` 与 Hooks 仅处理首页 `AWEFeedGeneralArticleCellViewController` 下的文章页。保留原生 Lynx 视口与正文位置，用内容底边的不透明像素行延展背景至全高宿主底部；不改全局窗口、正文 Frame 或交互层。取样合并为短延迟与一次补取样，换模型/复用/离页移除，关闭全屏或尺寸不符时恢复。Hook 复用搜索框架延迟加载安装入口；参考 DYKiller 的 DKFeedCardFit 并保留 MIT 声明。
- **评论菜单动作图标**：复制、收藏/取消收藏、搜索仅在深色评论功能行内使用缓存的白色 SF Symbols 覆层，沿原生图标槽或文字行首留白定位；原生图标透明度单独保存并恢复。覆层不接收触摸、不参与无障碍朗读，关闭/复用/切换动作时移除；其他图标、头像和彩色火花仍走原有绘制，不挂全局 UIImageView 写入钩子。
- **评论菜单文字对比度**：`DYYYCommentMenuPalette` 在深色评论长按菜单中将中性正文调整为 96% 白、半透明辅助文字调整为不透明的 78% 灰；富文本逐段处理，保留彩色火花与透明占位文字。好友横排的 `ShareContactListTargetCell`、`ShareContactListRecentShareCell` 在布局/进入窗口时局部同步，复用或离开评论菜单恢复；禁止对所有 UILabel 或普通分享面板全局提亮。功能图标仅在功能行内识别，不能处理好友头像。
- **菜单实际底色与调试面板**：评论长按菜单的深色 trait 不会自动改写原生白卡片；`DYYYCommentMenuPalette.(h/m)` 只在该菜单内部改中性色背景、功能行 `contentShapeLayer`、文字及专用图标，保存原值，退出/复用恢复，不改好友头像和识图缩略图。功能行布局与外壳布局同步，不挂全局 UIView/CALayer 写入钩子。调试操作和导出错误提示使用 `DYYYDebugMenuView.(h/m)` 自绘材质和文字按钮；`DYYYDebugAppearance` 读取屏幕/场景系统主题并记录诊断，文件分享仍由系统负责。
- **评论顶部空白占位**：`DYYYCommentHeaderLayout.(h/m)` 与 Hooks 只收起 `DYYYHideCommentViews` 已隐藏、单模型且没有其他可见内容的原生顶部业务行。通过分区高度、尺寸与原生回调同步，折叠状态变化才合并一次布局更新；不直接改评论列表 Frame、不增加全局偏好通知或布局循环。评论计数和分页仍由原生布局；遇到未知内容或多模型时保留原高度，复用 Cell/关闭功能恢复原生高度。适配参考 DYKiller 的分区接口，保留 MIT 署名。
- **分享标签定位与调试弹层**：分享标签以 `AWEPlayInteractionAuthorElementProtocol` 对应的可见昵称行定位，保持昵称上方 6 点间距，不把整栈预留行计入；深色磨砂样式保持原样。`DYYYDebugAppearance.(h/m)` 只管理调试菜单、导出错误提示和文件分享面板，主题读取屏幕与场景的系统外观，在系统外观变化/回到前台时更新，不继承抖音主窗口的固定浅色。弱引用跟踪弹层，不改全局窗口。消息/分享接口声明并入完整导出，普通轻量包仍包含 `independentIM` 和 `friendShareFeed` 状态摘要。
- **评论长按菜单主题**：`DYYYCommentMenuTheme.(h/m)` 与 `DYYYCommentMenuThemeHooks.xm` 只绑定原生 `CommentLongPressPanelSheet` 及其功能行，在创建菜单及显示前同步抖音主题，并用同一 trait 执行原生颜色构造。仅在评论毛玻璃或悬浮输入开启时接管，关闭后恢复；不得强制修改主窗口、键盘或所有分享面板的主题。录制事件 `commentLongPressMenuThemeApplied` 记录应用后的主题，真机效果需安装确认。
- **合集整行显隐**：`DYYYCollectionRows.(h/m)` 适配 DYK 的原生元素规则与布局顺序：识别 `AWEPlayInteractionNewMixVideoInfoElement` 和 `AWETemplateNewBottomElement/playlet_bar`，在元素栈原生布局前同步，`AWEBaseElementView.setHidden:` 只合并原生请求与隐藏规则。单项开关的模板分类在布局入口读取已存在的交互模型并缓存；显隐回调不得查找/创建容器、读取控制器模型、遍历文案、执行布局或发起刷新。行与栈均有重入保护，不添加全局偏好通知布局循环；不拦截 `mixInfo/playletInfoModel` 删除模型数据。保留 DYK 来源和 MIT 声明。
- **好友分享消息读取**：`DYYYIMHistoryReader.(h/m)` 在后台只读查询中支持按会话分组/列表外壳的结果，先校验目标会话及末条覆盖，再提取未读。优先已观察的会话查询和末条时间附近查询，旧版明确 ID 入口仅按需扩窗，不把最早 2000 条当近期未读；单好友失败保留其余结果。账户校验和扫描回调在主线程，切账户/退后台丢弃旧批次，不改已读状态。CI 的 `Test IM history reading` 用 Foundation 执行真实窗口选择回归。
- **好友分享来源与聊天视频**：`DYYYFriendShareBadgeView.(h/m)` 在首页文案栈上方展示头像、好友名及「分享给你」，使用深色薄磨砂材质；来源按账户与视频 ID 保存，待刷来源保留、已完成来源最多 256 条，切换模型清除旧标签，不能修改视频原文案。`DYYYChatVideoLayout.(h/m)` 仅处理私信视频详情页：按原生快捷回复栏的实际高度补齐 Cell 与播放器，交互层继续停在回复栏上沿；键盘/横屏不补高，背景和受管 Frame 可在关闭全屏后恢复，禁止用首页 Tab Bar 高度猜测私信栏尺寸。
- **搜索页精简**：`DYYYSearchClean.(h/m)` 与 `DYYYSearchCleanHooks.xm` 移植 DYKiller 搜索模块，在隐藏设置的「视频播放界面」与「侧边栏」之间仅放一个「搜索页」分区，七项设置平铺。使用 DYYY 独立偏好键，榜单目录按原生 ID 收录；历史/猜你想搜只改搜索模板的渲染副本，不能删历史数据。全移除使单榜单入口和完整榜单开关置灰但不清配置。相机隐藏用透明 mask 保留点击，移除通过原生许可收拢。dyld C 回调只负责识别搜索/Lynx 框架并调度类方法，按 Hook 组只安装一次；抖音私有声明统一放 AwemeHeaders。
- **评论输入区与表情面板**：展开玻璃依原生 middle 的完整内容计算高度，工具栏下留白 10 点，与面板间隔 8 点；用整个输入容器的可恢复 transform 抬升，禁止裁短玻璃盖住工具栏。原生 setFrame/layout 前撤回抬升，避免累计位移；背景视图补足抬升区域的点击范围。跟踪弱引用表情面板集合，包括快捷栏、整页评论面板和输入控件的自定义 inputView；可见面板优先于切换中残留的键盘 frame。关闭功能或收起时恢复 transform、裁切和背景。
- **博主主页返回首页**：玻璃底栏的显隐保护仅作用于此前底栏可见、且从 `AWEUserDetailViewControllerV2` 返回 `AWEFeedRootViewController` 的过渡。手势取消必须恢复原先 hidden/alpha；不要全局强制显示底栏，不要在 setHidden/setAlpha 内触发完整布局。
- **玻璃底栏启动与诊断**：`DYYYGlassTabBar.xm` 在原生按钮尚未创建时可用缓存外观预显示，原生按钮就绪后才启用点击。子视图镜像回调只同步内容，签名改变才请求布局，禁止每次回调直接完整重排。`DYYYGlassTabBar.h` 暴露只读布局状态，普通调试导出与录制脉冲可读取计数，不得为诊断主动触发布局。
- **Hook 入口**：`DYYY.xm` 负责 Feed、浮窗、全局透明度与 Tab Bar 高度等通用 Hook；`DYYYSettings.xm` 负责抖音设置页相关 Hook（`AWESettingBaseViewController`、`AWELeftSideBarWeatherLabel` 等）并构造 DYYY 自定义设置。
- **业务核心**：`DYYYManager` 统一处理媒体下载、批量任务、Live Photo/GIF/WebP 转换及保存流程，内部维护 `NSOperationQueue` 与下载任务/回调映射；`DYYYSettingsHelper` 管理设置依赖、入口查找、用户协议弹窗；`DYYYUtils` 处理 IP 属地、颜色、窗口查找、缓存路径等可复用逻辑。
- **UI 组件**：所有自定义视图/弹窗（如 `DYYYBottomAlertView`、`DYYYFloatSpeedButton`、`DYYYAboutDialogView` 等）都有 `.h/.m` 配对文件，并在设置控制器中组合使用。
- **模型/数据**：`CityManager` 负责本地城市映射与 GeoNames 查询；GeoNames 结果缓存逻辑在 `DYYYUtils`；`DYYYConstants.h`、`DYYYSettingsHelper` 中定义的 Key 控制远程 ABTest、依赖关系与通知。
- **AwemeHeaders**：项目依赖的抖音私有类、Category 声明、宏定义都集中在 `AwemeHeaders.h` 中，供整个 tweak 引入。

## 类路径速查（按 UI/功能分组）
- **入口 Hook / 控制器**
  - `DYYY.xm`、`DYYYSettings.xm`：全局 Hook、设置页 Hook。
  - `DYYYSettingViewController.(h/m)`：自定义设置主界面。
  - `DYYYSettingsHelper.(h/m)`：设置项依赖、入口、协议弹窗。
- **业务/下载**
  - `DYYYManager.(h/m)`：下载、合成、任务管理、授权。
  - `CityManager.(h/m)`：城市映射与 GeoNames 查询。
  - `AWMSafeDispatchTimer.(h/m)`：安全延时定时器。
- **通用工具/常量**
  - `DYYYUtils.(h/m)`：窗口/颜色/路径等工具。
  - `DYYYConstants.h`：Keys、URL、通知名。
- **好友发送配置**：`DYYYAutoMessageEditor.(h/m)` 管理同屏添加、按好友编辑、固定或每日随机文字、变量插入和本地图片选择。文字由 `DYYYAutoMessage` 渲染后统一发送；图片上传接口未适配时必须明确提示并停止含图发送，不能假报成功。
- **不发送时间段**：`DYYYAutoMessageQuietHoursPanel.(h/m)` 使用玻璃列表管理多段时间，支持逐段启停、添加、编辑和侧滑删除；添加窗口分别输入 0–23 的开始/结束小时，跨午夜按本地小时判断，开始与结束相同不保存。`DYYYAutoMessage` 沿用原偏好键把旧单字符串迁移为启用的时段数组，空数组表示已清空；时间限制只用于自动发送，手动测试入口不增加限制。
- **自动消息弹窗**：`DYYYAutoMessagePanel.(h/m)` 展示配置开关列表与互关好友搜索多选，配置读写和联系人适配由 `DYYYAutoMessage` 负责。
- **独立 IM 适配**：`DYYYIMService.(h/m)` 复用抖音创建的消息服务实例，读取联系人、未读分享并校验会话账户，通过原生回执维护每日发送状态；`DYYYAutoMessageHooks.xm` 观测服务生命周期与发送结果。手动测试使用独立入口，不限制每日次数，不写自动发送日账；配置列表先选测试对象，停用配置也可测试。文字格式由原生调用或历史识别，按抖音版本及账户缓存，不能硬编码未知消息类型。私有声明集中在 `AwemeHeaders.h`。
- **好友分享首播衔接**：批次模型就绪/超时后合并插入，整批原生插入期间禁止自定义重排。插入后使用 `reloadWithCurrentIndex:` 同步 Cell/索引，再对仍处于活动首页的目标调用 `playIfActive`，不能只做 UITableView.reloadData 或零位移滚动；无动画滚动必要时补 `playVideoOnScrollDidEnd`。仅首批主动切到分享，后续保留当前作品与暂停意图；用户点击/拖动、切账户和退后台取消旧激活任务，不重复定时强制播放。真实进度回调才记 `progress_confirmed`，调试包含播放阶段及原生索引。
- **好友分享待刷续推**：`DYYYFriendShareHistory.(h/m)` 按账户持久保存待刷视频 ID、好友来源与顺序，扫描结果先落盘再加载/插入。冷启动及返前台从待刷队列恢复并合并新分享，不依赖聊天未读；旧来源缓存中尚未已刷的条目可迁移。真实两次递增播放进度后，仅首页表格的用户垂直滑走或原生播完一轮才消费；导航搜索、退出、取消拖动、首帧卡住或仅插入均不能消费。当前已播完的 Cell 离开前保留；来源的 256 上限只裁剪已完成项目，不能裁掉待刷。Foundation 回归覆盖 10 条刷 3 条、重启剩 7 条再合并新消息、全部刷完和账户隔离。
- **好友分享推荐**：`DYYYFriendShareService.(h/m)` 在冷启动或从后台返回后扫描所选好友的本地未读分享，先用抖音 AWEIMFeedVideoCachePool（requestScene 为 dm）取得真实 AWEAwemeModel，再通过模型插入接口放在原首页列表之前；确认列表存在该 ID 才记已插入。模型缓存保留未刷分享，原生刷新后仍可恢复；加载失败保留待重试，禁止空转重复插入。已刷记录独立于聊天已读，按账户保存；实际滑走或播放循环后才记已刷，已刷记录不能立即删除正在播放的分享。调试导出包含 friendShareFeed 的加载、超时和插入状态。未编译和真机验证前不得宣称适配已通过。
- **设置页复用 UI（按交互类型）**
  - 列表/选择：`DYYYKeywordListView.(h/m)`、`DYYYOptionsSelectionView.(h/m)`、`DYYYFilterSettingsView.(h/m)`。
  - 输入/图标配置：`DYYYCustomInputView.(h/m)`、`DYYYIconOptionsDialogView.(h/m)`、`DYYYImagePickerDelegate.(h/m)`、`DYYYBackupPickerDelegate.(h/m)`。
  - 弹窗/提示：`DYYYBottomAlertView.(h/m)`、`DYYYConfirmCloseView.(h/m)`、`DYYYAboutDialogView.(h/m)`、`DYYYToast.(h/m)`。
- **浮窗与快捷操作**
  - 漂浮按钮：`DYYYFloatSpeedButton.(h/m)`、`DYYYFloatClearButton.(h/xm)`。
  - 长按/面板：`DYYYLongPressPanel.xm`、`DYYYBottomAlertView.(h/m)`（复用提示）。
- **辅助代理**
  - `DYYYImagePickerDelegate.(h/m)`、`DYYYBackupPickerDelegate.(h/m)`：统一封装系统 Picker 逻辑。
  - `DYYYCustomInputView.(h/m)`：文本输入。
- **ABTest / 远程配置**
  - `DYYYABTestHook.(h/xm)`：抖音 ABTest 注入。

(按上述分组定位 `.h/.m/.xm` 文件，可快速找到对应 UI 或业务类。若新增类，请将文件放入同类路径并在这里补充。)

## DYYYManager 与 DYYYUtils 职权边界（必须遵守）
- **DYYYManager（业务编排层）**
  - 负责“业务流程”与“任务生命周期”：下载发起/取消、批量任务、进度聚合、回调分发、相册保存、失败收敛、资源清理。
  - 允许维护业务状态与映射（如 downloadID、batchID、progress/completion 字典）。
  - 可以调用 `DYYYUtils` 完成底层工具能力，但不应在这里堆积与业务无关的通用工具。
- **DYYYUtils（无状态工具层）**
  - 负责可复用的通用能力：窗口/控制器查找、文件与缓存路径、媒体格式识别与转换、视频音频合成辅助、颜色与文本渲染、通用提示封装。
  - 方法应尽量“输入明确、输出明确”，不保存下载任务状态，不承担批量流程编排。
  - 不依赖 `DYYYManager`，保持单向依赖：`DYYYManager -> DYYYUtils`。
- **落点判定规则**
  - 需求涉及任务状态机、重试/取消、批次统计、统一收尾：放 `DYYYManager`。
  - 需求可被多个模块复用，且不需要业务上下文状态：放 `DYYYUtils`。
  - 若同一功能同时包含“流程编排 + 工具细节”，编排留在 `DYYYManager`，细节下沉为 `DYYYUtils` 新方法。
- **禁止项**
  - 禁止在 `DYYYUtils` 新增下载任务字典、批量计数器、业务开关同步逻辑。
  - 禁止在 `DYYYManager` 新增纯 UI 颜色算法、通用视图遍历、与下载/保存无关的杂项工具函数。

## 开发规范
### 1. 头文件管理
1. **所有新增的抖音类/方法声明必须写入 `AwemeHeaders.h`**，保持集中管理，避免在其他文件里散落声明。
2. 自定义 `UIView` Category 或辅助宏同样放在 `AwemeHeaders.h`，必要时按功能分段并维持已有注释风格。
3. 外部库统一通过已有 `AwemeHeaders.h` 或对应 `.h` 引入，避免重复 import。

### 2. 类与函数组织
1. 项目内业务类一律使用 `DYYY` 前缀，并拆分 `.h/.m`；Logos Hook 保持在 `.xm` 文件。
2. **禁止随意添加全局 C 函数**。如需新能力，请优先扩展已有类（`DYYYManager`、`DYYYSettingsHelper`、`DYYYUtils` 等）或创建新的 `DYYYXXX` 类。
3. 使用 `#pragma mark` 分隔方法区域，公开方法在 `.h`，实现细节留在 `.m`。

### 3. Hook 实现
1. 使用 Logos 语法 `%hook/%orig/%new`。对敏感类（如 `AWESettingBaseViewController`）需要在 `dealloc` 中清理 KVO/通知（示例：`DYYYRemoveRemoteConfigObserver`）。
2. Hook 中新增的手势、子视图必须通过 `objc_setAssociatedObject` 或弱引用管理生命周期（天气控件入口即参考）。
3. 所有 UI 写操作必须在主线程 `dispatch_async(dispatch_get_main_queue(), ^{ ... })`，避免阻塞抖音线程。

### 4. 设置/远程配置
1. 开关值均来自 `NSUserDefaults`，统一使用 `DYYYGetBool/DYYYGetString` 等宏或 `DYYYSettingsHelper` 提供的方法。
2. 复杂依赖关系写入 `+[DYYYSettingsHelper settingsDependencyConfig]`，包括 `dependencies/conditionalDependencies/conflicts/mutualExclusions/valueDependencies/synchronizations`。
3. 远程配置与 ABTest 常量统一在 `DYYYConstants.h`（如 `DYYY_DEFAULT_ABTEST_URL`、`DYYY_REMOTE_CONFIG_FLAG_KEY`、`DYYY_REMOTE_CONFIG_CHANGED_NOTIFICATION`）；新增配置时保持命名一致并添加注释。

### 5. 下载与媒体处理
1. 与下载、文件系统相关的逻辑集中在 `DYYYManager`，复用单例属性（下载队列、任务映射等）。新增流程必须复用 `finalizeDownloadWithFileURL:success:` / `finalizeDownloadWithID:success:fileURL:` 一类公共清理方法。
2. 操作 `PHPhotoLibrary` 前必定请求授权并回到主线程触发 UI（参考 `+saveMedia:mediaType:completion:`）。
3. 转码/合成任务使用 `dispatch_queue_t` 或 `NSOperationQueue`，并通过回调通知 UI 层，避免阻塞 Hook。

### 6. UI 与交互
1. 所有弹窗、输入框、选择视图均继承自 `UIView` 或自定义控件，负责自己的布局和动画，控制器或 Hook 仅负责组装。
2. 新的设置项请沿用 AWESetting 模型（`AWESettingSectionModel`、`AWESettingItemModel`）的构造方式，保持 icon/identifier/type 配置完整。
3. Toast、提示统一调用 `DYYYToast` / `DYYYBottomAlertView`，不要直接 `UIAlertController`。

### 7. 资源与缓存
1. `DYYYCustomAssetsDirectory`、`NSCache` 等资源缓存均用 `dispatch_once` 初始化。新增缓存时务必限制容量或提供清理策略。
2. 自定义图片命名遵循 `DYYYCustomIconFileNameForButtonName` 中的映射逻辑，保持文件夹结构一致。

### 8. 代码风格
1. 注释与 UI 文案使用简体中文，文案集中在对应视图或 `DYYYConstants` 中。
2. 常量使用 `static const` 或 `#define`，根据是否需要编译期常量选择，命名与现有风格一致（如 `kDYYYGlobalTransparencyDidChangeNotification`）。
3. 统一 clang 格式：4 空格缩进，`@interface` 属性使用 `nonatomic, strong/assign/copy` 顺序。

### 9. 调试与日志
1. 允许在调试时使用 `NSLog(@"[DYYY] ...")`，发布前要确保不会过度刷屏。
2. 关键路径失败时发送 UI 反馈（`DYYYToast showToast:`）并写 log，保证用户可感知。

### 10. 最终检查
- 新增 Hook 是否受开关保护并能恢复默认行为。
- 是否确保弱引用/通知/定时器释放（`AWMSafeDispatchTimer` 用于延时场景）。
- 所有新增抖音类声明已写入 `AwemeHeaders.h`。
- 是否在对应类/文件中添加函数，并补充必要头文件 import。

## 常见工作流示例
1. **新增抖音 UI Hook**
   - 在 `AwemeHeaders.h` 声明目标类/属性。
   - 于 `DYYY.xm` 或 `DYYYSettings.xm` 新增 `%hook`，逻辑用 `NSUserDefaults` 开关控制。
   - 如果需要 UI，则在 `DYYY` 前缀视图中实现并在 Hook 内调用。
2. **扩展设置开关**
   - 在 `DYYYSettingsHelper` 为依赖体系补充 key。
   - 在设置面板中创建 `AWESettingItemModel`，identifier 与 `NSUserDefaults` key 对齐。
   - 按职责边界实现功能：业务流程进 `DYYYManager`，通用无状态能力进 `DYYYUtils`。
3. **新增媒体处理能力**
   - 在 `DYYYManager` 内添加对应实例/类方法，并封装异步流程。
   - 通过现有回调（下载完成、进度回调等）向 UI 传递状态。

## 构建与测试（make）
- 本地验证优先执行 `make clean package`（或至少 `make package`），确认 tweak 能编译并生成 `.deb`。
- 需要安装到设备验证时，执行 `make package INSTALL=1`（依赖 `THEOS_DEVICE_IP` 配置），编译完成后会通过 `after-package` 自动推送并 `dpkg -i`。
- 切换不同包方案（roothide/rootless）时，通过 `make package SCHEME=rootless` 之类的命令指定 `SCHEME`，保持与目标设备一致。
- CI 或无人值守只需运行 `GITHUB_ACTIONS=true make package`，脚本会自动跳过安装并将产物放在 `packages/`。
- 本地机器建议通过 `Makefile.local` 覆盖 `THEOS_DEVICE_IP` 等私有配置，避免直接改主 `Makefile`。
- 每次回答涉及编译/测试的需求前，先说明是否已运行上述 `make` 命令以及结果，避免 AI 漏检构建错误。

## 复查清单（AI 回复前自检）
- 需求涉及的类是否已存在，若无应在 `AwemeHeaders.h` 与对应 `DYYY` 类中创建。
- 逻辑是否保持线程安全（UI→主线程，IO→后台）。
- 是否引用了现有工具（`DYYYUtils`、`DYYYSettingsHelper`、`DYYYToast`），避免重复造轮子。
- 是否描述了用户可见的行为及开关，确保可通过设置界面操作。

遵循以上约定可以保证 tweak 的 Hook 安全性和可维护性，也方便 AI Agent 在回答问题或生成补丁时保持统一风格。
