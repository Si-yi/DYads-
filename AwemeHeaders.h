#import <Photos/Photos.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT void DYYYNSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

#ifndef DYYY_KEEP_SYSTEM_NSLOG
#ifdef NSLog
#undef NSLog
#endif
#define NSLog(...) DYYYNSLog(__VA_ARGS__)
#endif

// 获取指定类型设置
#define DYYYGetBool(key) [[NSUserDefaults standardUserDefaults] boolForKey:key]
#define DYYYGetFloat(key) [[NSUserDefaults standardUserDefaults] floatForKey:key]
#define DYYYGetInteger(key) [[NSUserDefaults standardUserDefaults] integerForKey:key]
#define DYYYGetString(key) [[NSUserDefaults standardUserDefaults] stringForKey:key]
#define DYYY_IGNORE_GLOBAL_ALPHA_TAG 114514

typedef NS_ENUM(NSInteger, MediaType) { MediaTypeVideo, MediaTypeImage, MediaTypeAudio, MediaTypeHeic };

// 调节模式&全局状态
typedef NS_ENUM(NSUInteger, DYEdgeMode) {
    DYEdgeModeNone = 0,
    DYEdgeModeBrightness = 1,
    DYEdgeModeVolume = 2,
};

@interface UIView (DYYYGlobalAlpha)
- (void)dyyy_applyGlobalTransparency;
@end

// 音量控制
@interface AVSystemController : NSObject
+ (instancetype)sharedAVSystemController;
- (BOOL)setVolumeTo:(float)value forCategory:(NSString *)cat;
- (float)volumeForCategory:(NSString *)cat;
@end
// 亮度控制
@interface SBHUDController : NSObject
+ (instancetype)sharedInstance;
- (void)presentHUDWithIcon:(NSString *)name level:(float)level;
@end

@interface URLModel : NSObject
@property(nonatomic, strong) NSArray *originURLList;
@end

@interface DUXToast : NSObject
+ (void)showText:(NSString *)text;
@end

@interface AWEURLModel : NSObject
@property(nonatomic, copy) NSArray *originURLList;
@property(nonatomic, assign) NSInteger imageWidth;
@property(nonatomic, assign) NSInteger imageHeight;
@property(nonatomic, copy) NSString *URLKey;
- (NSArray *)originURLList;
- (id)URI;
- (NSURL *)getDYYYSrcURLDownload;
@end

@interface AWEVideoModel : NSObject
@property(nonatomic, strong) AWEURLModel *playLowBitURL;
@property(retain, nonatomic) AWEURLModel *playURL;
@property(copy, nonatomic) NSArray *manualBitrateModels;
@property(copy, nonatomic) NSArray *bitrateModels;
@property(copy, nonatomic) NSArray *bitrateRawData;
@property(nonatomic, strong) URLModel *h264URL;
@property(nonatomic, strong) URLModel *coverURL;
@property(nonatomic, assign) BOOL hasFilterHDR;
@property(nonatomic, assign) NSInteger isSourceHDR;
@end

@interface AWEMusicModel : NSObject
@property(nonatomic, strong) URLModel *playURL;
@end

@interface AWEImageAlbumImageModel : NSObject
@property(nonatomic, strong) NSArray *urlList;
@property(retain, nonatomic) AWEVideoModel *clipVideo;
@end

@interface AWEAwemeStatisticsModel : NSObject
@property(nonatomic, strong) NSNumber *diggCount;
@end

@interface AWESearchAwemeExtraModel : NSObject
@end

@interface AWEAwemeTextExtraModel : NSObject
@property(nonatomic, copy) NSString *hashtagName;
@property(nonatomic, copy) NSString *hashtagId;
@property(nonatomic, copy) NSString *type;
@property(nonatomic, assign) NSRange textRange;
@property(nonatomic, copy) NSString *awemeId;
@property(nonatomic, copy) NSString *userID;
@property(nonatomic, copy) NSString *userUniqueId;
@property(nonatomic, copy) NSString *secUid;
@end

@interface AWEUserModel : NSObject
@property(copy, nonatomic) NSString *nickname;
@property(copy, nonatomic) NSString *alias; // 当前账户给好友设置的备注
@property(copy, nonatomic) NSString *shortID;
@property(copy, nonatomic) NSString *signature;
@property(copy, nonatomic) AWEURLModel *avatarMedium;
@end

@interface AWEAnimatedImageVideoInfo : NSObject
@end

@interface AWEPropGuideV2Model : NSObject
@property(nonatomic, copy) NSString *propName;
@end

@interface AWEECommerceLabel : NSObject
@end

@interface AWELiveFollowFeedCellModel : NSObject
@end

@interface AWEMusicCardModel : NSObject
@end

@interface AWEAwemeModel : NSObject
@property(nonatomic, strong, readwrite) NSNumber *createTime;
@property(nonatomic, strong, readwrite) NSNumber *recommendShareRate; // 推荐视频专有属性 
@property(nonatomic, assign, readwrite) CGFloat videoDuration;
@property(nonatomic, strong) AWEVideoModel *video;
@property(nonatomic, strong) AWEMusicModel *music;
@property(nonatomic, strong) NSArray<AWEImageAlbumImageModel *> *albumImages;
@property(nonatomic, assign) NSInteger currentImageIndex;
@property(nonatomic, assign) NSInteger awemeType;
@property(nonatomic, strong) NSString *cityCode;
@property(nonatomic, strong) NSString *ipAttribution;
@property(nonatomic, strong) id currentAweme;
@property(nonatomic, copy) NSString *descriptionString;
@property(nonatomic, copy) NSString *globalVisionTitle;
@property(nonatomic, assign) BOOL isAds;
@property(nonatomic, assign) BOOL isLive;
@property(nonatomic, assign) BOOL isLivePhoto;
@property(nonatomic, assign) BOOL isNewTextMode;  // 文字图文专有属性
@property(nonatomic, strong) NSString *shareURL;
@property(nonatomic, strong) id hotSpotLynxCardModel;
@property(nonatomic, strong) AWELiveFollowFeedCellModel *cellRoom;
@property(nonatomic, strong) NSString *videoFeedTag;
@property(nonatomic, strong) id shareRecExtra;  // 收藏/喜欢以外的视频专有属性
@property(nonatomic, copy) NSString *referString; // 推荐页为 homepage_hot
- (BOOL)dyyy_shouldExcludeFromGlobalHDRFilter;
- (BOOL)dyyy_containsHDRMetadataInObject:(id)object depth:(NSUInteger)depth;
@property(nonatomic, strong) NSArray<AWEAwemeTextExtraModel *> *textExtras;
@property(nonatomic, copy) NSString *itemTitle;
@property(nonatomic, copy) NSString *descriptionSimpleString;
@property(nonatomic, strong) NSString *itemID;
@property(nonatomic, strong) AWEUserModel *author;
@property(nonatomic, strong) AWEAnimatedImageVideoInfo *animatedImageVideoInfo;
@property(nonatomic, strong) AWEAwemeStatisticsModel *statistics;
@property(nonatomic, strong) AWEPropGuideV2Model *propGuideV2;
@property(nonatomic, strong) AWEECommerceLabel *ecommerceBelowLabel;
@property(nonatomic, strong) AWEMusicCardModel *musicCard;
@property(nonatomic, assign) BOOL isShowLandscapeEntryView;
- (BOOL)isLive;
- (BOOL)contentFilter;
- (BOOL)checkIsAd;
- (BOOL)isHardAdModel;
- (BOOL)isHardAd;
- (BOOL)awe_enableHDR;
- (id)awe_HDRValueFor:(long long)value enableHDR:(BOOL)enableHDR;
- (AWESearchAwemeExtraModel *)searchExtraModel;
@end

@interface AWEHotListDataController : NSObject
- (void)updateAwemeList:(id)array;
- (id)_refreshDataSourceWithArray:(id)array cleanRefresh:(BOOL)clean requestId:(id)requestID;
- (NSNumber *)dyyy_numberValueForLowLikesFilter:(id)rawValue;
- (NSNumber *)dyyy_resolvedDiggCountForAweme:(AWEAwemeModel *)aweme;
@end

@interface AWEListDataController : NSObject
@property(nonatomic, strong) NSMutableArray *dataSource;
@property(nonatomic, strong) NSMutableArray *filteredDataSource;
- (void)calculateFilteredDataSource;
@end

@interface AWEMixVideoListDataController : AWEListDataController
@end

@interface AWEMixVideoDetailPlayListDataController : AWEListDataController
@end

@interface AWEMixVideoRelatedListDataController : AWEMixVideoListDataController
@end

@interface AWEFeedCommentConfigModel : NSObject
- (void)setCommentInputConfigText:(NSString *)text;
@end
@interface AWEAwemeStatusModel : NSObject
- (void)setListenVideoStatus:(NSInteger)status;
@end

@interface AWEABTestManager : NSObject
@property(retain, nonatomic) NSMutableDictionary *consistentABTestDic;
@property(copy, nonatomic) NSDictionary *abTestData;
@property(copy, nonatomic) NSDictionary *performanceReversalDic;
@property(nonatomic) BOOL performanceReversalEnabled;
@property(nonatomic) BOOL handledNetFirstBackNotification;
@property(nonatomic) BOOL lastUpdateByIncrement;
@property(nonatomic) BOOL shouldPrintLog;
@property(nonatomic) BOOL localABSettingEnabled;
- (void)fetchConfiguration:(id)arg1;
- (void)fetchConfigurationWithRetry:(BOOL)arg1 completion:(id)arg2;
- (void)incrementalUpdateData:(id)arg1 unchangedKeyList:(id)arg2;
- (void)overrideABTestData:(id)arg1 needCleanCache:(BOOL)arg2;
- (void)setAbTestData:(id)arg1;
- (void)_saveABTestData:(id)arg1;
- (id)getValueOfConsistentABTestWithKey:(id)arg1;
+ (id)sharedManager;
@end

@interface AWELongPressPanelBaseViewModel : NSObject
@property(nonatomic, copy) NSString *describeString;
@property(nonatomic, assign) NSInteger enterMethod;
@property(nonatomic, assign) NSInteger actionType;
@property(nonatomic, assign) BOOL showIfNeed;
@property(nonatomic, copy) NSString *duxIconName;
@property(nonatomic, copy) void (^action)(void);
@property(nonatomic) BOOL isModern;
@property(nonatomic, strong) AWEAwemeModel *awemeModel;
- (void)setDuxIconName:(NSString *)iconName;
- (void)setDescribeString:(NSString *)descString;
- (void)setAction:(void (^)(void))action;
@end

