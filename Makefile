THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET := iphone:clang:15.6:14.0
INSTALL_TARGET_PROCESSES = SpringBoard AppStore
THEOS_PACKAGE_DIR = dist
THEOS_STAGING_DIR = /tmp/ss2_stage

ADDITIONAL_CFLAGS = -fno-modules -Wno-error -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
ADDITIONAL_LDFLAGS = -lc++
_THEOS_DARWIN_CAN_USE_MODULES = 0
MODULESFLAGS =

include $(THEOS)/makefiles/common.mk

# =========================================================
# 1. TWEAK CORE & GUI: StoreSwitcher
# =========================================================
TWEAK_NAME = StoreSwitcher AppAgent

StoreSwitcher_FILES = Tweak.x \
                      SSViewController.m \
                      SSTableViewCell.m \
                      SSContainerManager.m \
                      AppAgentClient.m \
                      AppAgentDashboardController.m

StoreSwitcher_CFLAGS = -fobjc-arc -fno-modules
StoreSwitcher_FRAMEWORKS = UIKit Foundation CoreGraphics Security
StoreSwitcher_PRIVATE_FRAMEWORKS = Preferences StoreServices

# =========================================================
# 2. DYLIB AGENT TIÊM VÀO APP: AppAgent
# =========================================================
AppAgent_FILES = AppAgent/AppAgent.m \
                 AppAgent/AgentPacket.m \
                 AppAgent/AgentPacketManager.m \
                 AppAgent/StoreKitHook.m \
                 AppAgent/URLSchemeHook.m \
                 AppAgent/NetworkPacketHook.m \
                 AppAgent/RuntimeInspector.m \
                 AppAgent/UIInspector.m \
                 AppAgent/AgentIPCServer.m \
                 AppAgent/AgentBeacon.m

AppAgent_CFLAGS = -fobjc-arc -fno-modules
AppAgent_FRAMEWORKS = UIKit Foundation CoreGraphics StoreKit

include $(THEOS_MAKE_PATH)/tweak.mk

# =========================================================
# 3. TOOL DÒNG LỆNH TERMINAL: agentcli
# =========================================================
TOOL_NAME = agentcli
agentcli_FILES = cli/main.m
agentcli_FRAMEWORKS = Foundation
agentcli_CFLAGS = -fobjc-arc -fno-modules
agentcli_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk

SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 AppStore SpringBoard Preferences || true"
