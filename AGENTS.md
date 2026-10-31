# DYYY AI Agent 提示文档

本项目是基于 Theos/Logos 的抖音 UI 调整 Tweak。当前仓库 README 标注仅在 **抖音 36.5.0** 版本测试；回答需求时请以仓库现状为准，不要沿用旧版本描述。

## 工程关键点
- **自定义未读时限可行性检查**：用户最终要求按最近7天（以后可填写天数、留空/关闭完全原生）忽略超时未读，旧历史仍可翻看；尚未完成计数链路验证，不得发布假功能开关或把提示数组过滤等同于原生总数已修正。此前红点试改8ae8039已应用户暂停构建41204924159，当前恢复原数字镜像，不混入后续检查包。DYYYUnreadProbe配对h/m+Hooks仅在调试开关ON按39.5真实签名、参数数与返回编码验证后安装三个UI提示/holder入口；orig原样执行并返回，主线程仅收集receiver/input/result类名+selector和计数，最多32种、无SDK数据getter/UID/正文/未读getter钩子/计数写入/定时器。沿现有调试overlay刷新点补安装，不额外轮询；完整导出优先含未读/提示/列表ViewModel和实际观察类、相关协议方法声明。需安装本检查包后正常打开消息页并完整导出一次（不必等99+异常）以继续确认消息页和总数统一入口。这是接口检查，不是已实现7天过滤，不改已读游标或把超时消息标已读。第14组Foundation回归验证签名/参数类型保护、关闭不记录、仅类名无正文、不调用description、合并去重及32种上限。
- **隐藏限时日常**：隐藏设置→提示与位置信息新增 DYYYHideHomeDaily（默认关闭，cellType37 说明重启生效）。DYYYHomeDailyFilter.(h/m)+Hooks 仅给真实 AWEFeedRootViewController 后代的 Feed 绑定弱宿主范围，原生 filteredDataSource 设置/计算结束过滤 AWEAwemeModel 的 is24Story/is25Story/isStory/isMomentStory 正标记，未知对象保留；不按 Story/RichContent 类名、文案或 TTL 默认值猜测，普通图文也使用这些容器。保留原始 dataSource 和原生过滤索引映射，不在 getter/布局修改集合，不改模型日常属性，不影响消息/主页/搜索详情；首次请求早于挂载时在首次显示前补算一次。偏好绑定时保存，重启稳定应用。Foundation 第13组覆盖开关/首页范围、原生标记、混合顺序与源数组不改、普通富内容/未知对象/异常 getter 保留。装机首页过滤效果仍待用户验证。
- **自动消息相关的随机未读回涨补充**：用户明确不是每次新消息都涨，频率不可预测；以前独立自动消息插件也同样，停用那个插件后没有。不得继续要求等待/制造新消息做固定触发对照，前项整插件追新消息对照已放下。此证据优先查自动发送共用SDK路径，仍不能宣称唯一根因已定。DYYYIMService.sendText 完全移除主动 messagesInConversation(limit1000/200)、earliest(limit200) 和 conversation.lastMessage读取；格式只用真实原生发送/原生历史返回被动学习及已有账户缓存，缺失明确提示用户先正常发文字，不写死messageType/不补查。保留原本每日sent/pending与手动测试排除、账户root/参与者校验、30秒未知回执保留pending，不改native未读/cursor。新增DYYYIMSendLedger配对Foundation类：仅正常原生发送成功回执、同账户同peer当天、非手动测试记录本机观察事实；dailyState可返回native_sent但不改本插件原sent/pending，跨日清理/跨账户隔离/重复回执幂等回归第12组。其他设备或停用期间发送无法从本机事实判断，帮助文案明确，不能以去掉历史检查声称能知道所有过去手动发送。自动runDaily/processDaily/sendConfig/sendText与每日状态键，以及被动三个格式/历史观察入口均只读已捕获contacts UID，不再由自动路径经accountID唤起HTSServiceCenter；显式用户联系人/手动测试入口仍可解析服务，自动未就绪跳过等待原生自然初始化。新增autoSend尝试计数和逐次stage诊断，不记录正文/账号，不用SDK getter热钩子/同步堆栈/轮询。这版是降低主动SDK接触并保留防重，真实随机回涨是否消失仍需日常使用确认，不能要求用户按时触发。
- **2B3CD832 未读1543（2.1.8）**：完整快照非上涨过程，截图底栏1543、好友行99+；friendShare OFF、lastScan/lastValidation为空、historyManagers0、knownTextFormats0、pending/source/inserted0、unreadObserverEnabled=false、被动缓存20；auto开关ON但不能据此断言本轮发送/历史检查已执行。全仓库核查无写unread/read游标或屏蔽已读入口，GlassTabBar只镜像原生DUXBadge数值，不在此累加。自动发送代码仍有历史去重/识别文字类型查询，但日志不证明本次调用，勿再凭此宣称唯一根因/盲改发布。整DYads停用对照此前用户仅说还没做，旧停插件3–5秒转圈测试不能混用；此次已重新异步请求：仅停DYads并重启、其他插件不动、让一条异常会话正常已读，再等新消息看旧记录是否回涨，等待实际结果。即便OFF仍涨也只能支持当下停用条件下复现，不能据此武断排除早先持久化状态影响或直接归罪其他插件。不得强清badge/标已读/改DB游标/恢复热路径计数观察。此次仅完成日志和源码审查，尚无根因或新修复版。
- **07BB94EC 2.1.7 原生按钮未选中**：轻量录制只有10文件，无新增完整运行时接口；metadata hidden=YES、zone绑定成功，但 nativeDetailRequested=false、nativeMoreMounted=false/targets0，截图仍下拉，证实配置字符串替换没接上实际路径，不能再称原生更多已挂载。移除失败的四个componentsName配置Hook与纯数组helper/第12套测试。改在真实 AWEIMMessageListNaviBarGroupZoneToggleComponent.naviBarView 原始提供路径，保留orig原按钮，创建并持有原生详情provider、按当前source的实际context和belongingManager绑定，必要时只转发一次可用的hostVC_viewDidLoad，再由它naviBarView生成真实AWEIMMessageBaseVCMoreButton；仅native按钮且有效targets/可交互才返回，失败保留orig并记精确decision，不显示自造假按钮。额外provider关联原source生命周期、弱context/manager/view，初始化失败同一上下文不反复重试。已存在原生更多仅从其actual target读取Class并验证target.naviBarView就是该按钮，不跨群复制target/view/context；缺省用已知详情类，未知缺失安全退回。晚绑定或设置切换仅合并一次现有原生NaviBarComponent.setNeedsUpdateNaviBar重排，无轮询/每帧重建；原群功能栏隐藏/恢复、玻璃与滚动防卡死保护不变。新诊断providerDecision、replacementClass、class可用性/实际挂载targets区分失败阶段；轻量录制也只读保存两个确切原生UI组件及最多三级AWEIM父类的有限方法声明（每类<=64），无聊天字段，避免再次缺接口仍盲改。必须装机验证真实入口，CI不证明私有provider实例化/跳转成立。
- **25FB7376 / CF687888 原生群详情与透明稳定**：2.1.6 第一包 hidden/zone/toggle/替换全部生效但用户确认点击无响应，说明合成头像位置手势仍不成立，不再沿用。第二包是原生电话+更多群（偏好OFF），真实按钮 AWEIMMessageBaseVCMoreButton，使用上游已确认 AWEIMMessageListNaviBarChatDetailComponent。删除自有Button/Gesture/转交；在39.5导出的 AWEIMConversationViewController 四个 eager/lazy componentsName 配置方法中，仅将精确群下拉组件名换为原生详情组件名，由抖音原生manager负责实例化、context、按钮与action，已有详情不重复、其他顺序内容与原生电话群不动；关闭返回原配置，切换需重新进入聊天页（设置小字已说明）。DYYYGroupChatComponents配对Foundation helper和第12套回归验证开关透传、共享配置不改、顺序、去重、嵌套幂等与未知结构不猜。诊断区分实际原生more挂载/targets、配置是否替换，完整导出补4个确切原生组件接口。顶栏瞬时控件/标题几何未就绪保留已active玻璃和列表topActive，不在局部重排撤回整栏；仅AWENavigationBar子类setter在已确认active聊天保存原生晚写color/opaque并应用clear，恢复前active=NO避免吞恢复；自有glass补恢复hidden/alpha与nil effect，不反复替换材质、不轮询、不改SDK/消息。仍保留上拉/原生批量更新期间禁止列表几何写入的防卡死保护。CI不能证明装机原生组件已被选中/点击跳转/透明闪动彻底消除。
- **2EF72158 / BE303321 / 044E38D6 群隐藏回报**：2.1.5 录制起始树与截图已确认开关ON时 GroupZoneEntryBar hidden=YES、高0，DYYYGroupSettingsButton 三点已挂载；录制结束回消息列表后弱状态 observedGroups=0，不能据此误判从未绑定。两份静态页面快照实际偏好OFF：一群原生电话+更多，一群单下拉，按两种布局分别处理。旧 hitTest 返回异支头像会保留触摸的右侧实际坐标，不能保证原生标题头像分支响应；改自有真实tap手势调用导出确认的 p_didClickSelfWithGesture:，locationInView映射为 avatarStackView 中心，保留原生标题delegate/群设置路由，不猜router、不复制私聊设置。仅替换单下拉，临时禁用并可恢复其原手势，关闭恢复图像mask/手势/功能栏/原展开态。宿主挂载后以确切GroupZoneEntryBar+right单plainUIView/UIImageView补绑定，读取现有componentManager.components补找原生zone、不创建组件；每个zone只收起一次，禁止布局中反复toggle。诊断增加绑定/替换挂载/入口可用性，不能以显示三点或构建通过声称真机点击已成功。
- **29925181 关闭分享仍回涨**：用户报告收到新消息仍出现几百未读且分享进推荐已关；2.1.3元信息 lastScan={}、pending/source/inserted均0、unreadObserverEnabled=false、会话缓存22，不能归因本轮分享扫描或已移除计数观察。请求仅停用整个DYads-并重启的隔离对照（原先停插件的3–5秒转圈对照与此未读问题无关，不可混用结论）；等待回复，未读根因仍未定，不强清徽标/改read游标。诊断新增实际auto/share/hideGroup偏好布尔值，不能假定用户已做全插件对照。
- **隐藏群聊功能栏新开关**：用户随后明确可选移除群功能栏，开关 DYYYHideGroupToolbar 默认关闭，隐藏设置→消息页与我的页→隐藏群聊功能栏，ON收起页签并将原下拉控件绘制替换为ellipsis，OFF恢复原生功能栏/下拉。DYYYGroupChatToolbar.(h/m)+Hooks 参考上游DKChatTopClean的原生Zone组件入口并保留MIT；仅群组件捕获，desiredGroupZoneHeight在ON返回0，原生toggle仅在状态实际改变时调用，保存原展开态用于关闭恢复，不反复改messageList几何。用户确认进入群设置的原生入口是群头像：三点按钮hitTest转交实际群头像视图及其原生手势，不猜私有route/action、不复制私聊聊天信息页。原头像仍保留。Swift功能栏仅按实例可恢复hidden/点击穿透，不改公告/成员/消息/权限。右侧在玻璃开关开启时由ChatChrome铺圆玻璃，hide键与玻璃键独立。方法/类缺失时按可用性安装，装机必须确认三点点击确实进当前群设置、开关OFF还原及连续上拉不冻，CI不是功能验证。
- **群聊顶栏/样式恢复**：96865BE2（2.1.3）群聊右侧是栈直挂 plain UIView 24×24/单UIImageView，旧筛选忽略并 actions_not_ready 退出整个顶栏。只在原生rightBtnsContainerView识别该严格结构，单操作圆玻璃44pt，原生下拉控件可恢复平移居中/清其底色，保留gesture/层级/功能；私聊双键仍共用胶囊，返回圆钮44pt与头像昵称间距不变。右侧未就绪不再撤掉返回玻璃或顶栏透明。2E103BED 展开群聊功能栏为 AWEIMGroupImpl.GroupZoneEntryBarView {0,106,440,42}、列表从148起，原生聊天/公告/置顶/收藏/设置页签的frame、背景、显示、点击都不接管，列表记录headerBottom并在开合时重新核对几何，top inset同量保留原生可读区域，页签仍为列表上方兄弟。AWENav已确认addRight/setRight/setContent更新后只合并一次重核；输入原生更新结束、宿主appearance/layout、消息更新/滚动完成局部修复绘制，保存自有effect以恢复被原生清掉的材质。repairController只在实际可见聊天运行且不自行排队，只在active边沿通知列表；Chrome同样只在顶栏active边沿通知列表，避免 paint→list→paint 循环，禁止轮询/每帧全树修复。保持2.1.3滚动/批量更新延后与幂等修正，构建不能替代群聊开合与丢失恢复装机验证。