@interface AWEPlayVideoViewController : UIViewController
@property(nonatomic, strong) AWEAwemeModel *model;
- (BOOL)enableHDR;
- (void)setEnableHDR:(BOOL)enableHDR;
- (BOOL)awe_isCurrentVideoHDR;
- (void)setPlayerLutFilter:(id)lutFilter HDRLutImage:(id)HDRLutImage;
@end

@interface AWELongPressPanelViewGroupModel : NSObject
@property(nonatomic) unsigned long long groupType;
@property(nonatomic) NSArray *groupArr;
@property(nonatomic) long long numberOfRowsInSection;
@property(nonatomic) long long cellHeight;
@property(nonatomic) BOOL hasMore;
@property(nonatomic) BOOL isModern;
@property(nonatomic) BOOL isDYYYCustomGroup;
@end

@interface AWELongPressPanelManager : NSObject
+ (instancetype)shareInstance;
- (void)dismissWithAnimation:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)shouldShowMordenLongPressPanel;
- (BOOL)showShareFriends;
@end

@interface AWENormalModeTabBarGeneralButton : UIButton
@property(nonatomic) NSInteger status;
@end

@interface AWEHPTopTabItemBadgeContentView : UIView
@end

@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEProgressLoadingView : UIView
- (id)initWithType:(NSInteger)arg1 title:(NSString *)arg2;
- (id)initWithType:(NSInteger)arg1 title:(NSString *)arg2 progressTextFont:(UIFont *)arg3 progressCircleWidth:(NSNumber *)arg4;
- (void)dismissWithAnimated:(BOOL)arg1;
- (void)dismissAnimated:(BOOL)arg1;
- (void)showOnView:(id)arg1 animated:(BOOL)arg2;
- (void)showOnView:(id)arg1 animated:(BOOL)arg2 afterDelay:(CGFloat)arg3;
@end

@interface AWENormalModeTabBarBadgeContainerView : UIView

@end

@interface AWEFeedContainerContentView : UIView
@end

@interface TTMetalView : UIView
@end

@interface AWELeftSideBarEntranceView : UIView
- (void)setNumericalRedDot:(id)numericalRedDot;
- (void)setRedDot:(id)redDot;
@end

@interface AWEDanmakuContentLabel : UILabel
@property(nonatomic, assign) long long type;
@property(nonatomic, copy) NSString *danmakuText;
@property(nonatomic, copy) NSArray *danmakuStyleList;
@property(nonatomic, strong) UIColor *strokeColor;
@property(nonatomic, assign) double strokeWidth;
- (id)colorFromHexString:(id)arg0 baseColor:(id)arg1;
- (void)setTextColor:(id)arg0;
- (id)initWithFrame:(id)arg0 textColor:(id)arg1 type:(long long)arg2;
- (id)danmakuText;
- (void)setDanmakuText:(id)arg0;
- (id)danmakuStyleList;
- (void)drawUnderLineWithStart:(long long)arg0 len:(long long)arg1;
- (void)setDanmakuStyleList:(id)arg0;
- (double)strokeWidth;
- (id)accessibilityLabel;
- (void)setStrokeWidth:(double)arg0;
- (void)setAccessibilityLabel:(id)arg0;
- (void)setStrokeColor:(id)arg0;
- (id)strokeColor;
- (long long)type;
- (id)initWithFrame:(id)arg0;
- (id)boundingRectForCharacterRange:(id)arg0;
- (void)drawTextInRect:(id)arg0;
- (void)setType:(long long)arg0;
@end

@interface XIGDanmakuPlayerView : UIView
@end
@interface DDanmakuPlayerView : UIView
@end

@interface AWEDanmakuItemTextInfo : NSObject
@property(nonatomic, strong) NSAttributedString *danmakuText;
@property(nonatomic, assign) id danmakuTextFrame;
@property(nonatomic, assign) double strokeWidth;
@property(nonatomic, strong) UIColor *strokeColor;
@property(nonatomic, strong) UIFont *danmakuFont;
@property(nonatomic, strong) UIColor *danmakuTextColor;
- (id)colorFromHexStringForTextInfo:(id)arg0;
- (void)setDanmakuFont:(id)arg0;
- (id)danmakuFont;
- (id)danmakuText;
- (void)setDanmakuText:(id)arg0;
- (id)danmakuTextFrame;
- (void)setDanmakuTextFrame:(id)arg0;
- (id)danmakuTextColor;
- (void)setDanmakuTextColor:(id)arg0;
- (double)strokeWidth;
- (void)setStrokeWidth:(double)arg0;
- (void)setStrokeColor:(id)arg0;
- (id)strokeColor;
@end

@interface AWELandscapeFeedEntryView : UIView
@end

@interface AWEIMFeedVideoQuickReplayInputViewController : UIViewController
@end

@interface AWEHPSearchBubbleEntranceView : UIView
@end
@interface AWEFeedLiveTabTopSelectionView : UIView
- (void)setHideTimer:(id)timer;
@end

@interface AWEPlayInteractionViewController : UIViewController
@property(nonatomic, strong) UIView *view;
@property(nonatomic, strong) AWEAwemeModel *model;
@property(nonatomic, strong) NSString *referString;
@property(nonatomic, assign) BOOL isCommentVCShowing;
- (id)controllerByProtocol:(Protocol *)protocol;
- (id)videoDelegate;
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
- (void)showDislikeOnVideo;
- (void)onVideoPlayerViewDoubleClicked:(id)arg1;
- (void)speedButtonTapped:(id)sender;
- (void)buttonTouchDown:(id)sender;
- (void)buttonTouchUp:(id)sender;
@end

@interface HTSLiveRoomStatsMessage : NSObject
- (NSInteger)displayValue;
@end

@interface AWEFeedVideoButton : UIButton
@end

@interface AWEMusicCoverButton : UIButton
@end

@interface AWEPlayInteractionSingleSongMusicStyleView : UIView
- (void)setAwemeModel:(id)model;
- (void)updatePlayInteractionTitle:(id)title;
- (void)updatePlayInteractionDecorationHidden:(BOOL)hidden;
- (void)updatePlayInteractionLayout:(double)layout;
@end

@interface AWEAwemePlayVideoViewController : UIViewController
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context;
- (void)setVideoControllerPlaybackRate:(double)arg0;

@end

@interface AWECommentMiniEmoticonPanelView : UIView

@end

@interface AWEBaseElementView : UIView
@end

@interface AWESearchEntranceView : UIView

@end

@interface AWETextViewInternal : UITextView

@end

@interface AWECommentPublishGuidanceView : UIView

@end

@interface AWEPlayInteractionFollowPromptView : UIView
@end

@interface AWENormalModeTabBarTextView : UIView

@end

@interface AWEFamiliarNavView : UIView
@end

@interface AWEPlayInteractionNewBaseController : UIView
@property(retain, nonatomic) AWEAwemeModel *model;
@end

@interface AWEPlayInteractionProgressController : AWEPlayInteractionNewBaseController
@property(retain, nonatomic) id progressSlider;
- (NSString *)formatTimeFromSeconds:(CGFloat)seconds;
- (NSString *)convertSecondsToTimeString:(NSInteger)totalSeconds;
@end

@interface AWEDProgressCoreContainer : NSObject
@property(retain, nonatomic) id progressSlider;
@end

@interface AWEAdAvatarView : UIView
@end

@interface AWETabBarSkinContainerView : UIView
@end

@interface AWETabBarElementContainerView : UIView
@end

@interface AWENormalModeTabBar : UIView
@property(nonatomic, assign, readonly) UITabBarController *yy_viewController;
@property(retain, nonatomic) AWETabBarSkinContainerView *skinContainerView;
- (void)initializeOriginalTabBarHeight;
@end

@interface AWEPlayInteractionListenFeedView : UIView

@end

@interface AWEFeedLiveMarkView : UIView

@end

@interface AWEPlayInteractionTimestampElement : UIView
@property(nonatomic, strong) AWEAwemeModel *model;
@end

// 39.5.0 完整导出的原生 Cell 控制器，负责图文/视频等内容的准备与播放。
@interface AWEFeedCellViewController : UIViewController
@property (nonatomic, strong) AWEAwemeModel *model;
- (void)prepareForDisplay;
- (void)play;
- (void)didDisplay;
@end

// 39.5 完整导出：实际 UITableViewCell 持有显示内容的控制器。
@interface AWEFeedViewCell : UITableViewCell
@property (nonatomic, strong) AWEFeedCellViewController *viewController;
@end

@interface AWEFeedTableViewController : UIViewController
// 39.5.0 完整导出确认的原生选中与播放入口。
- (void)reloadWithCurrentIndex:(long long)index;
- (void)reloadTableViewData;
- (id)getCurrentCellVC;
- (id)dataSourceModelForIndexPath:(NSIndexPath *)indexPath;
- (void)playVideoOnScrollDidEnd;
- (void)playIfActive;
- (BOOL)currentVCIsActive;
- (BOOL)isPlaying;
- (void)videoPlayer:(id)player didSingleClick:(id)event;
- (void)videoPlayer:(id)player updatePlayTime:(double)time totalTime:(double)total;
@property (nonatomic, readonly) long long currentIndex;
@property (nonatomic, readonly) long long currentPlayIndex;
- (void)awe_refreshForceRequestWithoutAnimation;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)pi_scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)pi_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;
- (void)videoControllerWillStartNextLoop:(id)controller;
@property (nonatomic, strong) id dataController;
@property (nonatomic, readonly, strong) id currentAweme;
- (void)insertVideosToFeedWithAwemeIDs:(id)identifiers extraInfo:(id)info;
- (void)insertAwemeModel:(id)model atIndex:(long long)index shouldForceReload:(BOOL)reload byBiz:(long long)biz;
- (void)scrollToRowAtIndexPath:(id)indexPath atScrollPosition:(long long)position animated:(BOOL)animated;
@end

@interface AWEFeedTableView : UIView
@end

@interface AWEAwemeDetailTableView : UITableView
@end

@interface AWECommentContainerViewController : UIViewController
@end

@interface AWECommentInputViewController : UIViewController
@end

