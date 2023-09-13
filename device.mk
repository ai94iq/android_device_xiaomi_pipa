#
# Copyright (C) 2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# A/B
TARGET_IS_VAB := true

PRODUCT_IS_TABLET := true

# Platform
BOARD_VENDOR := xiaomi
PRODUCT_USES_QCOM_HARDWARE := true
PRODUCT_BOARD_PLATFORM := kona
TARGET_USES_HARDWARE_QCOM_WLAN := true

# Inherit from sm8250-common
$(call inherit-product, device/xiaomi/sm8250-common/kona.mk)

# AAPT
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxxhdpi

# Audio configs
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/audio/,$(TARGET_COPY_OUT_VENDOR)/etc)

# Boot animation
TARGET_SCREEN_HEIGHT := 2880
TARGET_SCREEN_WIDTH := 1800

# Camera
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/camera/camera_cnf.txt:$(TARGET_COPY_OUT_VENDOR)/etc/camera/camera_cnf.txt

PRODUCT_PACKAGES += \
    libpiex_shim

# Kernel
TARGET_KERNEL_VERSION ?= 4.19
TARGET_KERNEL_DIR ?= device/xiaomi/pipa/prebuilts/

PRODUCT_COPY_FILES += \
    $(TARGET_KERNEL_DIR)/Image:kernel

# Keyboard
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/idc/Xiaomi_Keyboard.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Xiaomi_Keyboard.idc

# Keylayout
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/Xiaomi_Smart_Pen_Keyboard.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/Xiaomi_Smart_Pen_Keyboard.kl

# Overlays
DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay \
    $(LOCAL_PATH)/overlay-statix

# Peripheral Manager
PRODUCT_PACKAGES += \
    XiaomiPeripheralManager

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.freeform_window_management.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.freeform_window_management.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

# Rootdir
PRODUCT_PACKAGES += \
    init.device.rc

# Shipping API level
PRODUCT_SHIPPING_API_LEVEL := 30

# RemovePackages
PRODUCT_PACKAGES += \
    RemovePackages

# Two-pane layout
PRODUCT_PACKAGES += \
    androidx.window.extensions

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Inherit from vendor blobs
$(call inherit-product, vendor/xiaomi/pipa/pipa-vendor.mk)
