LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := RemovePackages
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_TAGS := optional
LOCAL_OVERRIDES_PACKAGES := \
   CarrierServices \
   Contacts \
   Dialer \
   NfcNci \
   Stk \
   Etar \
   TeleService \
   Jelly \
   Telecom \
   TelephonyProvider \
   com.google.android.dialer.support \
   com.android.phone.common \
   messaging \
   TagGoogle \
   CalculatorGooglePrebuilt \
   CalendarGooglePrebuilt \
   DevicePolicyPrebuilt \
   GoogleContacts \
   LocationHistoryPrebuilt \
   Maps \
   MeetPrebuilt \
   PrebuiltDeskClockGoogle \
   PrebuiltGmail \
   Photos \
   SoundAmplifierPrebuilt \
   SwitchAccessPrebuilt \
   YouTube \
   arcore \
   talkback \
   AndroidAutoStubPrebuilt \
   FilesPrebuilt \
   GoogleDialer \
   HelpRtcPrebuilt \
   PixelSupportPrebuilt \
   PrebuiltBugle \
   RecorderPrebuilt \
   SafetyHubPrebuilt

LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := /dev/null
include $(BUILD_PREBUILT)