@interface AWEAwemeDetailTableViewCell : UIView
@end

@interface IESLiveFeedDrawerEntranceView : UIView
@end

@interface AWEPlayInteractionProgressContainerView : UIView
@end

@interface AFDFastSpeedView : UIView
@end

@interface AWEAwemeOfflineBottomView : UIView
@end

@interface AWEUserWorkCollectionViewComponentCell : UICollectionViewCell
@end

@interface AWELandscapeFeedViewController : UIViewController
@property(nonatomic, strong) UICollectionView *collectionView;
@end

@interface AWEFeedRefreshFooter : UIView
@end

@interface AWERLSegmentView : UIView
@end

@interface AWEBaseListViewController : UIViewController
- (void)applyBlurEffectIfNeeded;
- (UILabel *)findCommentLabel:(UIView *)view;
@end

// 隐藏同城定位
@interface AWEMarkView : UIView
@property(nonatomic, readonly) UILabel *markLabel;
@end

@interface AWEPlayInteractionSearchAnchorView : UIView
@end

@interface AWETemplateHotspotView : UIView
@end

@interface AWEAwemeMusicInfoView : UIView
@end

@interface AWETemplatePlayletView : UIView
@end

@interface AFDRecommendToFriendTagView : UIView
@end

// 39.5.0 运行时导出为 UIView，文字由内部 UILabel 承载。
@interface AFDRecommendToFriendEntranceLabel : UIView
- (void)configWithModel:(id)model;
- (void)updateBGImageViewWithModel:(id)model;
- (void)updateLabelColorWithModel:(id)model;
- (void)updateTextWithModel:(id)model;
@end

@interface AWEStoryContainerCollectionView : UIView
@end

@interface AWELiveNewPreStreamViewController : UIViewController
@end

@interface CommentInputContainerView : UIView
@end

@interface DYYYCommentInputMiddleContainer : UIView
@end

@interface AWELongPressPanelTableViewController : UIViewController
@property(nonatomic, strong) AWEAwemeModel *awemeModel;
@end

@interface AWEModernLongPressPanelTableViewController : UIViewController
@property(nonatomic, strong) AWEAwemeModel *awemeModel;
@end

@interface AWEModernLongPressHorizontalSettingCell : UITableViewCell
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) NSArray *dataArray;
@property(nonatomic, strong) AWELongPressPanelViewGroupModel *longPressViewGroupModel;
@end

@interface AWEModernLongPressHorizontalSettingItemCell : UICollectionViewCell
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, strong) UIImageView *buttonIcon;
@property(nonatomic, strong) UILabel *buttonLabel;
@property(nonatomic, strong) UIView *separator;
@property(nonatomic, strong) AWELongPressPanelBaseViewModel *longPressPanelVM;

- (void)updateUI:(AWELongPressPanelBaseViewModel *)viewModel;
@end

@interface AWEModernLongPressInteractiveCell : UITableViewCell
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) AWELongPressPanelViewGroupModel *longPressViewGroupModel;
@property(nonatomic, strong) NSArray *dataArray;
@property(nonatomic, assign) BOOL isAppearing;
@end

@interface AWEElementStackView : UIView
@property(nonatomic, copy) NSString *accessibilityLabel;
@property(nonatomic, assign) CGRect frame;
@property(nonatomic, strong) NSArray *subviews;
@property(nonatomic, assign) CGAffineTransform transform;
@end

@interface IESLiveStackView : UIView
@property(nonatomic, assign) CGRect frame;
@property(nonatomic, assign) CGAffineTransform transform;
@property(nonatomic, assign) CGFloat alpha;
@property(nonatomic, strong) UIView *superview;
@property(nonatomic, strong) NSArray *subviews;
@property(nonatomic, copy) NSString *accessibilityLabel;
@end

// 评论区实况照片模型
@interface AWECommentLivePhotoModel : NSObject
@property(nonatomic, copy) NSArray *videoUrl;
@end

@interface AWECommentImageModel : NSObject
@property(nonatomic, strong) AWEURLModel *originUrl;
@property(nonatomic, strong) AWEURLModel *mediumUrl;
@property(nonatomic, strong) AWECommentLivePhotoModel *livePhotoModel;
@end

@class AWECommentModel;
@class AWECommentLongPressPanelParam;
@class AWEIMStickerModel;
@class AWEURLModel;
@class AWECommentAudioModel;

@interface AWECommentLongPressPanelContext : NSObject
- (AWECommentModel *)selectdComment;
- (AWECommentLongPressPanelParam *)params;
@end

@interface AWECommentLongPressPanelParam : NSObject
- (AWECommentModel *)selectdComment;
- (NSDictionary *)extraParams;
@end

@interface AWECommentAudioModel : NSObject
@property (nonatomic, copy, readwrite) NSString *content;
@end

@interface AWECommentModel : NSObject
@property (nonatomic, strong, readwrite) AWECommentAudioModel *audioModel;
@property (nonatomic, strong, readwrite) AWEUserModel *author;
@property (nonatomic, strong, readwrite) NSNumber *createTime;
- (AWEIMStickerModel *)sticker;
- (NSString *)content;
- (NSArray<AWECommentImageModel *> *)imageList;
@end

@interface AWEIMStickerModel : NSObject
- (AWEURLModel *)staticURLModel;
@end

@interface _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end

@interface _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end

@interface _TtC21AWEIncentiveSwiftImpl29IncentivePendantContainerView : UIView
@end

@interface AWECommentLongPressPanelSwiftImpl_CommentLongPressPanelReportElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
- (BOOL)elementShouldShow;
- (id)elementContent;
- (id)elementImage;
@end

@interface AWEFeedProgressSlider : UIView
@property(nonatomic, assign) float maximumValue;
@property(nonatomic, strong) UIView *leftLabelUI;
@property(nonatomic, strong) UIView *rightLabelUI;
@property(nonatomic) AWEPlayInteractionProgressController *progressSliderDelegate;
- (void)applyWidthPercentToSubviews:(CGFloat)widthPercent;
@end

@interface AWEFeedChannelObject : NSObject
@property(nonatomic, copy) NSString *channelID;
@property(nonatomic, copy) NSString *channelTitle;
@end

@interface AWEFeedChannelManager : NSObject
- (AWEFeedChannelObject *)getChannelWithChannelID:(NSString *)channelID;
@end

@interface AWEHPTopTabItemModel : NSObject
@property(nonatomic, copy) NSString *channelID;
@property(nonatomic, copy) NSString *channelTitle;
@property(nonatomic, copy) NSString *title;
@end

@interface AWEPlayInteractionStrongifyShareContentView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEAntiAddictedNoticeBarView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEFeedAnchorContainerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEIMMessageTabOptPushBannerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEIMMessageTabSideBarView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@end

@interface AWEECommerceEntryView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWETemplateTagsCommonView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AFDSkylightCellBubble : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface LOTAnimationView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWENearbySkyLightCapsuleView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEPlayInteractionCoCreatorNewInfoView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AFDCancelMuteAwemeView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEPlayDanmakuInputContainView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEPlayInteractionRelatedVideoView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEFeedRelatedSearchTipView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWEProfileMixItemCollectionViewCell : UICollectionViewCell
@end

@interface AWEProfileTaskCardStyleListCollectionViewCell : UIView
@end

@interface AWEProfileUserDetailComponent : NSObject
- (void)reportUserDetailVisitIfNeeded:(id)user;
@end

// AWEVersionUpdateManager相关接口声明
@interface AWEVersionUpdateManager : NSObject
@property(nonatomic, strong) id networkModule;
@property(nonatomic, strong) id badgeModule;
@property(nonatomic, strong) id workflow;
- (NSString *)currentVersion;
- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2;
- (void)workflowDidFinish:(id)arg1;
+ (id)sharedInstance;
@end

@interface AWEVersionUpdateNetworkModule : NSObject
@end

@interface AWEVersionUpdateBadgeModule : NSObject
@end

@interface AWEVersionUpdateWorkflow : NSObject
@end

@interface AWEStoryProgressSlideView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

// 隐藏好友分享私信
@interface AFDNewFastReplyView
@property(nonatomic, weak) UIView *superview;
@property(nonatomic) BOOL hidden;
@end

@interface AWENewLiveSkylightViewController : UIViewController
- (void)showSkylight:(BOOL)arg0 animated:(BOOL)arg1 actionMethod:(unsigned long long)arg2;
- (void)updateIsSkylightShowing:(BOOL)arg0;
@end

@interface AWENearbyFullScreenViewModel : NSObject
- (void)setShowSkyLight:(id)arg1;
- (void)setHaveSkyLight:(id)arg1;
@end

@interface AWECorrelationItemTag : UIView
- (void)layoutSubviews;
@end

@interface AWEPlayInteractionTemplateButtonGroup : UIView
- (void)layoutSubviews;
@end

@interface AWEHPDiscoverFeedEntranceView : UIView
- (void)configImage:(UIImageView *)imageView Label:(UILabel *)label position:(NSInteger)pos;
@end

@interface AWEIMCellLiveStatusContainerView : UIView
- (void)p_initUI;
@end

@interface AWELiveFeedLabelTagView : UIView
@end

@interface AWEPlayInteractionLiveExtendGuideView : UIView
@end

@interface AWEIMFansGroupTopDynamicDomainTemplateView : UIView
- (void)layoutSubviews;
@end

@interface AWETemplateCommonView : UIView
- (void)layoutSubviews;
@end

@interface AWEUIAlertView : UIView
- (void)show;
@end

@interface AWETeenModeAlertView : UIView
- (BOOL)show;
@end

@interface AWETeenModeSimpleAlertView : UIView
- (BOOL)show;
@end

@interface AWEVideoTypeTagView : UIView
@end

@interface AWELiveStatusIndicatorView : UIView
@end

@interface AWEIMInputActionBarInteractor : UIView
- (void)p_setupUI;
@end

@interface AWELiveFeedStatusLabel : UILabel
@end

@interface BDXWebView : UIView
@end

@interface IESLiveActivityBannnerView : UIView
@end
@interface AWECommentSearchAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
@end

@interface AWEPOIEntryAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
- (void)p_processModels:(id)models withPOIName:(id)poiName;
@end

@interface AWECommentGuideLunaAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
@end

@interface AWEFeedTopBarContainer : UIView
@end

@interface AWEHPTopBarCTAContainer : UIView
@end

