TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CleanRider
CleanRider_FILES = Tweak.x
CleanRider_FRAMEWORKS = UIKit CoreLocation MapKit
CleanRider_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
