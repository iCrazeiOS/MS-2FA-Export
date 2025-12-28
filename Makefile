SDKVERSION = 14.4

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MS-2FA-Export

MS-2FA-Export_FILES = Tweak.x
MS-2FA-Export_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall 'Microsoft Authenticator'"
