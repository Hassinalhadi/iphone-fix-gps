TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = CleanRider Rider

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CleanRider

CleanRider_FILES = Tweak.x
CleanRider_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
CleanRider_FRAMEWORKS = UIKit CoreLocation MapKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
