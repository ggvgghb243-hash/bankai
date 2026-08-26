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
    MCMFilzaIntegration.m \
    sandbox_escape.m \
    apfs_own.m \
    kexploit/kexploit_opa334.m \
    kexploit/krw.m \
    kexploit/kutils.m \
    kexploit/offsets.m \
    kexploit/vnode.m \
    utils/file.c \
    utils/hexdump.c \
    utils/process.c \
    kpf/patchfinder.m \
    XPF/src/xpf.c \
    XPF/src/common.c \
    XPF/src/decompress.c \
    XPF/src/bad_recovery.c \
    XPF/src/non_ppl.c \
    XPF/src/ppl.c \
    XPF/external/ChOma/src/arm64.c \
    XPF/external/ChOma/src/Base64.c \
    XPF/external/ChOma/src/BufferedStream.c \
    XPF/external/ChOma/src/CodeDirectory.c \
    XPF/external/ChOma/src/CSBlob.c \
    XPF/external/ChOma/src/DER.c \
    XPF/external/ChOma/src/DyldSharedCache.c \
    XPF/external/ChOma/src/Entitlements.c \
    XPF/external/ChOma/src/Fat.c \
    XPF/external/ChOma/src/FileStream.c \
    XPF/external/ChOma/src/Host.c \
    XPF/external/ChOma/src/MachO.c \
    XPF/external/ChOma/src/MachOLoadCommand.c \
    XPF/external/ChOma/src/MemoryStream.c \
    XPF/external/ChOma/src/PatchFinder.c \
    XPF/external/ChOma/src/PatchFinder_arm64.c \
    XPF/external/ChOma/src/Util.c

ZEXInjector_CFLAGS = \
    -I$(THEOS_PROJECT_DIR) \
    -I$(THEOS_PROJECT_DIR)/XPF/src \
    -I$(THEOS_PROJECT_DIR)/XPF/external/ChOma/include \
    -fobjc-arc \
    -Wno-everything

ZEXInjector_FRAMEWORKS = UIKit Foundation CoreFoundation Security QuartzCore AVFoundation AudioToolbox IOKit
ZEXInjector_PRIVATE_FRAMEWORKS = IOSurface
ZEXInjector_LIBRARIES  = z sandbox

include $(THEOS_MAKE_PATH)/application.mk
