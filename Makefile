TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomRider
CustomRider_FILES = Tweak.x
CustomRider_FRAMEWORKS = UIKit CoreLocation MapKit

include $(THEOS_MAKE_PATH)/tweak.mk
