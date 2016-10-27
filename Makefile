THEOS_DEVICE_IP = 192.168.3.6
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MailMarker
MailMarker_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
MailMarker_FRAMEWORKS = UIKit
after-install::
	install.exec "killall -9 MobileMail"
