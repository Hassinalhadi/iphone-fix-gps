TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = hsrider

hsrider_FILES = Tweak.x
hsrider_CFLAGS = -fobjc-arc
hsrider_FRAMEWORKS = CoreLocation Foundation UIKit
hsrider_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
