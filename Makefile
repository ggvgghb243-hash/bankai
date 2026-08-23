TARGET := iphone:clang:17.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ZEXInjector

ZEXInjector_FILES = \
    main.m \
    AppDelegate.m \
    ZEXInjectorVC.m \
    ZEXFileService.m \
    MCMBridge.m \
    MCMFilzaIntegration.m

ZEXInjector_CFLAGS = \
    -I$(THEOS_PROJECT_DIR) \
    -fobjc-arc \
    -Wno-everything

ZEXInjector_FRAMEWORKS = UIKit Foundation CoreFoundation Security QuartzCore AVFoundation AudioToolbox
ZEXInjector_LIBRARIES  = z

include $(THEOS_MAKE_PATH)/application.mk