@interface ACCStickerContainerView : UIView
@end

@interface AWEUserActionSheetView : UIView
- (instancetype)init;
- (UIView *)containerView;
- (void)setActions:(NSArray *)actions;
- (void)show;
- (void)applyBlurEffectAndWhiteText;
- (void)setTextColorWhiteRecursivelyInView:(UIView *)view;
@end

@interface AWEUserSheetAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title imgName:(NSString *)imgName handler:(id)handler;
+ (instancetype)actionWithTitle:(NSString *)title style:(NSUInteger)style imgName:(NSString *)imgName handler:(id)handler;
@end

@interface AWEPlayInteractionDescriptionScrollView : UIScrollView
@end

@interface AWEUserNameLabel : UIView
@end

@interface AWEPlayInteractionDescriptionLabel : UILabel
@end
// 关注直播
@interface AWEConcernSkylightCapsuleView : UIView
@end
// 直播发现
@interface AWEFeedLiveTabRevisitControlView : UIView
@end
// 直播 退出清屏、投屏按钮
@interface IESLiveButton : UIView
@end
// 直播右上关闭按钮
@interface IESLiveLayoutPlaceholderView : UIView
@end
// 直播点歌
@interface IESLiveKTVSongIndicatorView : UIView
@end
// 图片滑条
@interface AWEStoryProgressContainerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
- (void)layoutSubviews;
- (void)updateIndicatorWithPageCount:(NSInteger)count;
@end

@interface AWESearchAnchorListModel : NSObject
- (id)init;
@end

@interface AWEPlayInteractionAvatarView : UIView
@property(nonatomic, readonly) NSArray *subviews;
@property(nonatomic, readonly) CGRect frame;
@end

// 直播间流量提醒弹窗
@interface AWELiveFlowAlertView : UIView
@end

// 搜索视频底部评论视图
@interface AWECommentInputBackgroundView : UIView
@end

// 聊天视频底部快速回复视图
@interface AWEIMFeedBottomQuickEmojiInputBar : UIView
@end

@interface DUXBadge : UIView
@end

@interface ACCEditTagStickerView : UIView
@end

@interface AWESearchFeedTagView : UIView
@end

@interface AFDAIbumFolioView : UIView
@end

@interface AWEHPTopBarCTAItemView : UIView
@end

@interface AWEVideoPlayDanmakuContainerView : UIView
@end
@interface AWEDanmakuContainerView : UIView
@end

// 应用内推送容器
@interface AWEInnerNotificationWindow : UIWindow
- (void)setupBlurEffectForNotificationView;
- (void)applyBlurEffectToView:(UIView *)containerView;
- (void)setLabelsColorWhiteInView:(UIView *)view;
- (void)clearBackgroundRecursivelyInView:(UIView *)view;
@end

@interface AWEFakeProgressSliderView : UIView
@end

@protocol IESIMContentSheetVCProtocol
, AWEMRGlobalAlertTrackProtocol;
@interface DUXBasicSheet : UIViewController
@end

@interface AWEBinding : NSObject
@end

@interface AWESettingItemModel : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subTitle;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, assign) NSInteger type;
@property(nonatomic, copy) NSString *iconImageName;
@property(nonatomic, copy) NSString *svgIconImageName;
@property(nonatomic, assign) NSInteger cellType;
@property(nonatomic, assign) NSInteger colorStyle;
@property(nonatomic, assign) BOOL isEnable;
@property(nonatomic, assign) BOOL isSwitchOn;
@property(nonatomic, copy) void (^cellTappedBlock)(void);
@property(nonatomic, copy) void (^switchChangedBlock)(void);
- (void)refreshCell;
@end

@interface AWESettingBaseViewModel : NSObject
@end

@interface AWESettingBaseViewController : UIViewController
@property(nonatomic, strong) UIView *view;
@property(nonatomic, strong) UITableView *tableView;
- (AWESettingBaseViewModel *)viewModel;
@end

@interface AWESettingsViewModel : AWESettingBaseViewModel
@property(nonatomic, assign) NSInteger colorStyle;
@property(nonatomic, strong) NSArray *sectionDataArray;
@property(nonatomic, weak) id controllerDelegate;
@property(nonatomic, strong) NSString *traceEnterFrom;

- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict;
- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict cellTapHandlers:(NSMutableDictionary *)cellTapHandlers;
@end

@interface AWENavigationBar : UIView
@property(nonatomic, strong) UILabel *titleLabel;
@end

@interface AWESettingSectionModel : NSObject
@property(nonatomic, assign) NSInteger type;
@property(nonatomic, assign) CGFloat sectionHeaderHeight;
@property(nonatomic, copy) NSString *sectionHeaderTitle;
@property(nonatomic, copy) NSString *sectionFooterTitle;
@property(nonatomic, assign) BOOL useNewFooterLayout;
@property(nonatomic, strong) NSArray *itemArray;
@property(retain, nonatomic) NSString *identifier;
@property(copy, nonatomic) NSString *title;
- (id)initWithIdentifier:(id)arg1;
- (void)setIsSelect:(BOOL)arg1;
- (BOOL)isSelect;
@end

@interface AWEPrivacySettingActionSheetConfig : NSObject
@property(copy, nonatomic) NSArray *models;
@property(copy, nonatomic) NSString *headerText;
@property(copy, nonatomic) NSString *headerTitleText;
@property(nonatomic) BOOL needHighLight;
@property(nonatomic) BOOL useCardUIStyle;
@property(nonatomic) BOOL fromHalfScreen;
@property(retain, nonatomic) UIImage *headerLabelIcon;
@property(nonatomic) CGFloat sheetWidth;
@property(nonatomic) BOOL adaptIpadFromHalfVC;
@end

@interface AWEPrivacySettingActionSheet : UIView
+ (id)sheetWithConfig:(id)arg1;
@property(copy, nonatomic) id closeBlock;
@end

@interface DUXContentSheet : UIViewController
@property (nonatomic, assign) CGFloat sheetHeight;
@property (nonatomic, assign) CGFloat minimumSheetHeight;
@property (nonatomic, assign) BOOL userDragging;
- (void)updateSheetHeight:(CGFloat)height withMinimumSheetHeight:(CGFloat)minimum animated:(BOOL)animated completion:(id)completion;
- (void)showOnViewController:(id)arg1 completion:(id)arg2;
- (instancetype)initWithRootViewController:(UIViewController *)controller withTopType:(NSInteger)topType withSheetAligment:(NSInteger)alignment;
- (instancetype)initWithRootViewController:(UIViewController *)controller withTopType:(NSInteger)topType withHeight:(CGFloat)height;
- (void)setAutoAlignmentCenter:(BOOL)center;
- (void)setSheetCornerRadius:(CGFloat)radius;
@property(nonatomic, strong) UIColor *contentColor;
@property(retain, nonatomic) UIView *fullScreenView;
@end

// 运行时绑定到 AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSheet。
@interface DYYYCommentLongPressPanelSheet : DUXContentSheet
@end

// 评论长按菜单内层列表在多选状态变更后独立布局。
@interface DYYYCommentMenuCollectionController : UIViewController
@end

// 原生评论菜单普通功能分区：两列排列仍由原生布局和事件分发管理。
@interface DYYYCommentMenuNormalSection : NSObject
@property (nonatomic, readonly, strong) UIViewController *viewController;
- (NSInteger)numberOfItems;
- (CGSize)sizeForItemAtIndex:(NSInteger)index model:(id)model collectionViewSize:(CGSize)size;
- (void)configCell:(id)cell index:(NSInteger)index model:(id)model;
- (CGSize)sizeForFooterWithCollectionViewSize:(CGSize)size;
@end

// 原生菜单渲染 VM；仅合并普通功能分区，保留原始元素对象与好友分区。
@interface DYYYCommentMenuListModel : NSObject
- (void)replaceBySectionViewModels:(NSArray *)sections sync:(BOOL)sync;
@end
@interface DYYYCommentMenuNormalSectionModel : NSObject
- (NSArray *)modelsArray;
- (void)replaceByModels:(NSArray *)models animated:(BOOL)animated sync:(BOOL)sync;
@end
@interface DYYYCommentMenuNativeLayout : UICollectionViewLayout
@end

// 实际 Swift 类从 ShareAdditionTextView 所在映像按语义名解析，避免绑定哈希。
@interface DYYYCommentMenuSendButton : UIButton
@end

// 评论菜单功能行的白色卡片由原生 contentShapeLayer 绘制。
@interface DYYYCommentMenuCardCell : UICollectionViewCell
@end

// 评论菜单的好友横排异步创建、滚动复用后需要重新同步文字颜色。
// 运行时分别绑定 AWEIMShareImpl.ShareContactListTargetCell / ShareContactListRecentShareCell。
@interface DYYYCommentMenuContactCell : UICollectionViewCell
@end

@interface DYYYCommentMenuRecentShareCell : UICollectionViewCell
@end

// 运行时绑定 AWEIMShareImpl.ShareCommentHorizontalSectionController，参考 DYKiller 已适配的选人回调。
@interface DYYYCommentMenuSelectionSection : NSObject
@property (nonatomic, readonly, strong) UIViewController *viewController;
- (UIView *)createAdditionTextAndAppendToViewHierarchyWithShareContactList:(id)list;
- (void)shareContactList:(id)list stateDidChangeFromState:(NSUInteger)fromState toState:(NSUInteger)toState;
@end

// 运行时绑定 AWESearchFeedArticleViewController；仅处理首页文章卡片背景。
@interface DYYYFeedArticleViewController : UIViewController
- (void)lynxEngineDidMount:(id)engine;
- (void)updateModel:(id)model;
- (void)prepareForReuse;
@end

// 分享面板的外壳和实际内容，私有声明集中在此处。
@interface AWESharePanelContainerViewController : UIViewController
@end

// 抖音 39.5.0 调试录制确认使用的分享控制器。
@interface DYYYLegacySharePanelController : UIViewController
@end

@interface AWESharePanelViewController : UIViewController
- (void)awe_themeReload;
@end

@interface AWESharePanelFunctionCell : UICollectionViewCell
@end

@protocol AFDPrivacyHalfScreenViewControllerProtocol <NSObject>
@end

@interface AWEHalfScreenBaseViewController : UIViewController
- (void)setCornerRadius:(CGFloat)radius;
- (void)setOnlyTopCornerClips:(BOOL)onlyTop;
@end

