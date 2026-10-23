#ifndef DYYYConstants_h
#define DYYYConstants_h

#define DYYY_NAME @"DYads-"
#define DYYY_SETTINGS_NAME @"DYads-设置"

#define DYYY_VERSION @"2.2-9"

// 默认的远程 ABTest 配置地址
#define DYYY_DEFAULT_ABTEST_URL @"https://github.com/Nathalie-Annis/AWEABTestDataPatch/releases/latest/download/ABTestDataPatch_A.json"

// 是否使用远程配置的偏好键
#define DYYY_REMOTE_CONFIG_FLAG_KEY @"DYYYUseRemoteConfig"

// 远程配置状态改变的通知名
#define DYYY_REMOTE_CONFIG_CHANGED_NOTIFICATION @"DYYYRemoteConfigStateChanged"

// 配置应用方式中的远程模式名称
#define DYYY_REMOTE_MODE_STRING @"远程模式：启动时自动检查更新"

#define DYYYGeonamesErrorDomain @"com.dyyy.geonames.api.error"
#define DYYYGeonamesStatusUserInfoKey @"com.dyyy.geonames.api.status"

// 隐藏设置：搜索页（独立于 DYKiller 的配置与运行时实现）
#define DYYY_SEARCH_REMOVE_HISTORY_KEY @"DYYYSearchRemoveHistory"
#define DYYY_SEARCH_REMOVE_GUESS_KEY @"DYYYSearchRemoveGuess"
#define DYYY_SEARCH_REMOVE_ALL_RANKS_KEY @"DYYYSearchRemoveAllRanks"
#define DYYY_SEARCH_RANKS_KEY @"DYYYSearchRanks"
#define DYYY_SEARCH_RANK_CATALOG_KEY @"DYYYSearchRankCatalog"
#define DYYY_SEARCH_RANK_HIDE_PREFIX @"DYYYHideSearchRank."
#define DYYY_SEARCH_REMOVE_RANK_FOOTER_KEY @"DYYYSearchRemoveRankFooter"
#define DYYY_SEARCH_REMOVE_VOICE_KEY @"DYYYSearchRemoveVoice"
#define DYYY_SEARCH_CAMERA_MODE_KEY @"DYYYSearchCameraMode"

#endif

