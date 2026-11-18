#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 The TWRP Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a73

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := universal9611
TARGET_NO_BOOTLOADER := true

# Platform
TARGET_BOARD_PLATFORM := $(PRODUCT_PLATFORM)

# Kernel (prebuilt, taken unchanged from the official android-9.0 m30s tree)
TARGET_KERNEL_ARCH := $(TARGET_ARCH)
BOARD_KERNEL_IMAGE_NAME := Image
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image

# DTBO
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# Ramdisk (the prebuilt kernel has CONFIG_RD_LZMA=y)
LZMA_RAMDISK_TARGETS := recovery,boot
BOARD_RAMDISK_USE_LZMA := true

# Kernel command line
BOARD_KERNEL_CMDLINE := \
    androidboot.hardware=exynos9611 \
    androidboot.selinux=permissive

# Platform version = what the INSTALLED FIRMWARE reports.
#
# The bootloader hands the OS version and patch level from this image's header
# to the secure world, and keymaster compares them with the values stored in
# every key:
#   same               the key is used as it is
#   recovery is older  keymaster refuses the key (decryption fails, nothing changes)
#   recovery is newer  keymaster asks for a key upgrade. TWRP keeps upgraded keys
#                      in RAM only, but whether Samsung's keymaster then still
#                      accepts the old key is not known. Avoid this case.
# So the default below is older than any Android 11 firmware of the M30s: a build
# with the default cannot decrypt, and cannot do harm. Set the two values to
#   getprop ro.build.version.release          (11)
#   getprop ro.build.version.security_patch   (for example 2021-10-01)
# of the phone. The GitHub workflow has inputs for them.
M30S_OS_VERSION := 11.0.0
M30S_SECURITY_PATCH := 2021-01-01

PLATFORM_VERSION := 11
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := $(M30S_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Boot image header (same values as the official android-9.0 m30s tree)
BOARD_MKBOOTIMG_ARGS := \
    --base 0x10000000 \
    --kernel_offset 0x00008000 \
    --pagesize 2048 \
    --ramdisk_offset 0x01000000 \
    --os_version $(M30S_OS_VERSION) \
    --os_patch_level $(M30S_SECURITY_PATCH) \
    --tags_offset 0x00000100 \
    --header_version 1 \
    --board SRPSE30A002RU

# Partitions
# NOTE: these sizes are the A50's (same chip family). The real M30s sizes are
# not confirmed yet. The build only uses them as an upper limit.
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 57671680
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_DTBIMG_PARTITION_SIZE := 8388608
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67633152

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Root
BOARD_ROOT_EXTRA_FOLDERS := \
    efs

# Partitions - System, ODM, Product, Vendor
BOARD_SYSTEM_PARTITION_LIST := system odm product vendor
BOARD_PARTITION_LIST := $(call to-upper, $(BOARD_SYSTEM_PARTITION_LIST))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := ext4))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))

# Android Verified Boot
BOARD_AVB_ENABLE := false

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := ABGR_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
RECOVERY_SDCARD_ON_DATA := true
TARGET_USES_MKE2FS := true

# TWRP
TW_THEME := portrait_hdpi
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 153
TW_Y_OFFSET := 80
TW_H_OFFSET := -80
TW_NO_REBOOT_BOOTLOADER := true
TW_HAS_DOWNLOAD_MODE := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_EXTRA_LANGUAGES := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXCLUDE_TWRPAPP := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_REPACKTOOLS := true

# Decryption (file based encryption, policy v1, "ice" contents mode)
# The keymaster / gatekeeper HALs are copied from the vendor partition at boot,
# see recovery/root/system/bin/m30s_tee.sh.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_USE_FSCRYPT_POLICY := 1

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
