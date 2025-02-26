#!/bin/bash

# Function to clone if directory doesn't exist
clone_if_missing() {
    local repo_url=$1
    local branch=$2
    local target_dir=$3
    
    if [ ! -d "$target_dir" ]; then
        echo "Cloning $repo_url to $target_dir"
        git clone "$repo_url" -b "$branch" "$target_dir"
    else
        echo "$target_dir already exists, skipping clone"
    fi
}

# Git clones
clone_if_missing "https://github.com/ai94iq/android_device_xiaomi_sm8250-common" "lmov" "device/xiaomi/sm8250-common"
clone_if_missing "https://github.com/ai94iq/android_kernel_xiaomi_sm8250" "axksu" "kernel/xiaomi/sm8250"
clone_if_missing "https://github.com/ai94iq/proprietary_vendor_xiaomi_sm8250-common" "vic" "vendor/xiaomi/sm8250-common"
clone_if_missing "https://github.com/ai94iq/proprietary_vendor_xiaomi_pipa" "vic" "vendor/xiaomi/pipa"
clone_if_missing "https://github.com/LineageOS/android_hardware_xiaomi" "lineage-22.1" "hardware/xiaomi"
clone_if_missing "https://github.com/TogoFire/packages_apps_ViPER4AndroidFX" "v4a" "packages/apps/ViPER4AndroidFX"

# Apply atomic-recovery patch
(
    # Store the root directory and device paths
    ROOT_DIR="$(pwd)"
    DEVICE_PATH="${ROOT_DIR}/device/xiaomi/pipa"
    PATCH_PATH="${DEVICE_PATH}/atomic-recovery.diff"

    # Check if patch file exists
    if [ ! -f "$PATCH_PATH" ]; then
        echo "Error: Patch file not found at ${PATCH_PATH}"
        exit 1
    fi

    # Enter recovery directory
    cd bootable/recovery || {
        echo "Error: Could not change to bootable/recovery directory"
        exit 1
    }

    echo "Applying atomic-recovery patch from ${PATCH_PATH}..."
    if git am "${PATCH_PATH}"; then
        echo "Patch applied successfully"
    else
        echo "Patch failed to apply, cleaning up..."
        git am --abort
        exit 1
    fi

    # Return to original directory
    cd "${ROOT_DIR}" || echo "Warning: Failed to return to original directory"
)