@interface AWELeftSideBarAddChildTransitionObject : NSObject
@end

@interface AWEButton : UIButton
@end

@interface AFDButton : UIButton
@end

@interface AWENoxusHighlightButton : UIButton
@end

@interface AWEProfileToggleView : UIView
@end

@interface DUXAbandonedButton : UIButton
@end

@interface AFDPrivacyHalfScreenViewController : AWEHalfScreenBaseViewController <AFDPrivacyHalfScreenViewControllerProtocol>
@property(retain, nonatomic) UILabel *titleLabel;
@property(retain, nonatomic) UILabel *contentLabel;
@property(retain, nonatomic) UIImageView *imageView;
@property(copy, nonatomic) void (^rightBtnClickedBlock)(void);
@property(copy, nonatomic) void (^leftButtonClickedBlock)(void);
@property(copy, nonatomic) void (^closeButtonClickedBlock)(void);
@property(copy, nonatomic) void (^singleTapBlock)(void);
@property(copy, nonatomic) void (^toggleBlock)(void);
@property(copy, nonatomic) void (^tapDismissBlock)(void);
@property(copy, nonatomic) void (^slideDismissBlock)(void);
@property(copy, nonatomic) void (^afterDismissBlock)(void);
@property(copy, nonatomic) void (^afterDismissWithSwitchChangedBlock)(void);
@property(copy, nonatomic) NSString *knownButtonText;
@property(assign, nonatomic) BOOL shouldShowKnownButton;
@property(assign, nonatomic) UIEdgeInsets lockImageInset;
@property(retain, nonatomic) UIImage *lockImage;
@property(retain, nonatomic) UIImage *closeImage;
@property(retain, nonatomic) AFDButton *cancelButton;
@property(retain, nonatomic) AWEButton *knownButton;
@property(retain, nonatomic) AWEButton *leftCancelButton;
@property(retain, nonatomic) AWEButton *rightConfirmButton;

- (void)configWithCloseButtonClickedBlock:(void (^)(void))closeButtonClickedBlock singleTapBlock:(void (^)(void))singleTapBlock toggleBlock:(void (^)(void))toggleBlock;
- (void)configWithImageView:(UIImageView *)imageView
                  titleText:(NSString *)titleText
                contentText:(NSString *)contentText
               settingsText:(NSString *)settingsText
             singleTapBlock:(void (^)(void))singleTapBlock;
- (void)configWithImageView:(UIImageView *)imageView
                  lockImage:(UIImage *)lockImage
             lockImageInset:(UIEdgeInsets)lockImageInset
             titleLabelText:(NSString *)titleLabelText
           contentLabelText:(NSString *)contentLabelText
            knownButtonText:(NSString *)knownButtonText
            toggleTitleText:(NSString *)toggleTitleText
               defaultState:(BOOL)defaultState
           defaultLockState:(BOOL)defaultLockState;
- (void)configWithImageView:(UIImageView *)imageView
                 closeImage:(UIImage *)closeImage
                  lockImage:(UIImage *)lockImage
             titleLabelText:(NSString *)titleLabelText
           contentLabelText:(NSString *)contentLabelText
            knownButtonText:(NSString *)knownButtonText
            toggleTitleText:(NSString *)toggleTitleText
               defaultState:(BOOL)defaultState
           defaultLockState:(BOOL)defaultLockState;
- (void)configWithImageView:(UIImageView *)imageView
                  lockImage:(UIImage *)lockImage
           defaultLockState:(BOOL)defaultLockState
             titleLabelText:(NSString *)titleText
           contentLabelText:(NSString *)contentText
       leftCancelButtonText:(NSString *)leftButtonText
     rightConfirmButtonText:(NSString *)rightButtonText
       rightBtnClickedBlock:(void (^)(void))rightBtnBlock
     leftButtonClickedBlock:(void (^)(void))leftBtnBlock;

- (void)setCornerRadius:(CGFloat)radius;
- (void)setOnlyTopCornerClips:(BOOL)onlyTop;
- (void)setUseCardUIStyle:(BOOL)arg1;
- (void)setShouldShowToggle:(BOOL)arg1;
- (NSUInteger)animationStyle;
- (NSUInteger)viewStyle;
- (void)cancelButtonTapped;
- (void)settingsTextTapped;
- (void)knownButtonClicked;
- (void)showKnownButton;
- (void)updateDarkModeAppearance;
- (void)presentOnViewController:(UIViewController *)presentingViewController;
@end

@interface AWELoadingAndVolumeView : UIView
@end

@interface BDImageView : UIImageView
@end

@interface AWEIMEmoticonModel : NSObject
- (id)valueForKey:(NSString *)key;
@end

@interface AWEIMEmoticonPreviewV2 : UIView
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) BDImageView *content;
@property(nonatomic, strong) AWEIMEmoticonModel *model;
- (void)dyyy_saveButtonTapped:(id)sender;
@end

// 设置修改顶栏标题
@interface AWEHPTopTabItemTextContentView : UIView
- (void)setContentText:(NSString *)text;
@end

// 直播间商品信息
@interface IESECLivePluginLayoutView : UIView
@end
@interface IESECLiveCardSizeComponent : UIView
@end
@interface IESECLiveGoodsCardView : UIView
@end
// 直播间点赞动画
@interface HTSLiveDiggView : UIView
@end
@interface IESLiveStickerView : UIView
@end
@interface IESLiveGroupLiveComponentView : UIView
@end
@interface IESLivePreAnnouncementPanelViewNew : UIView
@end
@interface IESLiveDynamicUserEnterView : UIView
@end
@interface _TtC18IESLiveRevenueImpl32IESLiveSwiftDynamicUserEnterView : UIView
@end
@interface _TtC18IESLiveRevenueImpl35IESLiveSwiftVideoLayerUserEnterView : UIView
@end
@interface _TtC18IESLiveRevenueImpl34IESLiveDynamicRankListEntranceView : UIView
@end
@interface IESLiveDynamicRankListEntranceView : UIView
@end
@interface IESLiveShortTouchActionView : UIView
@end
@interface PlatformCanvasView : UIView
@end
@interface IESLiveDanmakuVariousView : UIView
@end
@interface IESLiveDanmakuSupremeView : UIView
@end
@interface IESLiveLotteryAnimationViewNew : UIView
@end
@interface IESLiveMatrixEntranceView : UIView
@end
@interface IESLiveConfigurableShortTouchEntranceView : UIView
@end
@interface IESLiveRedEnvelopeAniLynxView : UIView
@end
@interface IESLiveBottomRightCardView : UIView
@end
@interface IESLiveGameCPExplainCardContainerImpl : UIView
@end
@interface AWEPOILivePurchaseAtmosphereView : UIView
@end
@interface IESLiveHotMessageView : UIView
@end
@interface AWEHomePageBubbleLiveHeadLabelContentView : UIView
@end

// 隐藏状态栏
@interface AWEUserDetailViewControllerV2 : UIViewController
@end

@interface AWEFeedRootViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end
@interface AWELiveAudienceContainerController : NSObject
@property(nonatomic, strong) id roomModel;
@property(nonatomic, strong) UIViewController *audienceVC;
- (UIViewController *)audienceViewController;
@end

@interface AWELiveAudienceViewController : NSObject
@property(nonatomic, strong) id roomModel;
@property(nonatomic, strong) UIViewController *audienceViewController;
@end

@interface IESLiveInnerFeedLiveRoomCell : UICollectionViewCell
@property(nonatomic, strong) id itemModel;
@property(nonatomic, strong) id roomAisle;
@property(nonatomic, strong) UIViewController *audienceVC;
@end

@interface IESLiveAudienceViewController : UIViewController
@property(nonatomic, strong) id containerContext;
@property(nonatomic, strong) id roomDI;
@property(nonatomic, strong) id roomConfig;
@property(nonatomic, strong) id roomAisle;
- (BOOL)prefersStatusBarHidden;
@end
@interface AWEAwemeDetailTableViewController : UIViewController
@property(nonatomic, strong) UITableView *tableView;
- (void)setupDetailTableView;
- (double)fixedCellHeight;
- (double)cellHeightAtIndex:(long long)index;
- (double)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (double)contentOffsetYForCellAtIndex:(long long)index;
- (BOOL)prefersStatusBarHidden;
@end
@interface AWEAwemeIMDetailTableViewController : AWEAwemeDetailTableViewController
@end
@interface AWEAwemeDetailCellViewController : UIViewController
@end
@interface AWEAwemeHotSpotTableViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end
@interface AWEFullPageFeedNewContainerViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end
@interface AFDPureModePageContainerViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end

@interface AWEFeedUnfollowFamiliarFollowAndDislikeView : UIView
@end

@interface AWEDPlayerFeedPlayerViewController : UIViewController
@property(nonatomic) UIView *contentView;
- (BOOL)enableHDR;
- (void)setVideoControllerPlaybackRate:(double)arg0;
@end

@interface AWEDPlayerViewController_Merge : UIViewController
@property(nonatomic, strong) AWEAwemeModel *model;
- (void)player:(id)player updatePlayTime:(double)time canPlayTime:(double)buffered totalTime:(double)total;
- (void)playerWillStartNextLoop:(id)player;
@property(nonatomic) UIView *contentView;
- (BOOL)enableHDR;
- (void)setVideoControllerPlaybackRate:(double)arg0;
@end

@interface AWEPlayInteractionElementMaskView : UIView
@end
@interface AWEGradientView : UIView
@end
@interface AWEHotSpotBlurView : UIView
@end
@interface AWEHotSearchInnerBottomView : UIView
@end
// 底部热点提示框
@interface AWENewHotSpotBottomBarView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

// 评论区免费去看短剧
@interface AWEShowPlayletCommentHeaderView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
@end

@interface ACCGestureResponsibleStickerView : UIView
@end

// 评论顶部业务分区，运行时绑定 Swift 实现；仅使用已有高度和布局接口。
@interface DYYYCommentHeaderSectionController : NSObject
@property(nonatomic, copy) void (^didUpdateHeight)(double);
@property(nonatomic, copy) void (^didTopBarUpdate)(BOOL, BOOL);
- (double)currentHeight;
- (void)updateLayout:(BOOL)animated completion:(id)completion;
- (CGSize)sizeForItemAtIndex:(NSInteger)index model:(id)model collectionViewSize:(CGSize)size;
- (void)configCell:(UICollectionViewCell *)cell index:(NSInteger)index model:(id)model;
@end