- **聊天双玻璃关闭对照与上拉历史布局**：用户反馈关闭悬浮输入框+消息页顶栏玻璃并重启后未再卡死，支持范围在玻璃路径，尚不能区分两个开关或唯一根因，不沿用新增未读观察导致旧卡死的结论。DYYYChatInputList 不再在每个原生历史内容布局前无条件撤回视口；只有宿主bounds/输入框frame变化才撤回。拖动、减速、hasUncommittedUpdates、聊天专用表格reload/begin-end/performBatch更新期间禁止写frame/inset/offset，原生调用与completion照常转发。原生布局结束、批更新完成、滚动结束或table布局后合并一个弱引用主队列同步，不自调度/轮询。仅Hook AWEIMMessageTableView（39.5实际类）、可用原生list delegate，非全局 UITableView；批量更新嵌套depth与原有busy/nativeDepth独立。保留玻璃绘制与独立开关，诊断增tableUpdateDepth/pending。幂等比较保存的请求开关状态，不能用实际extension>0代表开关值：原生已经占满一端而扩展量为0时，旧判断会让另一端每轮拆建；Metrics回归覆盖top106/bottom0与top0/bottom98的双开场景、关闭配置与非法值。必须装机验证好友与群聊连续上拉，CI不能证明卡死已根除。

