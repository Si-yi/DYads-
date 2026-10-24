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

TWEAK_NAME = DYYY

DYYY_FILES = DYYY.xm DYYYFloatClearButton.xm DYYYFloatSpeedButton.m DYYYSettings.xm DYYYAutoMessageHooks.xm DYYYABTestHook.xm DYYYLongPressPanel.xm DYYYGlassTabBar.xm DYYYProfileClean.xm DYYYPlusIcon.m DKTabBarIcons.m DKTabBarIconDraw.m DKIconCropper.m DYYYSettingsHelper.m DYYYAutoMessage.m DYYYAutoMessagePanel.m DYYYBackupTools.m DYYYDebugInspector.m DKDebugCapture.m DKClassDump.m DKZipWriter.m DYYYImagePickerDelegate.m DYYYBackupPickerDelegate.m DYYYBottomAlertView.m DYYYCustomInputView.m DYYYOptionsSelectionView.m DYYYIconOptionsDialogView.m DYYYAboutDialogView.m DYYYKeywordListView.m DYYYFilterSettingsView.m DYYYConfirmCloseView.m DYYYToast.m DYYYManager.m DYYYUtils.m CityManager.m AWMSafeDispatchTimer.m
DYYY_FILES += DYYYAutoMessageEditor.m DYYYAutoMessageQuietHoursPanel.m
DYYY_FILES += DYYYIMService.m DYYYIMHistoryReader.m
DYYY_FILES += DYYYFriendShareService.m DYYYFriendShareHistory.m DYYYFriendShareDelivery.m
DYYY_FILES += DYYYFriendShareBadgeView.m DYYYChatVideoLayout.m
DYYY_FILES += DYYYCollectionRows.m
DYYY_FILES += DYYYCommentMenuTheme.m DYYYCommentMenuThemeHooks.xm
DYYY_FILES += DYYYDebugAppearance.m
DYYY_FILES += DYYYDebugMenuView.m DYYYCommentMenuPalette.m
DYYY_FILES += DYYYCommentHeaderLayout.m DYYYCommentHeaderLayoutHooks.xm
DYYY_FILES += DYYYSearchClean.m DYYYSearchCleanHooks.xm
DYYY_FILES += DYYYArticleBackdrop.m DYYYArticleBackdropHooks.xm
DYYY_FILES += DYYYPanelBlur.m DYYYPanelBlurHooks.xm
DYYY_FILES += DYYYFeedTagGlass.m DYYYAvatarRing.m DYYYFeedDecorationsHooks.xm
DYYY_CFLAGS = -fobjc-arc -w
DYYY_LDFLAGS = -weak_framework AVFAudio -lz
DYYY_FRAMEWORKS = CoreAudio PhotosUI
CXXFLAGS += -std=c++11
CCFLAGS += -std=c++11
DYYY_LOGOS_DEFAULT_GENERATOR = internal

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