@interface DYYYCommentHeaderCell : UICollectionViewCell
@end

@interface DYYYCommentHeaderInnerController : UIViewController
- (double)heightForSegmentedControl;
- (double)autoFullScreen_topContainerTotalHeight;
- (double)pinchFullScreen_topContainerTotalHeight;
@end

@interface AWEDemaciaChapterProgressSlider : UIView
@end

@interface AWELiveAutoEnterStyleAView : UIView
@end

@interface IESLiveRoomComponent : NSObject
@end

@interface IESLiveUserSeqlistFragment : NSObject
- (void)refreshVerticalUserCount:(id)arg1 horizontalUserCount:(id)arg2 trueValue:(NSInteger)arg3;
@end

@interface HTSLiveStreamQualityFragment : IESLiveRoomComponent
@property(nonatomic, strong) NSArray *streamQualityArray;
- (NSArray *)getQualities;
- (void)setResolutionWithIndex:(NSInteger)index isManual:(BOOL)manual beginChange:(void (^)(void))beginChangeBlock completion:(void (^)(void))completionBlock;
@end

@interface DUXPopover : UIView
@end

@interface AWESearchViewController : UIViewController
@property(nonatomic, strong) UITabBarController *tabBarController;
- (UIButton *)scanButton;
@end

@interface AWEIMCommentShareUserHorizontalSectionController : UIViewController
- (void)configCell:(id)cell index:(NSInteger)index model:(id)model;
@end

@interface AWEIMCommentShareUserHorizontalCollectionViewCell : UIView
@end

@interface AWENormalModeTabBarFeedView : UIView
@end

@interface AWENormalModeTabBarController : UIViewController
@property(nonatomic, strong) AWENormalModeTabBar *awe_tabBar;
- (void)handleApplicationWillEnterForeground:(NSNotification *)notification;
@end

@interface AWELeftSideBarWeatherLabel : UILabel
@property(nonatomic, assign) BOOL userInteractionEnabled;
@property(nonatomic, strong) UIColor *textColor;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end
@interface AWELeftSideBarWeatherView : UIView
@property(nonatomic, readonly) NSArray<UIView *> *subviews;
- (UITapGestureRecognizer *)tapGestureForDYYY;
- (UITapGestureRecognizer *)tapGestureForSubview:(UIView *)subview;
- (void)openDYYYSettings;
@end

@interface AWEFeedContainerViewController : UIViewController
@end

@interface AWEIMGiphyMessage : NSObject
@property(nonatomic, copy, readwrite) AWEURLModel *giphyURL;
@end

@interface AWEIMMessageComponentContext : NSObject
@property(nonatomic, weak, readwrite) AWEIMGiphyMessage *message;
@end

@interface AWEIMReusableCommonCell : UITableViewCell
@property(nonatomic, weak, readwrite) id currentContext;
@end

@interface AWEIMCustomMenuModel : NSObject
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *imageName;
@property(nonatomic, copy, readwrite) id willPerformMenuActionSelectorBlock;
@property(nonatomic, copy, readwrite) NSString *trackerName;
@property(nonatomic, assign, readwrite) NSUInteger type;
@end

@interface AWEPlayInteractionSpeedController : NSObject
@property(nonatomic, strong) id progressSliderDelegate;
- (id)playVideoViewController;
- (CGFloat)longPressFastSpeedValue;
- (void)changeSpeed:(double)speed;
- (void)handleLongPressLockedDoubleSpeedChanged:(id)arg1 gesture:(UIGestureRecognizer *)gesture;
- (void)handleLongPressLockedSpeedBegan;
- (void)handleLongPressLockedDoubleSpeedEnded:(id)arg1 gesture:(UIGestureRecognizer *)gesture;
- (void)longPressSpeedControlDidChangeSpeed:(double)speed;
@end

@interface AWEPlayInteractionDPlayerSpeedController : NSObject
- (id)playVideoViewController;
@end

@interface AWEPlayInteractionUserAvatarView : UIView
@property(retain, nonatomic) UIView *followPromptView;
@property(retain, nonatomic) UIView *followAnimationView;
@property(retain, nonatomic) UIView *unfollowAnimationView;
@property(retain, nonatomic) UIView *staticFollowAnimationView;
@property(retain, nonatomic) UIView *sendMessageView;
@property(retain, nonatomic) UIView *sendMessageGuideView;
@property(nonatomic, weak) UIImageView *avatarSendMessageImageView;
@property(retain, nonatomic) UIView *enterStoreView;
@property(retain, nonatomic) UIView *enterStoreGuideView;
@property(nonatomic, weak) UIImageView *avatarEnterStoreImageView;
@property(retain, nonatomic) UIView *linkIconContainerView;
@property(retain, nonatomic) UIImageView *userAvatarLinkIcon;
- (void)updateRightContainerElement;
- (void)p_resetFollowAnimation;
- (void)playFollowAnimation:(id)completion;
- (void)playUnFollowAnimation;
- (void)changeSendMessageViewWithFlag:(BOOL)flag;
@end

@interface AWEPlayInteractionStaticFollowAnimationView : UIView
@property(retain, nonatomic) UIImageView *plusImageView;
@property(retain, nonatomic) UIImageView *tickImageView;
@end

@interface AWELeftSideBarViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource>
- (UICollectionView *)collectionView;
- (void)adjustContainerViewLayout:(UICollectionViewCell *)cell;
@end

@interface AWESettingsTableViewController : AWESettingBaseViewController
- (id)viewModel;
@end

@interface AWEProfileMixCollectionView : UICollectionView
@property(nonatomic, assign) BOOL fromHome;
@end

@interface AFDViewedBottomView : UIView
@property(nonatomic, strong, readonly) UIView *effectView;
@end

@interface AWEAwemeDetailNaviBarContainerView : UIView
@end

@interface AWEVideoBSModel : NSObject
@property(nonatomic) NSNumber *bitrate;
@property(nonatomic) AWEURLModel *playAddr;
@end

@interface AWENormalModeTabBarPlusButton : UIView
@end

@interface AWENormalModeTabBarGeneralPlusButton : AWENormalModeTabBarPlusButton
@end

@interface AWEMixVideoPanelMoreView : UIView
@end

@interface AWEPlayInteractionUserAvatarElement : NSObject
@property(retain, nonatomic) AWEAwemeModel *model;
@end

@interface AWEPlayInteractionUserAvatarContext : NSObject
@property(retain, nonatomic) AWEAwemeModel *model;
@property(nonatomic, weak) UIView *elementView;
@property(nonatomic, weak) UIView *avatarPicContainerView;
@property(nonatomic, weak) UIView *avatarPicView;
@property(nonatomic, weak) UIView *avatarPicAvatarButton;
@end

@interface AWEPlayInteractionUserAvatarFollowController : UIViewController
@property(retain, nonatomic) AWEAwemeModel *model;
@end

@interface AWEPlayInteractionUserAvatarFollowPromptController : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
@property(retain, nonatomic) UIView *followPromptView;
@property(retain, nonatomic) UIView *followAddView;
@property(retain, nonatomic) UIView *followAnimationView;
@property(retain, nonatomic) UIView *unfollowAnimationView;
@property(retain, nonatomic) AWEPlayInteractionStaticFollowAnimationView *staticFollowAnimationView;
- (void)onFollowViewClicked:(id)gesture;
- (void)onUnFollowViewClicked:(id)arg1;
- (void)followPromptViewClicked:(id)arg1;
- (void)layoutElementView;
- (void)showFollowAddView:(BOOL)show;
- (BOOL)shouldShowFollowAddWithModel:(id)arg1;
- (BOOL)shouldShowSpecialFollowWithModel:(id)arg1;
- (void)viewController_willDisplay;
- (void)viewController_viewDidAppear;
- (void)updateFollowStatus;
- (void)followStatusChanged:(id)arg1;
- (void)playFollowAnimation;
- (void)playFollowAnimation:(id)completion;
- (void)playUnFollowAnimation;
- (void)_ensureStaticFollowAnimationView;
@end

@interface AWEPlayInteractionUserAvatarMainBusinessController : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
@property(retain, nonatomic) UIView *avatarPicView;
- (void)layoutElementView;
@end

@interface AWEPlayInteractionUserAvatarOptElementElement : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
- (void)layoutElementView;
- (void)viewController_willDisplay;
- (void)viewController_viewDidAppear;
- (void)setAppear:(BOOL)appear;
@end

@interface AWEPlayInteractionUserAvatarStoryController : NSObject
@property(nonatomic, weak) UIView *colorRingView;
- (void)layoutElementView;
- (void)showStory25RingView;
@end

@interface AWEPlayInteractionUserAvatarDecorationController : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
@property(retain, nonatomic) UIImageView *decorationView;
- (void)layoutElementView;
- (void)viewController_willDisplay;
- (void)setDecorationStyle:(long long)style;
@end

@interface AWEPlayInteractionUserAvatarSendMessageController : NSObject
- (id)userAvatarView;
- (void)controllerViewDidLayout;
- (void)controllerStartConfigAvatarView:(id)view;
- (void)controllerWillDisplay;
- (void)controllerPlay;
- (void)controllerReset;
- (void)updateSendMessageView:(BOOL)show;
- (void)p_updateSendMessageView:(BOOL)show;
- (void)p_showSendMessageView:(id)view shouldShowSendMessageView:(BOOL)show animated:(BOOL)animated completion:(id)completion;
- (BOOL)shouldShowSendMessageView;
- (BOOL)shouldShowSendMessageGuideAnimation;
- (void)playSendMessageGuideAnimationIfNeeded;
- (void)onSendMessageViewClicked:(id)arg1;
@end