- **2.1.2 聊天历史卡死风险回退**：41763176 是2.1.1存活快照，lastScan空、无录制或线程采样，不能证明唯一卡死栈。用户澄清翻动/上拉好友或群聊天历史就卡，卡住时一切点击（含导出）无响应；不得再要求在卡死现场导出或称该包为卡死线程日志。彻底移除 TIMXOConversation unreadCount/setUnreadCount 钩子与 observeCount/计数map/同步取栈，避免SDK访问器内插件锁、模型hash与调用栈符号解析引入锁环。会话工厂只原样透传，返回后将弱模型/弱root投递到独立串行观察队列；无标识参数的工厂也不在SDK回调栈内读identifier。root缓存改WeakMemory|OpaquePersonality，不调用SDK hash/isEqual；diagnostics不强取活模型枚举，只报缓存槽与observerEnabled=false。保留弱缓存/原账户校验、不重新主动创建或拉历史；回归新增会hash/equality抛异常的模拟SDK root与并发读写/诊断，不能替代真机卡死验证。未读回涨仍未解决，不恢复热路径计数观察来继续诊断。

- **AA452BEF 再次未读异常**：2.1.0 已确认 historyKind=native_unread_only_no_history_fallback，五会话计数9/1/1/159/1，扫描前后完全相同；异常159会话专用未读只返回1。不能继续宣称历史回退是本次根因，也不能把首次看到大数当记录到上涨。DYYYIMConversationStore 配对 h/m 以 SDK root 弱键、会话弱值被动保留抖音自然创建的模型；五种已导出工厂 Hook 只透传后捕获，IMService 不再主动调用 cachedInstance/fetchConversations 来刷新会话，缺失等待原生就绪；账户根与原有参与者校验保留。getter/setter 原数透传，仅观察差值，首次大数/上涨>=32才取有限原生调用栈，内存最多32条、无内容或账户ID，诊断 conversationStore；不修改 count、游标、不标已读或强清badge。Foundation 回归验证同ID跨root、弱生命周期、缺失不创建、重复读取/首次大数与有界记录。此版是减少主动SDK接触与定位计数源，不能声称已找出或彻底修复未读回涨唯一原因。

