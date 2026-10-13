THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:15.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StoreSwitcher
$(TWEAK_NAME)_FILES = Tweak.xm SSViewController.m SSTableViewCell.m
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics StoreKit QuartzCore
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = StoreServices iTunesStore AppStoreDaemon
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
$(TWEAK_NAME)_LDFLAGS = -Wl,-segalign,0x4000

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 AppStore"