@interface AWEPlayInteractionUserAvatarSendMsgController : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
@property(retain, nonatomic) UIView *sendMessageView;
@property(retain, nonatomic) UIView *sendMessageGuideView;
@property(retain, nonatomic) UIImageView *avatarSendMessageImageView;
- (void)layoutElementView;
- (void)viewController_willDisplay;
- (void)viewController_viewDidDisappear;
- (void)play;
- (void)reset;
- (void)changeSendMessageViewWithFlag:(BOOL)flag;
- (void)showSendMessageView:(id)view show:(BOOL)show animated:(BOOL)animated completion:(id)completion;
- (void)showSendMessageViewWithAnimation:(BOOL)animated;
- (BOOL)shouldShowSendMessageView:(id)arg1;
- (BOOL)shouldShowSendMessageGuideAnimation;
- (void)updateSendMsgWithFollowShow:(BOOL)show animation:(BOOL)animated;
- (void)handleAvatarFollowStatusChange:(id)arg1;
- (void)playSendMessageGuideAnimationIfNeeded;
- (void)onSendMessageViewClicked:(id)arg1;
@end

@interface AWEPlayInteractionUserAvatarEnterStoreController : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
@property(retain, nonatomic) UIView *enterStoreView;
@property(retain, nonatomic) UIView *enterStoreGuideView;
- (void)layoutElementView;
- (void)viewController_willDisplay;
- (void)viewController_viewDidAppear;
- (void)play;
- (void)reset;
- (void)showEnterStore;
- (void)hideEnterStore;
- (BOOL)shouldShowEnterStoreView;
- (BOOL)shouldShowEnterStoreGuideAnimation;
- (void)playEnterStoreGuideAnimationIfNeeded;
- (void)handleAvatarFollowStatusChange:(id)arg1;
- (void)onEnterStoreViewClicked:(id)arg1;
@end

@interface AWEPlayInteractionUserAvatarAdLinkController : NSObject
@property(retain, nonatomic) AWEPlayInteractionUserAvatarContext *userAvatarContext;
@property(retain, nonatomic) UIView *linkIconContainerView;
@property(retain, nonatomic) UIImageView *userAvatarLinkIcon;
- (void)layoutElementView;
- (void)reset;
- (void)updateCommerceHotSplashLinkIconImageIfNeeded:(id)arg1;
- (void)onLinkIconContainerViewClicked:(id)arg1;
@end

@interface AWECodeGenCommonAnchorBasicInfoModel : UIViewController
@property(copy, nonatomic) NSString *name;
@end

@interface AWEFeedTemplateAnchorView : UIView
@property(retain, nonatomic) AWECodeGenCommonAnchorBasicInfoModel *templateAnchorInfo;
@end

@interface AWEKnowledgeABTestSettings : NSObject
+ (BOOL)enableHDRAutomaticIdentification;
@end

@interface AWEFeedABSettings : NSObject
+ (BOOL)enableHDRBrightnessOpt;
+ (BOOL)enableHDRFullModelAdaptation;
+ (BOOL)hdrAutomaticIdentification;
@end

@interface BDSimPlayerBizConfig : NSObject
- (BOOL)enableHDRBrightnessOpt;
- (BOOL)enableHDRFullModelAdaptation;
- (BOOL)hdrAutomaticIdentification;
@end

@interface AWEBDSimPlayerBizConfig : BDSimPlayerBizConfig
@end

@interface AWEDPlayerVideoDisplayOptState : NSObject
- (BOOL)enableHDR;
- (void)setEnableHDR:(BOOL)enableHDR;
@end

@interface AWEPlayVideoPlayerContext : NSObject
- (BOOL)enableHDR;
- (void)setEnableHDR:(BOOL)enableHDR;
@end

@interface BDSimStreamContext : NSObject
- (BOOL)enableHDR;
- (void)setEnableHDR:(BOOL)enableHDR;
@end

@interface BDSimPlayerHelper : NSObject
+ (id)hdrValueFor:(long long)value enableHDR:(BOOL)enableHDR;
@end

@interface BDSimMediaPlayer : NSObject
- (BOOL)enableHDR;
- (void)setEnableHDR:(BOOL)enableHDR;
- (void)setEnablePlayHDRMode;
- (void)buildHDRConfig:(id)config;
- (id)awe_HDRValueFor:(long long)value enableHDR:(BOOL)enableHDR;
@end

@interface TTVideoEngineOwnPlayer : NSObject
- (BOOL)enableHDR10;
- (void)setEnableHDR10:(BOOL)enableHDR10;
@end

@interface IESLiveAudienceHDRController : NSObject
+ (BOOL)currentHDRStatusForRoomID:(id)roomID;
+ (BOOL)isCurrentRoomSupportHDR:(id)roomID roomModel:(id)roomModel;
+ (BOOL)isFeedCanEnableHDRFeature;
+ (BOOL)isInnerFeedCanEnableHDRFeature;
+ (BOOL)isUserEnableHDR;
+ (BOOL)p_isHDRFeatureEnable;
+ (void)setUserEnableHDR:(BOOL)enableHDR;
+ (BOOL)shouldShowHDRSwitchForRoom:(id)room;
@end

@interface BDImageDecoderFactory : NSObject
+ (BOOL)isHDRImageData:(id)data withHeifDecoderClass:(Class)decoderClass;
@end

@interface BDImageDecoderImageIO : NSObject
- (BOOL)isHDRCGImage:(CGImageRef)image decodedToHDR:(BOOL)decodedToHDR;
- (id)hdrOptionsFor:(id)image decodedToHDR:(BOOL *)decodedToHDR;
@end

@interface BDImageDecoderHeic : NSObject
+ (BOOL)isHDRData:(id)data;
- (BOOL)isHDR;
- (void)setIsHDR:(BOOL)isHDR;
@end

@interface BDImageDecoderBVC2 : NSObject
- (BOOL)isHDR;
- (void)setIsHDR:(BOOL)isHDR;
@end

@interface BDImageDecoderWebP : NSObject
- (BOOL)isHDR;
- (void)setIsHDR:(BOOL)isHDR;
@end

@interface BDImage : UIImage
- (BOOL)isHDR;
- (void)setIsHDR:(BOOL)isHDR;
@end

@class HDRMTImageView;

@interface HDRMTUIImageView : UIImageView
@property(nonatomic, assign) BOOL hdrEnabled;
@property(nonatomic, strong) HDRMTImageView *innerHDRImageView;
- (instancetype)initWithFrame:(CGRect)frame hdrEnabled:(BOOL)hdrEnabled;
@end

@interface HDRMTImageView : UIView
@property(nonatomic, strong) CAMetalLayer *metalLayer;
@end

@interface HDRMTButton : UIButton
@property(nonatomic, strong) HDRMTUIImageView *hdrmtImageView;
- (void)configHDRContent;
@end

@interface AWEVideoPlayerConfiguration : NSObject
+ (void)setHDRBrightnessStrategy:(id)strategy;
+ (double)getHDRBrightnessOffset:(id)configuration brightness:(double)brightness;
@end

@interface AWEFeedABTestServiceObjc : NSObject
+ (BOOL)enableProfilePreloadHDRBrightnessFilter;
@end

@interface AWEDPlayerVideoConfig : NSObject
- (BOOL)enableMetalRenderHDR;
- (void)setEnableMetalRenderHDR:(BOOL)enableMetalRenderHDR;
@end

@interface AWEDPlayerVideoController : NSObject
- (void)configEnableMetalRenderHDRIfNeeded;
- (void)setEnablePlayHDRModeIfNeeded;
@end

@interface AWEDPlayerVideoController_Merge : NSObject
- (void)configEnableMetalRenderHDRIfNeeded;
- (void)setEnablePlayHDRModeIfNeeded;
@end

@interface AWEDPlayerPlayControlContainer : NSObject
- (void)configEnableMetalRenderHDRIfNeeded;
@end

@interface AWEDPlayerNonSimplayerContainer : NSObject
- (void)setEnablePlayHDRMode;
@end

@interface AWEDPlayerSimpleModeContainer : NSObject
- (void)setEnablePlayHDRModeIfNeeded;
@end

@interface AWEDPlayerBrightnessContainer : NSObject
- (BOOL)awe_isCurrentVideoHDR;
@end

@interface AWEVideoPlayerScreenBrightnessManager : NSObject
- (BOOL)isHDRVideo;
- (void)setIsHDRVideo:(BOOL)isHDRVideo;
@end

@interface ALMOwnPlayerWrapper : NSObject
- (void)setLutFilter:(id)lutFilter HDRLutImage:(id)HDRLutImage;
@end

@interface ALMSysPlayerWrapper : NSObject
- (void)setLutFilter:(id)lutFilter HDRLutImage:(id)HDRLutImage;
@end

@interface ALMVideoPlayerConfig : NSObject
+ (void)setPlayerEffectHDRLutImageEnable:(BOOL)enable;
@end

@interface IESVideoPlayerConfig : NSObject
+ (void)setPlayerEffectHDRLutImageEnable:(BOOL)enable;
@end

@interface AWEIMModuleService : NSObject
- (BOOL)im_forceHDRToSDR;
@end

@interface IESIMVideoPlayerWrapper : NSObject
- (void)setupHDREnable:(BOOL)enable;
@end

@interface AWEIMVideoBrowserCollectionViewCell : UICollectionViewCell
- (void)setEnablePlayHDR:(BOOL)enable;
@end

@interface AWEECOMIMAppSettingsService : NSObject
+ (BOOL)enableVideoPreviewSupportHDR;
@end

@interface IESLivePlayerController : NSObject
- (BOOL)isVideoSDR2HDRSupport;
- (void)setEnableVideoSDR2HDR:(BOOL)enable callTrace:(id)callTrace;
- (BOOL)enableCloseSDR2HDR;
@end

@interface AWELivePreStreamPlayer : NSObject
- (void)changeSDR2HDRWithStrategy;
@end

@interface HTSLiveStreamPlayer : NSObject
- (void)setEnableVideoSDR2HDR:(BOOL)enable callTrace:(id)callTrace;
- (void)changeSDR2HDRWithStrategy;
@end

@interface IESLiveStreamPlayerVideoAudioEffectPlugin : NSObject
- (void)setEnableVideoSDR2HDR:(BOOL)enable callTrace:(id)callTrace;
- (void)changeSDR2HDRWithStrategy;
@end

@interface TVLManager : NSObject
- (BOOL)shouldForbidHDR10Render;
- (void)setShouldForbidHDR10Render:(BOOL)shouldForbid;
- (void)setupVideoSDR2HDR:(id)config;
@end

@interface TVLPlayerItemPreferences : NSObject
- (BOOL)forbidSDR2HDRInPreview;
- (void)setForbidSDR2HDRInPreview:(BOOL)forbid;
- (BOOL)enableUseSDR2HDR;
- (void)setEnableUseSDR2HDR:(BOOL)enable;
@end