- **返回圆钮不随未读数缩放**：8BCFE754/B2C5C75A（2.0.9）确认无未读圆钮 {8,66,36,36}、有未读 {16,62,44,44}，旧逻辑按原生标题 x 缩直径导致。固定 x16/44pt，与右侧胶囊同高；头像昵称至少在圆钮右12pt，原右侧空间不足则受约束。原生 UIButton/父未读组件动作不变，原 UIImageView 绘制用可恢复透明 layer.mask 接管，在玻璃 contentView 内以固定9×17pt chevron 路径与2.25pt圆头笔画居中；不再采样图片透明留白或平移原按钮。只掩图片不掩未读badge，布局前恢复原mask，关闭/离页恢复；弱引用快照与原有depth/busy保护，不改未读数。构建不能代替装机观感验证。

- **聊天顶栏间距与实际透明**：10F6A214（2.0.8）确认玻璃 active，返回 {16,62,44,44}、头像 x64.33，间距仅4.33pt。用户新授权头像/昵称整体右移约10pt（右控件前空隙不足则缩减），保存原 transform、原生标题/导航布局前恢复，幂等禁止累加；保持原生头像与文字内容/点击。箭头 alpha 像素包围盒缓存升级二维居中。该记录 bar 背景已 clear，但 list 从 y106 开始，清色无法让列表出现在顶栏后。DYYYChatInputList 统一保存上/下扩展，顶栏开关独立控制列表原点上移至宿主顶边、表格同量增高、top inset/indicator 等量补偿、offset.y 同量减以保持屏幕内容位置；回退时反向还原自有几何。和原有底部扩展共用同一快照与原生布局嵌套防护，不能两个模块互相覆盖高度。关闭/离页/未知结构恢复，语音/表情不额外延伸底部；仅普通聊天同宽直挂表格、竖屏和合理顶部<=180pt，不清宿主聊天背景或改顶部系统状态栏。诊断补 topExtension；构建不能声称装机背景/居中已验证。

- **液态玻璃独立入口**：按用户最终指示，「液态玻璃」是设置首页紧接「界面设置」的独立入口（orderedMainItems 也必须加入，不能只写 mainItems）。移走界面设置旧「毛玻璃设置」整组与增强设置的保存面板玻璃/面板透明度/长按面板玻璃；通知圆角 DYYYNotificationCornerRadius 移回界面设置→透明度设置，不属玻璃选项。沿用原偏好键、数值、回调与默认值；搜索索引登记新路径；不改变各材质实现或把原模糊材质统一强改 UIGlassEffect。

- **2.0.7 已读重新变未读**：用户澄清 61EF3DA2 针对消息未读恢复问题，不能误按顶栏诊断；该快照 lastScan=services_not_ready，不是计数跳变过程，不能宣称已锁定唯一根因。旧分享核验 revalidating 曾绕过 1.8.5 的 nativeUnread 短路，继续展开 2000..32000 条 SDK 历史。DYYYIMService 分享扫描彻底取消 observed/recent/earliest 回退，只接收原生专用未读结果，零未读会话跳过，失败/超时作为 partial、不凑旧消息。旧凭据仅用本次已返回未读消息核实，其余保持待核实，已验证待刷/已刷持久化不变；不得写会话 unreadCount/已读游标、发送已读回执或强制清徽标。HistoryReader 分享安全入口回归验证即使 legacy 或边界存在也不会调用历史 provider。已有异常计数不能可靠区分真实未读，不自动清除；需实机验证是否仍增长。

- **2.0.6 顶栏稳定与设置整理**：DFA7CCE5/35FFEEEC 均确认 2.0.5 聊天输入玻璃正常而 chatChrome.topBars.active=false，几何留有成功记录，不能凭快照断言唯一退出原因。聊天宿主页布局结束补同步；导航/未读/标题回调合并一个弱引用主队列复核，补原生 StackView 当轮未完成时退出后无恢复的路径，不轮询、不强制原生 layout。离页暂停待执行复核，返回恢复；无变化不重复撤回/写入 transform，原生布局前仍还原自有移动。诊断记录最后退出条件。独立 DYYYEnableChatTopGlass 命名「消息页顶栏玻璃」，旧聊天玻璃取值一次迁移后独立；输入框与表情圆角仍用 DYYYEnableFloatingChatInput。界面设置原底栏自定义改「毛玻璃设置」，紧接透明度设置；评论/分享/评论长按/通知毛玻璃、通知圆角、共用毛玻璃透明度整体移入，原键/取值不变。CI 不代表真机忽隐忽现已确认消除。

