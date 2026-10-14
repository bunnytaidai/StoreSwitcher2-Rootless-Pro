include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = StoreSwitcher

ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:12.0

StoreSwitcher_FILES = SSBasePrefsController.m SSPrefsRootListController.m SSContainersListController.m SSContainerDetailController.m SSInjectedAppsController.m SSAutoRunnerController.m SSPacketReplayerController.m SSSubscriptionModalController.m SSTestFlightManagerController.m ../SSContainerManager.m SSTerminalConsole.m
StoreSwitcher_FRAMEWORKS = UIKit CoreGraphics StoreKit Security
StoreSwitcher_PRIVATE_FRAMEWORKS = Preferences
StoreSwitcher_INSTALL_PATH = /Library/PreferenceBundles
StoreSwitcher_CFLAGS = -fobjc-arc -fno-modules -I../ -Wno-unguarded-availability-new -Wno-error -fno-threadsafe-statics
StoreSwitcher_LDFLAGS = -lc++

include $(THEOS_MAKE_PATH)/bundle.mk
