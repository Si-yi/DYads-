# DYYY AI Agent 提示文档

本项目是基于 Theos/Logos 的抖音 UI 调整 Tweak。当前仓库 README 标注仅在 **抖音 36.5.0** 版本测试；回答需求时请以仓库现状为准，不要沿用旧版本描述。

## 工程关键点
- **作者作品页与评论回复入口的图片文案间距**：`DYYYDetailCaptionLayout.(h/m)` 只管理从 AWEUserDetailViewControllerV2/AWEUserHomeViewControllerV2 或已确认的互动消息 AWEIMFansAndInteractMergeViewController（9E6D8407：评论回复通知入口）进入的 AWEAwemeDetailTableViewController 中图片（awemeType=68）、实况与 animatedImageVideoInfo 实况。悬浮输入开启且 r9 胶囊实际可见、收起、竖屏时，文案左栈下移至胶囊上方约 16pt，最多 32pt；有 AWEStoryProgressContainerView 图片分页条时，仅平移其 AWEStoryProgressSlideView 内容与文案同量移动，容器 frame 保持原样；按实际 3pt UICollectionView 分页线约束下移量，线必须留在原 HUD 点击范围内，且距输入至少 4pt，不能覆盖输入。输入框 frame/高度、播放器、右侧按钮、首页与普通视频完全不接管。 私信 AWEAwemeIMDetailTableViewController 明确排除，不能把消息主列表或普通聊天页当成评论回复来源；来源仍校验详情前一张原生导航页面，不按标题或截图文字猜测。沿既有左栈 layout/arrangedSubviews 的嵌套更新前恢复原 transform，保留用户缩放，最外层结束后按实际坐标叠加可恢复平移；离窗、离页、换模型、切视频、关闭悬浮输入及展开键盘时恢复。输入胶囊原生布局结束后只局部同步，不轮询或挂全局 UIView/CALayer；弱引用跟踪状态。DYYYDetailCaptionMetrics 的回归覆盖记录中的坐标、图片分页条边界、已合适间距与关闭路径，导出只记录几何数字，不记录文案。 动图可带有 3pt 高、无子视图/子图层/内容/背景/描边/阴影/遮罩的分页空壳：仅忽略该空壳的测量，不移动或隐藏它；实际未知分页仍保守跳过。时间/IP 纯 UILabel 行以可见文字底边测量，不能把原生行尾空白计作文字；复合行保持原 bounds。 上下切页时按 AWEAwemeDetailCellViewController.view 的整页坐标测量文案和分页线，将实际胶囊的视口位置映射到尺寸一致的页内坐标；不能用带 table 滚动位移的屏幕坐标相减，也不能等覆盖屏幕中央才调整。预加载相邻 Cell 即使被原生隐藏，也要准备其页内最终位置（只忽略页外 Cell 的显隐，页内元素自身的 hidden/alpha 仍遵循原生）。原生 willDisplayCell 和页容器布局结束前同步，交互层布局 begin/end 嵌套期间暂不应用，最外层结束立即提交；只对受管 transform 禁用动画，保留原生整页滑动。分页中的 viewWillDisappear 不提前恢复造成旧位置闪现，实际离开作用域/离窗、切普通视频、关闭功能及展开输入仍恢复；输入与普通视频尺寸保持原样。
- **长按评论隐藏收藏**：`DYYYHideCommentLongPressFavorite` 默认关闭，平铺在隐藏设置的「长按评论」分组。`DYYYCommentMenuItems` 仅在原生评论菜单普通分区的 setModelsArray/replaceByModels 输入中按 elementContent 精确移除收藏、取消收藏、已收藏（含富文本）；不改原模型/动作或收藏状态，不依赖毛玻璃开关，不操作视频右栏收藏按钮。功能项布局前过滤，余项连续排列，关闭后下一次打开恢复原生入口。
- **右下角音乐图标文字**：`DYYYSameStyleVisibility.(h/m)` 隐藏右侧元素栈内 `AWEPlayInteractionSingleSongMusicStyleView` 与 `AWEPlayInteractionStyleOneMusicView`（81ADA564 已确认的“玩同款”另一原生样式，二者均直接继承 UIView）直接子 UILabel 的所有标题，包括拍同款、玩同款及其他音乐入口文案，不再按固定文字匹配；保留组件根视图、AWEMusicCoverButton、缩略图、原生点击遮罩、无障碍动作和尺寸，不能隐藏或移除整个入口。设置名为「隐藏图标文字」，沿用独立开关 `DYYYHideSameStyleButton` 与原有取值、默认关闭，平铺在视频播放界面的隐藏音乐按钮下方。原生模型/标题更新前恢复、结束后重新应用，布局仅补同步；关闭/复用/离窗恢复标题原始 hidden，不处理视频文案和其他元素的标题，不改点击功能。隐藏标题时同时将 playInteractionCircleMaskView/playInteractionMaskView/playInteractionColorMaskView 的 CALayer.mask 可恢复地替换为透明绘制遮罩，去掉遗留半圆底板；不改 UIView.hidden/alpha/命中及图层 opacity，不处理 AWEMusicCoverButton 内的封面绘制；原生更新前及关闭/离窗恢复装饰层原 mask。两个音乐类分别按类可用状态安装一次模型/标题/装饰/布局与挂窗钩子，共用显隐及装饰恢复管线；不能只放宽辅助类判定却漏装另一类钩子，也不能假定二者为继承关系。
- **昵称上方标签与头像光圈**：`DYYYFeedTagGlass.(h/m)` 默认给原生标签行的点击推荐、好友推荐、通用/轮播标签等铺深色薄毛玻璃，固定 alpha 为 0.9、不跟随共享透明度设置；只替换已有背景槽，保留内容、点击和原生尺寸。不得给整条元素栈铺满背景，离开视频交互层时恢复。`DYYYAvatarRing.(h/m)` 仅管理作者头像内的 `AFDColorRingView` 绘制，用可恢复的透明 layer.mask 屏蔽原生晚写 hidden 后重新露出的渐变/动画圈；保存原 mask，关闭/复用/离窗还原；头像为外层兄弟视图，不能隐藏光圈根视图、改根 alpha 或移除手势；开关 `DYYYHideAvatarColorRing` 默认关闭，直接平铺在隐藏设置的「视频播放界面」分组，与头像相关开关相邻，不新增二级菜单。原生配置/动画更新前恢复、结束后重新应用，嵌套更新只在最外层处理，关闭/复用恢复原生显隐。推荐入口及好友推荐标签需在原生模型、背景、文字和动画更新前恢复样式、最外层结束后重铺；同轮状态变化仅合并一次主队列补同步，不能依赖切换视频触发布局，不轮询或挂全局视图 Hook。共享 Hook 见 `DYYYFeedDecorationsHooks.xm`，各组按实际类可用状态只安装一次；复用已有框架加载通知补装，普通导出记录可见光圈/遮罩计数。
- **39.5 分享控制器与调试玻璃**：录制确认实际分享控制器为 `AWESharePanelController`，需与新版容器并行适配；仅在该控制器内按半屏根视图或底部宽面板识别背景宿主，不猜私有字段、不把玻璃铺满整屏遮罩。新版分享页把玻璃挂在实际内容控制器根视图，原生 `contentColor` 源值需保存、清除和恢复。调试菜单默认使用独立毛玻璃背景层，共用透明度，文字与按钮在上层保持可读；材质在非零尺寸时创建。轻量导出包含 `panelBlur` 的宿主、挂载状态和透明度，便于核查未适配层级。
- **分享与评论长按毛玻璃**：`DYYYPanelBlur.(h/m)` 和 Hooks 分别使用 `DYYYEnableSharePanelBlur`、`DYYYEnableCommentMenuBlur` 两个独立开关，默认关闭；位于界面设置的透明度设置内。与评论区、通知栏共用 `DYYYCommentBlurTransparent`，由 `DYYYUtils.sharedBlurTransparency` 统一校验（默认 0.9，允许 0–1）。只在面板外壳内铺一层普通毛玻璃并清理中性底板，不能修改整个面板或文字图标的 alpha；保留好友头像、彩色图标与外部遮罩。复用/关闭/离页时先恢复毛玻璃接管值，再恢复菜单调色值，避免残留底色。共享原生 Cell 的布局时只处理当前面板，不挂全局 UIView/CALayer 写入 Hook。
- **首页文章底栏黑边**：`DYYYArticleBackdrop.(h/m)` 与 Hooks 仅处理首页 `AWEFeedGeneralArticleCellViewController` 下的文章页。保留原生 Lynx 视口与正文位置，用内容底边的不透明像素行延展背景至全高宿主底部；不改全局窗口、正文 Frame 或交互层。取样合并为短延迟与一次补取样，换模型/复用/离页移除，关闭全屏或尺寸不符时恢复。Hook 复用搜索框架延迟加载安装入口；参考 DYKiller 的 DKFeedCardFit 并保留 MIT 声明。
- **评论菜单功能键边框**：评论菜单毛玻璃开启时，由 DYYYCommentMenuGrid 在评论菜单专用 List/NormalSection VM 中保存原分区模型并合并显示到首个功能分区，保留原始元素和动作；其他功能分区清空渲染并收起页脚，好友分区不变。通过原生 sizeForItem/configCell 接口连续两列排列，举报稳定移到末尾；最后单项保持半宽，由当前实际原生布局类的属性副本居中，点击范围与显示一致。禁止只平移整行内的底板来伪装半宽按钮，仅为 CommentLongPressPanelNormalBaseCell 功能行增加深色/浅色半透明圆角底和细描边，隐藏绘制原生分组底板；头像行不接管；选择好友后的「建群并发送」仅在 ShareAdditionTextView 内改绿色底、白字和细边框，保留 targets/启停与「分别发送」原样。发送按钮类从原生映像按语义名解析，布局/离窗局部同步，不绑定 Swift 哈希。绘制层不改命中；两列内容对齐只叠加可恢复 transform，按原生 center/bounds 幂等计算，避免每次布局撤回又重加；复用/离窗/关闭恢复。选人后边框完整收在发送区上方的可见范围内。关闭、复用、离开菜单时移除并恢复底板，不叠加多层模糊。菜单高度按原生布局中最后一个实际半宽功能项底边加底部安全距离测量，不再把可能残留选人占位的 collectionView.contentSize 当作实际内容；通过已确认的 DUX updateSheetHeight 接口收紧；顶部间距必须取内层原生 UINavigationController.view 在 DUXVisualEffectView 中的实际起点，不能缓存 sheetHeight 减列表高度的差（过渡时会误取 44/64pt，在底部或输入区上方多留 28/48pt）；未挂入实际宿主不猜尺寸，正常布局回调就绪后测量。保留顶部间距、选人发送区和首行空间；选人高度取首个功能行底边；所有功能隐藏时改取实际好友行底边，再加输入区自己的完整高度。原生输入区可因面板过矮压成 0，必须按可见原生发送按钮判断选人态；按已观察的 126pt 原生正常高度、控件下沿与安全区恢复所需空间，不能再依赖外壳高度来判定是否有输入区，也不拿可变空底板高度当内容。禁止再用列表高度减输入区 y 值，避免键盘移动导致高度正反馈；取消后重新使用实际功能项高度，输入区还须有可见原生发送按钮才视为选人态，不能仅凭输入区外壳仍挂载判断；选人态允许从 184pt 的短菜单扩展到原生 minimumSheetHeight 范围并受屏幕上限约束，不能把选人前的短高度当成硬上限。自身应用高度不能写回 original，取消/关闭仍能恢复短面板。选人态原生迟到的好友行高度请求也须保持当前完整目标，防止再次压扁发送区；取消后立即撤销这个高度下限。核对真实 DUXVisualEffectView 高度与 sheetHeight；目标/选人状态/宽度签名变化时合并一次主队列更新，同一签名最多一次补修，必要时调用原生 updateSheetFrameAnimated 重排外壳，禁止布局轮询；同时约束 sheetHeight 与 minimumSheetHeight 的原生 setter，防止旧最小高度在取消时短暂撑高。选人状态回调在无动画作用域内执行原生变化与最终同步，发送区装卸/按钮显隐回调即时提交紧凑高度；提交有 applying 重入保护，普通布局保留一次合并更新，不能轮询改高。测量不依赖 contentOffset，取消后即使保留滚动偏移也要恢复。关闭时保存一份不含文本的最后几何诊断，便于菜单关闭后导出；关闭/离页恢复原高度和 minimumSheetHeight，关闭功能恢复各分区原模型。
- **评论菜单动作图标**：复制、收藏/取消收藏、搜索、删除等已确认动作仅在深色评论功能行内使用缓存的白色 SF Symbols 覆层；删除精确匹配「删除」并用 trash，选人禁用时沿用灰白符号，原生删除事件与启停不变，沿原生图标槽或文字行首留白定位；原生图标透明度单独保存并恢复。覆层不接收触摸、不参与无障碍朗读，关闭/复用/切换动作时移除；其他图标、头像和彩色火花仍走原有绘制，不挂全局 UIImageView 写入钩子。
- **评论菜单文字对比度**：`DYYYCommentMenuPalette` 在深色评论长按菜单中将中性正文调整为 96% 白、半透明辅助文字调整为不透明的 78% 灰；富文本逐段处理，保留彩色火花与透明占位文字。好友横排的 `ShareContactListTargetCell`、`ShareContactListRecentShareCell` 在布局/进入窗口时局部同步，复用或离开评论菜单恢复；好友 Cell 内仅对已确认 UILabel 逐实例监听 text/textColor/attributedText，原生取消后晚写颜色时局部纠正，自己写入有重入保护；复用、关闭、离窗先注销监听再恢复。禁止对所有 UILabel 或普通分享面板全局提亮。功能图标仅在功能行内识别，不能处理好友头像。
- **评论分享留言输入框**：`DYYYShareComposer.(h/m)` 仅管理评论菜单内 ShareAdditionTextView 中的 ShareTextView。按抖音主题同步中性 textColor、typingAttributes 和已提交文本的前景色，保留 font/段落/彩色提及、markedText、选区和原生发送；不得重设 text/attributedText 或清空用户输入。编辑通知仅监听该输入实例，状态释放时移除，不挂全局 UITextView Hook。输入框细边框沿实际发送按钮栈的左边距（通常 16pt）对齐，边框横跨输入与预览图整行，与发送按钮左右边距对齐；预览图只叠加可恢复的横向 transform 留出 8pt 内边距，保留原生点击；只可恢复地增加文字左内距，不改原生 Frame/键盘。底色/描边与功能按钮共用透明度，关闭/离窗恢复颜色、默认输入属性及左内距。诊断只记录颜色和边框几何，不记录用户输入内容。
- **评论分享多选状态**：39.5 选人后在 CommentLongPressPanelCollectionViewController.view 末尾新增浅色禁用遮罩。仅在已确认菜单内、且遮罩下沿与 ShareAdditionTextView 上沿相接的直接子背景槽中清除中性填充，保留 view.alpha、hidden、userInteractionEnabled 和原生触摸拦截；不得删除遮罩或启用被遮住的动作。禁用反馈直接用原生功能行的 78% 灰白文字与专用符号表达，取消后恢复；禁止再铺深色横条或复制文字镜像。发送区透明后，DYYYPanelBlur 只用可恢复的列表 layer.mask 截去被发送区遮住的旧菜单绘制；裁切停在最后一整行末尾，不能露出半行图标或文字；不改列表 Frame、滚动、命中或发送区内容，已有原生 mask 时保留并记录诊断。取消/关闭/复用恢复。ShareCommentHorizontalSectionController 的创建输入区/选人状态回调完成后立即同步并合并一次主队列补同步；ShareAdditionTextView 的真实装卸、显隐结束入口用弱引用保留菜单归属并补最终同步，取消后恢复正常高度，不能按动画延时猜测或轮询；内层列表布局仅即时同步，禁止布局轮询。好友 Cell.setSelected 后局部同步中性昵称，保留头像、火花、勾选徽标及红色发送按钮。菜单归属沿真实父控制器查找，并验证视图仍属于 Sheet；Hook 按组只安装一次，复用已有框架延迟加载入口补装。
- **调试菜单前保存现场**：DYYYDebugInspector 打开调试菜单前同步生成当前页面 DKDebugExportContext 和 JSON 深拷贝的诊断元信息，由本次菜单处理块持有，导出轻量/完整包都使用该快照，captureStage=before_debug_menu；不能等菜单关闭后重新采集，否则 @ 好友候选栏、键盘等临时视图已消失。开始记录的起始快照也用点击菜单前的现场；取消后释放本次上下文，保留既有录制生命周期，不新增后台截屏、轮询或永久缓存截图/正文。此改动只修采集时机，不等同于修复候选栏背景。
- **菜单实际底色与调试面板**：评论长按菜单的深色 trait 不会自动改写原生白卡片；`DYYYCommentMenuPalette.(h/m)` 只在该菜单内部改中性色背景、功能行 `contentShapeLayer`、文字及专用图标，保存原值，退出/复用恢复，不改好友头像和识图缩略图。功能行布局与外壳布局同步，不挂全局 UIView/CALayer 写入钩子。调试操作和导出错误提示使用 `DYYYDebugMenuView.(h/m)` 自绘材质和文字按钮；`DYYYDebugAppearance` 读取屏幕/场景系统主题并记录诊断，文件分享仍由系统负责。
- **评论顶部空白占位**：`DYYYCommentHeaderLayout.(h/m)` 与 Hooks 只收起 `DYYYHideCommentViews` 已隐藏、单模型且没有其他可见内容的原生顶部业务行。通过分区高度、尺寸与原生回调同步，折叠状态变化才合并一次布局更新；不直接改评论列表 Frame、不增加全局偏好通知或布局循环。评论计数和分页仍由原生布局；遇到未知内容或多模型时保留原高度，复用 Cell/关闭功能恢复原生高度。适配参考 DYKiller 的分区接口，保留 MIT 署名。
- **分享标签定位与调试弹层**：分享标签以 `AWEPlayInteractionAuthorElementProtocol` 对应的可见昵称行定位，保持昵称上方 6 点间距，不把整栈预留行计入；深色磨砂样式保持原样。`DYYYDebugAppearance.(h/m)` 只管理调试菜单、导出错误提示和文件分享面板，主题读取屏幕与场景的系统外观，在系统外观变化/回到前台时更新，不继承抖音主窗口的固定浅色。弱引用跟踪弹层，不改全局窗口。消息/分享接口声明并入完整导出，普通轻量包仍包含 `independentIM` 和 `friendShareFeed` 状态摘要。
- **评论长按菜单主题**：`DYYYCommentMenuTheme.(h/m)` 与 `DYYYCommentMenuThemeHooks.xm` 只绑定原生 `CommentLongPressPanelSheet` 及其功能行，在创建菜单及显示前同步抖音主题，并用同一 trait 执行原生颜色构造。仅在评论毛玻璃或悬浮输入开启时接管，关闭后恢复；不得强制修改主窗口、键盘或所有分享面板的主题。录制事件 `commentLongPressMenuThemeApplied` 记录应用后的主题，真机效果需安装确认。
- **隐藏文案关注**：DYYYHideCaptionFollow 默认关闭，平铺在隐藏设置「视频播放界面」，标题「隐藏文案关注」。复用 DYYYCollectionRows 原生元素行显隐管线；只在 AWEPlayInteractionViewController 的 AWEElementStackView 布局入口有限遍历 AWEBaseElementView 行，以同一行内两个不同原生按钮（UIControl 或无障碍 Button）标题精确匹配「关注」「暂不关注」确认目标，整行 hidden 并由原生栈收起占位，不改关注关系、右侧头像关注按钮或普通文案。setHidden 内只读缓存判定，不查控制器/遍历文字；原生显隐请求继续保存，关闭/复用时恢复，过滤掉隐藏项的 arrangedSubviews 也须从受管直接子行找回。设置变更只刷新弱引用跟踪的交互栈，不挂全局 UIView/UILabel 钩子或循环刷新。
- **合集整行显隐**：`DYYYCollectionRows.(h/m)` 适配 DYK 的原生元素规则与布局顺序：识别 `AWEPlayInteractionNewMixVideoInfoElement` 和 `AWETemplateNewBottomElement/playlet_bar`，在元素栈原生布局前同步，`AWEBaseElementView.setHidden:` 只合并原生请求与隐藏规则。单项开关的模板分类在布局入口读取已存在的交互模型并缓存；显隐回调不得查找/创建容器、读取控制器模型、遍历文案、执行布局或发起刷新。行与栈均有重入保护，不添加全局偏好通知布局循环；不拦截 `mixInfo/playletInfoModel` 删除模型数据。保留 DYK 来源和 MIT 声明。
- **IM 未读异常与读取范围**：`DYYYIMService` 优先使用当前 SDK root 的 cachedInstanceWithRootObject:identifier: 会话缓存，缺失时通过同 root 的 TIMXOConversationManager.fetchConversationsWithIdentifiers: 本地读取；扫描和自动发送不自行调用 instanceWithRootObject:identifier: 构造会话模型，不改 unreadCount/已读索引，不主动标已读/未读。专用未读结果先验证，若已取得有效数组（含空数组）且该好友无旧凭据待核实，跳过所有普通历史入口；专用查询失败且无确切边界、无旧凭据时也不盲读历史。旧错误来源反证和确切边界回退仍保留，不能丢失未刷分享或将历史凑成未读。导出记录 conversationSource、unreadAfterNativeQuery、unreadAfterScan 和变化标记；这里只能证明本次查询前后状态，不能据此宣称已确认重启异常原因或真机修复。
- **好友分享消息读取**：`DYYYIMHistoryReader.(h/m)` 后台只读查询支持分组/外壳，校验目标会话与末条覆盖；有首条未读时需继续扩窗至覆盖边界。边界同时匹配本地 identifier 与原生 serverMessageID；39.5 边界为空时优先使用已导出的 asyncGetUnreadMessagesFromSender:inConversation:limit:completion: 只读接口，异步有界等待，不阻塞主线程或 SDK 回调；结果逐条验证会话、发送者、消息 ID 并按未读数交叉校验。原生未读查询与确切边界都不能验证时记部分失败，不能误报没有新分享；不得退回按 unreadCount 凑历史好友消息，避免读出很久前的分享。查询历史可留作旧缓存反证，但不把它当未读。账户校验与回调在主线程，切账户/后台丢弃旧批次，不修改已读状态。日志包含 nativeUnreadCount、边界覆盖/匹配方式与截取结果，CI 覆盖服务器 ID 边界、缺失边界拒绝、历史回灌隔离及正常续推。
- **好友直接分享与引用隔离**：`DYYYIMShareParser.(h/m)` 同时校验发送者、原生消息类型与最外层作品 ID。39.5.0 真机已观察 8 为视频、77 为图文；83/105 的评论/引用也含顶层 itemId，绝不能因此放行；未知类型保留诊断但不猜为分享。v2 凭据必须同时保存 shareMessageType/shareMessageID/shareUnreadValidated，1.6.6 的 v1 凭据须重核，核实前暂存不推、不显示错误好友标签。完整历史只作反证/保留，不能仅因找到一条旧的真实分享就升级入队；只有当前已确认未读窗口能生成或升级有效凭据。旧凭据明确指向评论/引用时可撤销，或结合本账户发出与好友引用证据撤销；真实新版待刷不因聊天已读而丢失。旧来源不能降级新版凭据，跨账户隔离；列表清理保留当前作品及暂停意图。诊断只保存字段名、类型、分类和计数，不保存正文。
- **好友分享来源与聊天视频**：`DYYYFriendShareBadgeView.(h/m)` 在首页文案栈上方展示头像、好友名及「分享给你」，使用深色薄磨砂材质；来源按账户与视频 ID 保存，待刷来源保留、已完成来源最多 256 条，切换模型清除旧标签，不能修改视频原文案。`DYYYChatVideoLayout.(h/m)` 仅处理私信视频详情页：按原生快捷回复栏的实际高度补齐 Cell 与播放器，交互层继续停在回复栏上沿；键盘/横屏不补高，背景和受管 Frame 可在关闭全屏后恢复，禁止用首页 Tab Bar 高度猜测私信栏尺寸。
- **搜索页精简**：`DYYYSearchClean.(h/m)` 与 `DYYYSearchCleanHooks.xm` 移植 DYKiller 搜索模块，在隐藏设置的「视频播放界面」与「侧边栏」之间仅放一个「搜索页」分区，七项设置平铺。使用 DYYY 独立偏好键，榜单目录按原生 ID 收录；历史/猜你想搜只改搜索模板的渲染副本，不能删历史数据。全移除使单榜单入口和完整榜单开关置灰但不清配置。相机隐藏用透明 mask 保留点击，移除通过原生许可收拢。dyld C 回调只负责识别搜索/Lynx 框架并调度类方法，按 Hook 组只安装一次；抖音私有声明统一放 AwemeHeaders。
- **@ 好友候选栏背景**：39.5 完整包 744D8007 已确认黑底来自 AWECommentSearchViewController.collectionView（112pt 高、120pt 候选行内），已有 r9 展开玻璃覆盖整行。DYYYUpdateDetailInputTransparency 只在该控制器实际 collectionView 位于 Swift CommentInputContainerView 内且悬浮输入展开时，把其填充/opaque 纳入既有可恢复清底管线，露出同一块输入玻璃；不另加玻璃、不改列表 frame/头像/昵称/滚动/选择、不处理普通搜索页及表情面板。原生主题重写颜色后保存新值再清底；该控制器 appearance/layout/主题和父级挂载结束局部同步，消失或离开输入作用域时恢复保存的原生背景，关闭悬浮输入沿原管线恢复。不挂全局 UICollectionView/UIView 写入 Hook，不轮询。
- **评论输入区与表情面板**：展开玻璃依原生 middle 的完整内容计算高度，工具栏下留白 10 点，与面板间隔 8 点；禁止裁短玻璃盖住工具栏。完整表情面板可能嵌在 CommentInputContainerView 中，边界检测必须包含该分支；此时仅可恢复地上移 middle 与玻璃，不能连表情面板一起移动。独立键盘窗口仍整体抬升输入容器。middle/container 原生 setFrame/layout 前撤回各自抬升，避免累计位移；输入容器及背景视图补足抬升区域的点击范围。完整表情面板只跟踪位置，保留原生背景、effect、contentView、图片和表情 Cell，不清成透明。独立快捷表情行沿用透明底板，保存并恢复其原生颜色/effect；不得隐藏效果视图或内容。输入框清底规则须跳过完整表情面板及其包装分支。跟踪弱引用面板集合，包括快捷栏、完整面板和自定义 inputView；可见面板优先于残留键盘 frame。关闭或收起恢复 transform、裁切和输入框背景。
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
- **好友选择备注名**：自动消息与好友分享来源共用 `DYYYAutoMessagePanel`；联系人优先显示原生 `alias` 备注，缺省用昵称再用 UID。读取数据库行、内层用户及当前账户本地缓存，不发逐人网络请求；保留 `nickname`、`remarkName` 与搜索别名，搜索支持备注/昵称/抖音号/UID。离线缓存重新规范化，选择与配置仍按 UID，不改用户已有消息和自定义显示名。
- **自动消息批量修改**：自动消息配置列表的「批量修改内容」仅列出当前账户已添加的好友，支持搜索/全选/全不选并显示数量。复用文字编辑器的固定/每日随机和参数插入；保存时按捕获的账户与 UID 读取最新配置，仅覆盖 message/randomText，保留发送模式、图片、启停、显示名、createdAt 及独立发送记录；不触发发送、不恢复已删除配置。`DYYYAutoMessageBatch.(h/m)` 的 Foundation 回归覆盖部分/全部、同 UID 跨账户、未绑定旧配置与其余字段不变。批量编辑取消不写入配置。
- **自动消息弹窗**：`DYYYAutoMessagePanel.(h/m)` 展示配置开关列表与互关好友搜索多选，配置读写和联系人适配由 `DYYYAutoMessage` 负责。
- **独立 IM 适配**：`DYYYIMService.(h/m)` 复用抖音创建的消息服务实例，读取联系人、未读分享并校验会话账户，通过原生回执维护每日发送状态；`DYYYAutoMessageHooks.xm` 观测服务生命周期与发送结果。手动测试使用独立入口，不限制每日次数，不写自动发送日账；配置列表先选测试对象，停用配置也可测试。文字格式由原生调用或历史识别，按抖音版本及账户缓存，不能硬编码未知消息类型。私有声明集中在 `AwemeHeaders.h`。
- **首页离页恢复播放**：`DYYYFriendShareReturnState.(h/m)` 保存本次离页前实际可见作品与播放状态，Feed 离页与 AWEPlayVideoViewController 呈现弹层前保留第一次快照，不从播放器 Cell 的普通复用/消失回调截取意图；父 Feed 未收到返回回调时，用当前 Cell 内播放器 appearance 出栈后绑定补同步。仅真正回到活动首页、同一可见作品、离开前播放且现在停止时消耗一次恢复机会，先 playIfActive，再沿原有路径验证并最多准备 Cell 一次；不重载表格/改索引，不修改播放器私有暂停字段。手动暂停、换作品、切账户、用户手势和后台使旧快照失效；侧边栏/个人页仍可见时不能抢播。诊断记录返回快照、决策及实际播放阶段，不能把只收到生命周期事件当成真机播放成功。
- **好友分享首播衔接**：按已就绪模型一次性提交完整列表，提交期间禁止自定义重排，单条超时不能阻塞其余条目。插入后先用 `reloadTableViewData` 重载实际原生表格，再用 `reloadWithCurrentIndex:` 同步 Cell/索引，再对仍处于活动首页的目标调用 `playIfActive`，不能只做 UITableView.reloadData 或零位移滚动；无动画滚动必要时补 `playVideoOnScrollDidEnd`。仅首批主动切到分享，后续保留当前作品与暂停意图；用户点击/拖动、切账户和退后台取消旧激活任务，不重复定时强制播放。真实进度回调才记 `progress_confirmed`，调试包含播放阶段及原生索引。
- **好友分享待刷续推**：`DYYYFriendShareHistory.(h/m)` 按账户持久保存待刷视频 ID、好友来源与顺序，扫描结果先落盘再加载/插入。冷启动及返前台从待刷队列恢复并合并新分享，不依赖聊天未读；旧来源缓存中尚未已刷的条目可迁移。已刷以实际可见 Cell 开始并完成的首页用户垂直滑走为准，不要求播放进度（快速跳过、暂停、图文也算划过）；原生播完一轮仍需真实递增进度。导航搜索、退出、取消拖动、仅首帧停留或仅插入均不能消费。标准和 pi 手势入口在原生处理前保存起点并去重；结束事件出栈后再按稳定 Cell 结算，不能因代理内部 decelerating 仍为 YES 漏掉。手势及播放归属从 UITableView.visibleCells 中覆盖表格中心的 AWEFeedViewCell.viewController.model 读取，不能用可能滞后的 currentAweme/计算下标代替屏幕内容。直接播放器进度仅接收注册首页内、实际可见 Cell 与模型均匹配的实例；手势期间到达的有效进度也须更新起点证明。迟到批次同时过滤 active 缓存及原列表中的已刷 ID，避免整批重推。当前已播完的 Cell 离开前保留；来源的 256 上限只裁剪已完成项目，不能裁掉待刷。Foundation 回归覆盖 10 条刷 3 条、重启剩 7 条再合并新消息、全部刷完和账户隔离。
- **好友分享插入与普通推荐续刷**：合并列表以实际可见视频 ID（离页时用最后显示 ID）为插入锚点。首次选中分享时在锚点前插入，已开始刷视频后新批次接在当前视频后；此前普通推荐历史保留在当前位置之前，不能放到分享后导致从开机首条重刷。当前分享作为锚点时保留原位置，迟到批次去重接续；原生 setDataSource/load more/刷新重排也使用相同规则，不能每次把 active 搬到全表开头。锚点按 ID 定位，不能拿 filteredDataSource 的下标切原始数据。回归包含已刷十条、继续原位置、后续批次和原生追加列表。
- **好友分享跨页面准备与首播**：扫描、模型获取和一次性 `setDataSource:` 加 `calculateFilteredDataSource` 提交只要求应用在前台，不依赖首页可见；不得逐条插入时反复创建/停用 Cell。`DYYYFriendShareDelivery.(h/m)` 合并去重完整列表，隐藏首页不布局、不抢播；回到首页后统一重载选中目标。播放请求后验证是否实际启动，只有目标/模型匹配且页面仍活动、用户未接管时才允许一次原生 Cell 的 `prepareForDisplay` → `play`。39.5 现场确认 `updateAwemeList:` 不接收新 ID，不能用于整表插入；必须回读 dataSource 与 filteredDataSource 同时包含 ID 才确认插入，选中索引取过滤列表。已就绪视频不被单条超时阻塞，迟到的有效模型清除失败标记，每次前台会话最多静默自动重试一次，加载超时不弹提示；待刷持久化照旧。首页绑定限定 `AWEFeedRootViewController` 下的 HotList，不能绑定私信/详情页。
- **好友分享推荐**：`DYYYFriendShareService.(h/m)` 在冷启动或从后台返回后扫描所选好友的本地未读分享，先用抖音 AWEIMFeedVideoCachePool（requestScene 为 dm）取得真实 AWEAwemeModel，再按当前浏览位置合并到首页列表；确认列表存在该 ID 才记已插入。模型缓存保留未刷分享，原生刷新后仍可恢复；加载失败保留待重试，禁止空转重复插入。已刷记录独立于聊天已读，按账户保存；实际滑走或播放循环后才记已刷，已刷记录不能立即删除正在播放的分享。调试导出包含 friendShareFeed 的加载、超时和插入状态。未编译和真机验证前不得宣称适配已通过。
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
- GitHub Actions 使用 `macos-15-intel` 构建，Theos 缓存按 `runner.os` 与 `runner.arch` 隔离；40356512045 曾因 `macos-latest` ARM64 容量不足等待 15 分钟仍无法分配 Runner，不能当作源码编译失败。主机架构不改变三种 iOS 安装包目标。
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