- **屏蔽展开视频缩放**：基本设置中紧接「启用首页全屏」新增独立 DYYYDisableCommentVideoShrink（默认关闭），标题严格按用户最后指示为「屏蔽展开视频缩放」，subTitle 为原生次要小字「展开评论区时，视频保持原尺寸，评论面板覆盖在画面上」。该项必须用 cellType=37（带说明开关行）；cellType=6 在用户 39.5 实机截图中不渲染 subTitle，仅写入字段或编译通过不能证明说明已显示。截图上方正常带说明的开关均为 37，沿用同一种原生灰色小字行；键、取值、顺序与功能不变。1EF25F8D（2.0.1）录制起点确认 AWEDPlayerViewController_Merge 根从 440×956 被改为 {128.53,-0.2273,182.94,368.3746}，结束快照已收起评论恢复全幅，不能仅看结束树就断言没有缩放。DYYYCommentVideoLayout.(h/m) / DYYYCommentVideoHooks.xm 参考 DYK 视频几何与 RichContent 缩放入口并保留 MIT：复用现有 UIView.setFrame 入口，只为已确认视频/RichContent 控制器自己的根视图换算成父容器自然满幅，所有原生布局调用仍透传，不吞 setter；子视图/按钮/文字/输入框/普通面板不接管。既有私信补高若为满宽原点且只高出父容器 <=160pt 则保留。普通视频抑制 videoDidShrink，图文/实况抑制两种 updateShrinkState:YES（裸 %orig 放行以免重组私有 struct），willDisplay/原生 layout 后同步且尺寸相同不写；关闭缩放恢复入口与原生 magnify 保留。PiP/浮窗非 normal window 不接管；不把横屏视频画面改为纵向 aspect-fill，不改变首页全屏/毛玻璃取值或播放/加载行为。只在设置切换时有界遍历控制器并还原本模块最后接管的 frame/gradient alpha；弱引用状态、主线程与 busy 保护，无轮询、新全局 Hook 或强制播放。复用 AwemeCore 延迟安装入口，各组只安装一次。诊断 commentVideoLayout 仅记录原生/目标/实际几何；构建通过不能声称所有入口已实机验证。
- **聊天 Codex 顶栏与表情面板弧度**：用户明确返回键单独圆形玻璃、右上电话/更多共用一块胶囊，头像/名字不圈入；澄清底部圆角指「整块表情面板的上边缘（像图四键盘顶部）」，不是输入框。DYYYChatChrome.(h/m) + Hooks 按已导出 39.5 AWENavigationBar.contentView/左右按钮容器、AWEIMNavigationUnreadView.backButton/unreadCountView 处理，参考上游 DYK ChatInput 语义入口并保留 MIT。同用户现有聊天玻璃键 DYYYEnableFloatingChatInput；设置名保留悬浮输入框，用 cellType37 说明顶栏与面板范围。只为 AWEIMMessageBaseViewController 内该顶栏增加返回圆玻璃和右侧按钮联合胶囊，几何约束在 titleView 之外，头像/昵称/火花不铺玻璃、不挪动。返回原 UIButton 的图标透明边缘用一次 32px alpha 采样缓存横向中心，原按钮仅可恢复平移以居中；未读数保留数值，以原生 badge 可恢复平移到返回钮角标位，不改未读/读取状态或动作。右侧原生按钮位置、原生 targets/命中/返回手势不替换，玻璃自身不交互；导航/未读组件原生布局、基类与聊天子类 updateWithCount: 及 p_updateUI 前撤回自有 transform，嵌套 depth/busy 防重入，结束同步，自己写入禁用动画。清理顶栏、content 与底线填充以透出聊天背景，关闭/离页/结构不符恢复颜色、opaque、裁剪与 transform，无全局 UIView/CALayer/UIButton Hook 和轮询。聊天 IESIMInputViewController.currentInputType==2 时，仅 AWEIMEmoticonPanelContainerView 及同起点同宽的原生面板包裹层（允许 <=80pt 安全区差）设置连续上方两角半径28与细边框；位置吻合的 AWEUIDynamicBlurEffect 兄弟底板也只裁同样上角、保留原 effect/颜色并保存恢复，避免圆角外残留矩形底板，不改 frame、原 layer.mask、表情/搜索/页签/发送/系统键盘或评论区共用面板；收起、换输入态、离页、开关关闭恢复自有圆角/角集合/描边/裁剪，原生新值保留。复用输入同步/延迟安装入口，主题和挂窗局部同步，弱引用状态和仅几何 diagnostics chatChrome。需实机核对外观，CI 只证明编译/打包。
- **聊天悬浮底栏**：2D69E19A（39.5）确认 IESIMInputViewController 隶属 AWEIMMessageBaseViewController，底栏原生 root=440×64，文本与背景槽同框 {8,10,424,44}，语音/表情/加号在独立前景。DYYYChatInputGlass.(h/m) 只处理聊天中的该输入 VC，在原生直接背景槽和 GrowingTextView 同框且槽内仅有背景绘制时铺一层 Regular 玻璃（旧系统 ThinMaterialDark），边框/圆角随原生槽尺寸变化，不改输入行 native frame、输入文字、选择、语音、发送、键盘、附件/表情面板和命中。原背景子层仅替换可恢复的透明 layer.mask，保留 hidden/alpha/交互；保存根底色、opaque、clips、圆角，原生更新前恢复，最外层结束后同步；关闭/离页/未知布局恢复原样，弱引用跟踪，无轮询及新全局 UIView Hook。独立键 DYYYEnableFloatingChatInput 默认关闭；按用户最终要求在界面设置的「底栏自定义」分组，标题「悬浮输入框」，副标题明确聊天输入与周边透明；不新增「聊天页自定义」分组，也不与原首页悬浮底栏绑定。Hooks 位于 DYYYChatInputGlassHooks.xm，复用现有 AwemeCore 延迟加载安装通道。导出 chatInputGlass 只记录几何/状态。
- **聊天输入周边透明补全**：B8C5BB62（2.0.0）确认聊天玻璃已挂载且启用，但输入 VC 的 64pt 根仍为不透明 #161616；只替换槽内绘制会留下整条背景。DYYYChatInputGlass 增加弱键背景快照，开启时清理输入 root、GrowingTextView 至 root 的已确认 plain UIView 前景路径，以及贴 root 底边、空且无交互的安全区底板，保留父聊天页面背景和原生 panelsContainer（消息列表底部延伸见后述）；不遍历按钮/文字绘制/附件/表情，不改 frame、文字或命中。关闭/离页/原生更新前恢复自己清理的颜色和 opaque，原生迟写先保存再接管。玻璃补与悬浮评论输入一致的 iOS26 capsuleConfiguration，沿用 Regular/ThinMaterialDark 与边框；不把默认聊天页本身的黑色背景误当输入残留。原生更新第一次进入即建立 depth 状态，避免嵌套回调提前同步。诊断增加清底数量与输入 root 底色/opaque，不记录输入内容。
- **聊天消息真正透过输入框**：58476BAB（2.0.1）确认输入 root 已 clear/非 opaque，5 处清底生效，但 AWEIMMessageListViewController.view 仍 {0,106,440,752} 且 clips=YES，列表止于输入 y858，胶囊后没有消息。用户指定 HierarchThurs/DYKiller 最新仓库，不能把 Si-yi 旧副本称作最新版。参考上游 261c2d5 的 ChatInput/DKChatInputList.xm（保留 MIT 许可），DYYYChatInputList 只延伸底部，不引入顶部/按钮分拆/输入下沉等功能：普通聊天收起/语音态、输入玻璃实际有效且原生表格直挂列表容器时，按宿主底边延伸容器与表格（本记录 +98pt），底部 contentInset/verticalScrollIndicatorInsets 同量补偿，保存并回写当前 contentOffset 保持阅读位置与末条可见；只触碰高度和底部 inset。原生 AWEIMMessageListLayoutComponent.p_layoutWithAnimation:coordinate:/updatePageLayout: 在快照计算前撤回，嵌套 depth/实例 busy 防重入，结束重算，幂等防累计；各方法仅实际存在才安装，复用 AwemeCore 延迟通道。键盘/表情/附件、横屏、离页、开关关闭或结构不符恢复，未知原生新值透传，不拉伸全局表格。原生回到底部/新消息提示补偿延伸量，保持在输入上方；不改消息正文、发送、读取状态或顶部。DYYYChatInputMetrics 回归覆盖实际坐标、已延伸/部分列表、面板与非法尺寸，CI 校验实际库包含 DYYYChatInputList。清底同时处理已确认 GrowingTextView.internalTextView 的颜色/opaque（不改文字及内部绘制子树）；补充参考上游已确认的 AWEUIDynamicBlurEffect 安全区底板，仅管理输入以下 <=128pt 的原生 effect，保存与关闭恢复，不隐藏视图/改变命中，不清整块附件/键盘。导出 chatInputList 仅记录几何/输入类型。
- **对外名称统一 DYads-**：Theos 目标改为 DYads-，对应变量为 DYads-_FILES/CFLAGS 等，实际注入库和过滤器为 DYads-.dylib / DYads-.plist；发布版本化下载名仍是 DYads-<version>.dylib。构建相关性/触发路径及提取脚本同步，提取必须匹配确切新库名，不能退回任意 dylib 掩盖改名遗漏。verify-tweak-identity.sh 检查三种 Deb 中新库/过滤器各一份且无旧 DYYY 注入文件，test-tweak-identity.sh 覆盖三种安装路径和旧名/混装/缺失/重复负例。日志文件夹/ZIP/元信息、调试工具显示文字及设置导出名使用 DYYY_NAME（DYads-）；旧类名、偏好键、包 ID com.huami.dyyy、备份格式和内部持久化路径保留兼容，不全局替换 DYYY。Deb 原包升级删除原包旧路径；手动侧载须替换旧 DYYY.dylib，不能同时注入新旧两份。
- **评论毛玻璃稳定性对照**：用户停用整个插件并重启后转圈时长相同、未观察到闪退；此前曾把一次回报理解为“只关闭 DYYYEnableCommentBlur 后未闪退”，但用户随后澄清之前测试是开启状态，因此不能再把该对照作为可靠的开关因果证据。59193759 确认 1.9.9、DYYYEnableCommentBlur=true，用户回报新版暂未闪退，仍不等于已证明唯一根因。移除既有全局 UIView.setFrame 中“开启评论毛玻璃且播放器视图 x 非零就直接 return”的分支，所有原生布局请求继续透传（保留独立全屏和私信布局既有规则）。AWECommentContainerViewController 不再在弹幕输入每轮布局追加白底并隐藏首个原生子视图；该分支保留原生绘制。DYYYUtils.applyBlurEffectToView 仅主线程执行，同 tag 效果及覆层复用，主题变化才重置 effect，相同背景/alpha 不重复写入。不新增轮询/全局钩子、不调整原生网络加载/强制隐藏转圈；九组回归和打包只能验证构建，闪退需重新开启评论毛玻璃后装机复测。
- **关闭悬浮输入时隔离全屏清底**：DYYYEnableFullScreen 曾在输入开关关闭后继续清理 Swift 输入子树底色、旧 AWECommentInputBackgroundView 还无条件平移，导致仅关悬浮输入不能作为完整的样式退出对照。DYYYUpdateDetailInputTransparency 的清底严格由 floating 控制；既有 UIView 背景写入/布局清底入口在关闭时对已确认输入外壳/子树透传。DYYYUtils.isCommentInputView 只按 AWECommentInputBackgroundView、Swift CommentInputContainerView、AFDMentionFeedIMBottomBarView 及有界祖先判定，不泛匹配普通底栏或键盘。旧外壳平移保存原 transform、原生布局前撤回，只有开启才叠加，关闭保留原生变换。首页/其他区域的独立全屏、评论毛玻璃、原生黑色私信条及视频几何不因此关闭；不改网络/播放或强制隐藏加载圈，不能声称修复了 3–5 秒等待或闪退。
- **悬浮输入设置与关闭恢复**：DYYYEnableFloatingCommentInput 移至界面设置的「底栏自定义」分组，沿用键/取值/默认值，移除空的「输入栏」分组，不与悬浮导航底栏开关建立依赖。FA501997 为开关关闭的对照：初始取数约 0.59–0.85 秒、播放器就绪约 0.64–0.89 秒，仍存在评论加载，不能断言开关解释了全部等待。AFDMentionFeedIMBottomBarView 的原生黑底圆角在适配前 1.9.1 的 ADD68736 就已存在；关闭后保留原生私信回复/表情，不把黑底武断判为玻璃残留。CommentInputContainerView 的旧裸指针 OBJC_ASSOCIATION_ASSIGN 子视图缓存已移除，改为当轮直接子视图查找；背景显隐只在悬浮输入开启时可恢复地接管，原生布局前撤回写入的 hidden，关闭时不再干预。该失效指针是代码中可确认的风险，但无崩溃栈不能宣称就是用户闪退根因。独立全屏设置、原生尺寸及播放加载流程保持既有职责。
- **详情加载诊断 r6**：FF7267E5 录制 24.95 秒、33 个主队列脉冲，间隔约 0.65–0.84 秒且正常停止；用户确认其中每次进入有 3–5 秒转圈，不能因心跳正常就判断没有故障，也不能据此归因网络。DYYYDebugInspector 只在用户主动开始记录时安装已确认详情/提及类的取数、数据完成、加载提示、首图/首帧及缓冲回调观察；沿既有 ABI 校验，原参数/调用/回执始终透传，新标记不抓调用栈/作品 ID/正文/网络内容。基类与子类分别按实际可用签名安装一次，以 receiver 关联；重复的 super 调用不是重复请求证据。现有有界 0.75 秒采样补可见原生加载提示几何和进程 physical footprint，不新增定时器、不改加载/播放/布局、不强制隐藏转圈。该版本是诊断增强，不能称为已修复等待或闪退。
- **提及详情底栏重复工作**：777D13B7（1.9.4）导出时评论已载入，不包含用户截图中的黑屏加载阶段，不能推断网络耗时。保留原生回调深度及 busy 保护；setFrame 结束不再无条件 setNeedsLayout，实际尺寸变化沿 UIKit 原生失效；updateWithAweme 不拆建玻璃，复用同一实例并捕获原生重写的背景，样式/尺寸/圆角/填充值相同不重复写入。离窗、关闭及无效尺寸仍恢复原生。不能用隐藏加载提示、超时假装成功、预读所有互动消息等方式掩盖等待。
- **互动详情快速进出稳定性**：D36E2F95/D171EEDE 是 1.9.3 的朋友/互动页存活快照，没有崩溃调用栈，不能据此宣称确定根因。详情表格主动改 frame 时加实例重入锁，finally 清理；AFDMentionFeedIMBottomBarView 的原生布局/模型/挂窗/主题回调按实例深度成对保护，只在最外层结束同步玻璃，setFrame 只撤回位移、透传并标记布局，不能在构造或拆卸中的 setter 内创建玻璃。离窗/关闭恢复也放在同步 busy 保护内，保留 6pt 对齐和原生交互，不增加延时轮询或全局 UIView Hook。
- **评论提及底栏玻璃**：ADD68736 确认 AFDMentionFeedIMBottomBarView 使用不透明 #161616 背景，含“该评论已无法查看”提示。DYYY.xm 仅在悬浮评论输入开启且该原生底栏在窗内时清除根填充，铺同款 Regular 玻璃（旧系统 ThinMaterialDark）及细边框；原生尺寸、文字、右侧按钮、点击与禁用状态不变。6EB8A649 确认该提及入口的底栏中心 909pt，普通悬浮输入中心 915pt；仅 AFDMentionFeedTableViewController 中、竖屏贴底宿主内的该底栏整体下移 6pt，文字/玻璃/命中一起移动，不改普通详情、首页、文案或进度条。用可恢复 transform，原生 setFrame/layout/updateWithAweme 前撤回，完成后同步；setFrame 若复用已平移 origin 须扣除旧位移，不能累积。缩放/旋转、离开贴底宿主、离窗或关闭开关恢复。updateWithAweme 前恢复、结束及布局/主题/挂窗后同步，离窗或关闭恢复保存背景；复用既有输入同步遍历，不增加轮询或全局 UIView 钩子。
- **作者作品页与评论回复入口的图片文案间距**：`DYYYDetailCaptionLayout.(h/m)` 只管理从 AWEUserDetailViewControllerV2/AWEUserHomeViewControllerV2 或已确认的互动消息 AWEIMFansAndInteractMergeViewController（9E6D8407：评论回复通知入口）进入的 AWEAwemeDetailTableViewController 中图片（awemeType=68）、实况与 animatedImageVideoInfo 实况。悬浮输入开启且 r9 胶囊实际可见、收起、竖屏时，文案左栈下移至胶囊上方约 16pt，最多 32pt；有 AWEStoryProgressContainerView 图片分页条时，仅平移其 AWEStoryProgressSlideView 内容与文案同量移动，容器 frame 保持原样；按实际 3pt UICollectionView 分页线约束下移量，线必须留在原 HUD 点击范围内，且距输入至少 4pt，不能覆盖输入。输入框 frame/高度、播放器、右侧按钮、首页与普通视频完全不接管。 私信 AWEAwemeIMDetailTableViewController 明确排除，不能把消息主列表或普通聊天页当成评论回复来源；来源仍校验详情前一张原生导航页面，不按标题或截图文字猜测。沿既有左栈 layout/arrangedSubviews 的嵌套更新前恢复原 transform，保留用户缩放，最外层结束后按实际坐标叠加可恢复平移；离窗、离页、换模型、切视频、关闭悬浮输入及展开键盘时恢复。输入胶囊原生布局结束后只局部同步，不轮询或挂全局 UIView/CALayer；弱引用跟踪状态。DYYYDetailCaptionMetrics 的回归覆盖记录中的坐标、图片分页条边界、已合适间距与关闭路径，导出只记录几何数字，不记录文案。 动图可带有 3pt 高、无子视图/子图层/内容/背景/描边/阴影/遮罩的分页空壳：仅忽略该空壳的测量，不移动或隐藏它；实际未知分页仍保守跳过。时间/IP 纯 UILabel 行以可见文字底边测量，不能把原生行尾空白计作文字；复合行保持原 bounds。 上下切页时按 AWEAwemeDetailCellViewController.view 的整页坐标测量文案和分页线，将实际胶囊的视口位置映射到尺寸一致的页内坐标；不能用带 table 滚动位移的屏幕坐标相减，也不能等覆盖屏幕中央才调整。预加载相邻 Cell 即使被原生隐藏，也要准备其页内最终位置（只忽略页外 Cell 的显隐，页内元素自身的 hidden/alpha 仍遵循原生）。原生 willDisplayCell 和页容器布局结束前同步，交互层布局 begin/end 嵌套期间暂不应用，最外层结束立即提交；只对受管 transform 禁用动画，保留原生整页滑动。分页中的 viewWillDisappear 不提前恢复造成旧位置闪现，实际离开作用域/离窗、切普通视频、关闭功能及展开输入仍恢复；输入与普通视频尺寸保持原样。
- **长按评论隐藏收藏**：`DYYYHideCommentLongPressFavorite` 默认关闭，平铺在隐藏设置的「长按评论」分组。`DYYYCommentMenuItems` 仅在原生评论菜单普通分区的 setModelsArray/replaceByModels 输入中按 elementContent 精确移除收藏、取消收藏、已收藏（含富文本）；不改原模型/动作或收藏状态，不依赖毛玻璃开关，不操作视频右栏收藏按钮。功能项布局前过滤，余项连续排列，关闭后下一次打开恢复原生入口。
- **右下角音乐图标文字**：`DYYYSameStyleVisibility.(h/m)` 隐藏右侧元素栈内 `AWEPlayInteractionSingleSongMusicStyleView` 与 `AWEPlayInteractionStyleOneMusicView`（81ADA564 已确认的“玩同款”另一原生样式，二者均直接继承 UIView）直接子 UILabel 的所有标题，包括拍同款、玩同款及其他音乐入口文案，不再按固定文字匹配；保留组件根视图、AWEMusicCoverButton、缩略图、原生点击遮罩、无障碍动作和尺寸，不能隐藏或移除整个入口。设置名为「隐藏音乐文字」，沿用独立开关 `DYYYHideSameStyleButton` 与原有取值、默认关闭，平铺在视频播放界面的隐藏音乐按钮下方。原生模型/标题更新前恢复、结束后重新应用，布局仅补同步；关闭/复用/离窗恢复标题原始 hidden，不处理视频文案和其他元素的标题，不改点击功能。隐藏标题时同时将 playInteractionCircleMaskView/playInteractionMaskView/playInteractionColorMaskView 的 CALayer.mask 可恢复地替换为透明绘制遮罩，去掉遗留半圆底板；不改 UIView.hidden/alpha/命中及图层 opacity，不处理 AWEMusicCoverButton 内的封面绘制；原生更新前及关闭/离窗恢复装饰层原 mask。两个音乐类分别按类可用状态安装一次模型/标题/装饰/布局与挂窗钩子，共用显隐及装饰恢复管线；不能只放宽辅助类判定却漏装另一类钩子，也不能假定二者为继承关系。
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
- GitHub Actions 使用 `macos-26-intel` 及 iOS 26+ SDK 构建，Theos 缓存按 `runner.os` 与 `runner.arch` 隔离。40356512045 曾因 ARM64 容量不足无法分配 Runner，但不能退到旧 SDK：1.9.0 使用 macos-15-intel 时实际 SDK 不支持玻璃底栏，6016F657 的 floatingTabBar 已确认走了编译期空实现。CI 开始先校验 Xcode 的 iOS SDK；Makefile 在官方构建定义 DYYY_REQUIRE_GLASS_TAB_BAR，DYYYGlassTabBar.xm 对实际编译 SDK 低于 26 直接报错；发布上传前还检查 arm64e dylib 的 DKGlassTabBarProxy 类符号。不能只用打包成功或 Foundation 回归通过来证明玻璃功能已编入，禁止通过删除 SDK 保护、强写版本宏或改变用户开关掩盖 SDK 缺失。
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
