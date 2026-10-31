#
#  DYYY
#
#  Copyright (c) 2024 huami. All rights reserved.
#  Channel: @huamidev
#  Created on: 2024/10/04
#
# 本地配置文件（可选）
-include Makefile.local

TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

#export THEOS=/Users/huami/theos
#export THEOS_PACKAGE_SCHEME=roothide

# 根据参数选择打包方案
ifeq ($(SCHEME),roothide)
    export THEOS_PACKAGE_SCHEME = roothide
else ifeq ($(SCHEME),rootless)
    export THEOS_PACKAGE_SCHEME = rootless
else
    unexport THEOS_PACKAGE_SCHEME
endif

# 在GitHub Actions中运行时的特殊配置
ifeq ($(GITHUB_ACTIONS),true)
    export INSTALL = 0
    export FINALPACKAGE = 1
endif

export DEBUG = 0
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DYads-

DYads-_FILES = DYYY.xm DYYYFloatClearButton.xm DYYYFloatSpeedButton.m DYYYSettings.xm DYYYAutoMessageHooks.xm DYYYABTestHook.xm DYYYLongPressPanel.xm DYYYGlassTabBar.xm DYYYProfileClean.xm DYYYPlusIcon.m DKTabBarIcons.m DKTabBarIconDraw.m DKIconCropper.m DYYYSettingsHelper.m DYYYAutoMessage.m DYYYAutoMessagePanel.m DYYYBackupTools.m DYYYDebugInspector.m DKDebugCapture.m DKClassDump.m DKZipWriter.m DYYYImagePickerDelegate.m DYYYBackupPickerDelegate.m DYYYBottomAlertView.m DYYYCustomInputView.m DYYYOptionsSelectionView.m DYYYIconOptionsDialogView.m DYYYAboutDialogView.m DYYYKeywordListView.m DYYYFilterSettingsView.m DYYYConfirmCloseView.m DYYYToast.m DYYYManager.m DYYYUtils.m CityManager.m AWMSafeDispatchTimer.m
DYads-_FILES += DYYYUnreadProbe.m DYYYUnreadProbeHooks.xm
DYads-_FILES += DYYYHomeDailyFilter.m DYYYHomeDailyFilterHooks.xm
DYads-_FILES += DYYYAutoMessageEditor.m DYYYAutoMessageQuietHoursPanel.m DYYYAutoMessageBatch.m
DYads-_FILES += DYYYIMService.m DYYYIMSendLedger.m DYYYIMConversationStore.m DYYYIMHistoryReader.m DYYYIMShareParser.m
DYads-_FILES += DYYYFriendShareService.m DYYYFriendShareHistory.m DYYYFriendShareDelivery.m DYYYFriendShareReturnState.m
DYads-_FILES += DYYYFriendShareBadgeView.m DYYYChatVideoLayout.m DYYYDetailCaptionLayout.m DYYYDetailCaptionMetrics.m
DYads-_FILES += DYYYCollectionRows.m
DYads-_FILES += DYYYCommentMenuTheme.m DYYYCommentMenuThemeHooks.xm
DYads-_FILES += DYYYDebugAppearance.m
DYads-_FILES += DYYYDebugMenuView.m DYYYCommentMenuPalette.m DYYYCommentMenuGrid.m DYYYCommentMenuItems.m DYYYCommentMenuMetrics.m DYYYShareComposer.m
DYads-_FILES += DYYYCommentHeaderLayout.m DYYYCommentHeaderLayoutHooks.xm
DYads-_FILES += DYYYSearchClean.m DYYYSearchCleanHooks.xm
DYads-_FILES += DYYYArticleBackdrop.m DYYYArticleBackdropHooks.xm
DYads-_FILES += DYYYPanelBlur.m DYYYPanelBlurHooks.xm
DYads-_FILES += DYYYGroupChatToolbar.m DYYYGroupChatToolbarHooks.xm
DYads-_FILES += DYYYChatChrome.m DYYYChatChromeHooks.xm
DYads-_FILES += DYYYCommentVideoLayout.m DYYYCommentVideoHooks.xm
DYads-_FILES += DYYYChatInputGlass.m DYYYChatInputGlassHooks.xm DYYYChatInputList.m DYYYChatInputMetrics.m
DYads-_FILES += DYYYFeedTagGlass.m DYYYAvatarRing.m DYYYSameStyleVisibility.m DYYYFeedDecorationsHooks.xm
DYads-_CFLAGS = -fobjc-arc -w
ifeq ($(GITHUB_ACTIONS),true)
DYads-_CFLAGS += -DDYYY_REQUIRE_GLASS_TAB_BAR=1
endif
DYads-_LDFLAGS = -weak_framework AVFAudio -lz
DYads-_FRAMEWORKS = CoreAudio PhotosUI
CXXFLAGS += -std=c++11
CCFLAGS += -std=c++11
DYads-_LOGOS_DEFAULT_GENERATOR = internal

export THEOS_STRICT_LOGOS=0
export ERROR_ON_WARNINGS=0
export LOGOS_DEFAULT_GENERATOR=internal

include $(THEOS_MAKE_PATH)/tweak.mk

ifeq ($(shell whoami),huami)
    THEOS_DEVICE_IP = 192.168.31.227
else
    THEOS_DEVICE_IP = 192.168.15.201
endif
THEOS_DEVICE_PORT = 22

# 清理 packages 目录
clean::
	@echo -e "\033[31m==>\033[0m Cleaning packages…"
	@rm -rf .theos packages

# 编译并自动安装
after-package::
	@echo -e "\033[32m==>\033[0m Packaging complete."
	@if [ "$(GITHUB_ACTIONS)" != "true" ] && [ "$(INSTALL)" = "1" ]; then \
        DEB_FILE=$$(ls -t packages/*.deb | head -1); \
        PACKAGE_NAME=$$(basename "$$DEB_FILE" | cut -d'_' -f1); \
        echo -e "\033[34m==>\033[0m Installing $$PACKAGE_NAME to device…"; \
        ssh root@$(THEOS_DEVICE_IP) "rm -rf /tmp/$${PACKAGE_NAME}.deb"; \
        scp "$$DEB_FILE" root@$(THEOS_DEVICE_IP):/tmp/$${PACKAGE_NAME}.deb; \
        ssh root@$(THEOS_DEVICE_IP) "dpkg -i --force-overwrite /tmp/$${PACKAGE_NAME}.deb && rm -f /tmp/$${PACKAGE_NAME}.deb"; \
	else \
        echo -e "\033[33m==>\033[0m Skipping installation (GitHub Actions environment or INSTALL!=1)"; \
	fi
