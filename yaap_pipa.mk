#
# Copyright (C) 2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit some common yaap stuff.
$(call inherit-product, vendor/yaap/config/common_full_tablet_wifionly.mk)

# Inherit from pipa device
$(call inherit-product, device/xiaomi/pipa/device.mk)

# Inherit keys
$(call inherit-product, vendor/lineage-priv/keys/keys.mk)

# Boot animation
scr_resolution := 1080
TARGET_SCREEN_HEIGHT := 2880
TARGET_SCREEN_WIDTH := 1800

# Exclude QCOM powerhal manifest
TARGET_PROVIDES_POWERHAL := true

# Gapps
TARGET_BUILD_GAPPS := true

# Product
PRODUCT_NAME := yaap_pipa
PRODUCT_DEVICE := pipa
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := Pad 6

# Extra Device Flags
PRODUCT_CHARACTERISTICS := nosdcard,tablet
TARGET_SUPPORTS_QUICK_TAP := false
PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildFingerprint=Xiaomi/pipa_global/pipa:13/RKQ1.211001.001/V816.0.7.0.UMZMIXM:user/release-keys
