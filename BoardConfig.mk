#
# Copyright (C) 2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from sm8250-common
include device/xiaomi/sm8250-common/BoardConfigCommon.mk

DEVICE_PATH := device/xiaomi/pipa

BUILD_BROKEN_DUP_RULES := true

# Display
TARGET_SCREEN_DENSITY := 400

# DTB
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := device/xiaomi/pipa/prebuilts/
BOARD_PREBUILT_DTBOIMAGE := device/xiaomi/pipa/prebuilts/dtbo.img
BOARD_USES_DT := true

# Kernel and module handling
TARGET_PREBUILT_KERNEL := device/xiaomi/pipa/prebuilts/Image

BOARD_BUILD_VENDOR_RAMDISK_IMAGE := true
KERNEL_MODULE_DIR := device/xiaomi/pipa/prebuilts
KERNEL_MODULES := $(wildcard $(KERNEL_MODULE_DIR)/*.ko)

# Properties
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Sepolicy
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Inherit from the proprietary version
include vendor/xiaomi/pipa/BoardConfigVendor.mk
