TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Xianyu

# rootless (Dopamine / palera1n rootless)
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = XianyuMon
XianyuMon_FILES = Tweak.xm XYMonitor.xm
XianyuMon_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/Headers
XianyuMon_FRAMEWORKS = Foundation UIKit UserNotifications
XianyuMon_PRIVATE_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Xianyu || true"
