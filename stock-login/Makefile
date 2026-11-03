# ApolloAuthShim - credentials-only build for running stock Apollo in the
# simulator. Built against the simulator SDK with the internal Logos generator
# (ObjC-runtime swizzling, no CydiaSubstrate) so it can be DYLD_INSERTed into
# the platform-patched stock app.
#
# Build with install.sh, or directly:
#   make TARGET="simulator:clang:latest:15.0" ARCHS=arm64 \
#        TARGET_CODESIGN_FLAGS="--sign -" LOGOS_DEFAULT_GENERATOR=internal

TARGET = simulator:clang:latest:15.0
ARCHS = arm64
LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ApolloAuthShim
ApolloAuthShim_FILES = ApolloAuthShim.xm
ApolloAuthShim_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ApolloAuthShim_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