@interface TVLSettingsManager : NSObject
- (BOOL)enableMetalRenderHDR;
@end

@interface IESFiltersManager : NSObject
- (void)setHDRIndensity:(double)intensity;
@end

@interface AWEFeedPauseVideoRelatedWordView : UIView
@end

@interface AWEFeedPauseRelatedWordComponent : NSObject
@property(nonatomic, strong) AWEFeedPauseVideoRelatedWordView *relatedView;
@property(nonatomic, strong) AWEAwemeModel *currentAweme;
@property(nonatomic, assign) long long pauseContentNum;

@end

@interface YYAnimatedImageView : UIImageView
@end

@interface AWEProfileMentionLabel : UILabel
@property(copy, nonatomic) NSString *text;
@end

@interface MTKView : UIView
@end

@interface AWEConcernCellLastView : UIView
@end

@interface HTSEventForwardingView : UIView
@property(copy, nonatomic) NSString *levelName;
@end

@interface AWEAwemePlayVideoViewController (SpeedControl)
- (void)adjustPlaybackSpeed:(float)speed;
@end

@interface AWEDPlayerFeedPlayerViewController (SpeedControl)
- (void)adjustPlaybackSpeed:(float)speed;
@end

@interface AWEDPlayerViewController_Merge (SpeedControl)
- (void)adjustPlaybackSpeed:(float)speed;
@end

@interface AWELeftSideBarModel : NSObject
@property(nonatomic, copy) NSArray *moduleModels;
@property(nonatomic, retain) NSArray *bottomModuleModels;
- (NSArray *)moduleModels;
- (NSArray *)bottomModuleModels;
- (id)filterModuleItems:(id)moduleModel;
@end

@interface AWELeftSideBarModuleModel : NSObject
@property(nonatomic, copy) NSArray *items;
@property(nonatomic, copy) NSString *moduleID;
@property(nonatomic, copy) NSString *moduleType;
- (NSArray *)items;
- (NSString *)moduleID;
- (NSString *)moduleType;
- (void)setItems:(NSArray *)items;
- (id)copy;
@end

@interface AWELeftSideBarItemModel : NSObject
@property(nonatomic, copy) NSString *businessType;
@property(nonatomic, copy) NSString *businessId;
- (NSString *)businessType;
- (NSString *)businessId;
@end

@interface AWEListKitMagicCollectionView : UICollectionView
@end

@interface TTPlayerView : UIView
@end

// 开屏广告
@interface BDASplashManager : NSObject
- (void)showSplashControllerViewOnKeyWindow:(id)keyWindow model:(id)model;
- (void)splashViewShowFinished;
@end

// 投屏 VPN 检测
@interface BDByteCastUtils : NSObject
+ (BOOL)netVPNStatus;
@end

@interface BDByteCastNetUtilities : NSObject
- (BOOL)getVPNStatus;
@end

@interface BDByteCastMonitorManager : NSObject
- (BOOL)netVPNStatus;
- (void)setNetVPNStatus:(BOOL)netVPNStatus;
@end

@interface BDByteCastEnvInfo : NSObject
- (BOOL)isVPNActive;
- (void)setIsVPNActive:(BOOL)isVPNActive;
@end

@interface BDByteScreenCastContext : NSObject
- (BOOL)isVPNActive;
- (void)setIsVPNActive:(BOOL)isVPNActive;
@end

@interface AWEDPlayerProgressContainerView : UIView
@end

// 精选标签
@interface AWETemplateStaticLabelInfoModel : NSObject
@property (nonatomic, copy) NSArray *containers;
@end

// 好友推荐
@interface AFDFriendRecommendTagView : UIView
- (void)updateWithModel:(id)model;
- (void)updateUI;
- (void)updateDynamicUI;
- (void)updateUIWithAnimation;
- (void)didAppearWithAnimation;
- (void)updateBackgroundColor;
- (void)updateBackgroundImageView;
- (void)updateText;
@end

// 39.5.0 导出确认的昵称上方标签容器与“点击推荐”标签。
@interface AWEPlayInteractionTagsStackView : UIStackView
@end
@interface AWEPlayInteractionGeneralTagView : UIView
@end
@interface AWEPlayInteractionTagsContainerLabelView : UIView
@end

// 头像彩色光圈。保留其手势与外层头像，仅控制其内部绘制视图。
@interface AFDColorRingView : UIView
- (void)updateDisplayConfig:(id)config;
- (void)startAnimationWithType:(NSInteger)type;
- (void)stopAnimation;
- (void)addAttachmentView;
- (void)prepareForReuse;
@end

// 顶栏选中指示线
@interface AWEFeedMultiTabSelectedContainerView : UIView
@end

// 抖音 39.5.0 运行时导出的 IM 接口；DYYY 独立消息服务只使用这些已确认的方法。
@interface HTSServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)serviceClass;
@end

@interface AWEIMContactDataManager : NSObject
+ (instancetype)sharedInstance;
- (id)userManager;
@end

// 39.5 联系人数据库及本地缓存用户的原生备注字段。
@interface AWEIMUser : NSObject
@property(nonatomic, copy) NSString *nickname;
@property(nonatomic, copy) NSString *alias;
@end

@interface AWEIMUserManager : NSObject
+ (instancetype)sharedManager;
- (id)localCachedUserForUserID:(id)userID;
@end

@interface AWEIMUserDBManager : NSObject
- (id)currentDataBaseUid;
- (id)fetchFriendUsersWithLimits:(long long)limit readScene:(long long)scene;
- (id)localContactListWithReadScene:(long long)scene;
@end

@class TIMXOMessage;
@interface TIMXOConversation : NSObject
- (id)sendMessage:(id)model error:(void *)error;
- (id)sendMessage:(id)model isSaveDB:(BOOL)saveDB error:(void *)error;
+ (instancetype)instanceWithRootObject:(id)root identifier:(id)identifier;
@property (nonatomic, readonly) long long ownerID;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, strong) NSDictionary *participantsMap;
@property (nonatomic, readonly) BOOL isCurrentUserAParticipant;
@property (nonatomic, readonly, strong) TIMXOMessage *lastMessage;
@property (nonatomic, readonly) unsigned long long unreadCount;
@property (nonatomic, copy) NSString *firstUnreadMessageID;
@end

@interface TIMXOMessage : NSObject
@property (nonatomic, readonly, strong) NSNumber *serverMessageID;
@property (nonatomic, readonly, strong) NSNumber *orderInConversation;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSDictionary *content;
@property (nonatomic, readonly, copy) NSString *belongingConversationIdentifier;
@property (nonatomic, readonly, strong) NSDate *createdAt;
@property (nonatomic, readonly) long long sender;
@property (nonatomic, readonly) long long messageType;
@end

@interface TIMXOConversationManager : NSObject
- (id)initWithRootObject:(id)root;
- (id)conversationIDFor1to1ChatWithOtherUserID:(long long)userID inbox:(int)inbox;
- (BOOL)conversationExitsInDB:(id)identifier;
- (long long)otherUserIDFor1to1ChatWithConversationID:(id)identifier;
@end

@interface TIMXOMessageManager : NSObject
- (id)earliestMessagesInConversationWithIdentifier:(id)identifier limit:(long long)limit;
- (id)initWithRootObject:(id)root;
- (id)messagesBeforeTime:(double)time inTypes:(id)types limit:(unsigned long long)limit;
- (id)messagesInConversation:(id)conversation excludeMessageTypes:(id)types limit:(unsigned long long)limit;
@end

@interface IESIMSendMessageModel : NSObject
- (instancetype)initWithConversationId:(id)identifier;
@property (nonatomic) long long messageType;
@property (nonatomic, copy) NSDictionary *messageContentDict;
@property (nonatomic, copy) NSString *preferMessageId;
@property (nonatomic) double preferCreateTime;
@end

@interface IESIMMessageSender : NSObject
- (id)sendMessage:(id)model;
- (void)asyncSendMessage:(id)model completion:(id)completion;
- (void)message:(id)message inConversation:(id)conversation didReceiveResponse:(id)response error:(id)error;
- (void)message:(id)message inConversation:(id)conversation didReceiveAsyncResponse:(id)response error:(id)error;
@end




// 好友分享使用抖音视频缓存池；调用前仍以运行时方法签名确认参数。
@interface AWEIMFeedVideoCachePool : NSObject
+ (instancetype)sharedInstance;
- (id)awemeModelForItemId:(NSString *)itemID;
- (id)awemeWithItemId:(NSString *)itemID;
- (void)requestAwemeModelsForItemIds:(NSArray *)itemIDs requestScene:(NSString *)scene results:(void (^)(id))results;
- (void)tryRequestAwemeItemsWithIds:(NSArray *)itemIDs requestScene:(NSString *)scene;
@end


// 搜索页精简：移植 DYKiller 搜索模块使用的抖音原生接口。
@interface AWESearchMiddleNASingleTabModel : NSObject
@property (nonatomic, copy) NSString *tabId;
@property (nonatomic, copy) NSString *tabName;
@end

@interface AWESearchMiddleNATabDataModel : NSObject <NSCopying>
@property (nonatomic, copy) NSArray<AWESearchMiddleNASingleTabModel *> *tabs;
@property (nonatomic, copy) NSString *landingTab;
@end

@interface AWESearchMiddleNATabViewComponent : NSObject
+ (id)filerTabDataModel:(id)viewModel;
@end

@interface BDXLynxKitParams : NSObject
@property (nonatomic, copy) NSString *originURL;
- (NSDictionary *)globalProps;
@end

@interface AWEVoiceSearchManager : NSObject
- (BOOL)isVoiceSearchMiddlePagePosition:(long long)position;
- (BOOL)isVoiceSearchSugPagePosition:(long long)position;
- (BOOL)shouldHiddenWithPagePositionType:(long long)position;
@end

@interface AWESearchRootStateContext : NSObject
- (BOOL)allowShowScanButton;
@end

@interface AWESearchTopBarScanElement : NSObject
- (UIButton *)scanButton;
- (void)hostViewDidLayoutSubviews;
@end

@interface LynxUI : NSObject
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) id context;
- (void)setAccessibilityLabel:(NSString *)label requestReset:(BOOL)reset;
- (void)propsDidUpdate;
- (BOOL)shouldHitTest:(CGPoint)point withEvent:(UIEvent *)event;
@end
