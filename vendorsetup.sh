#!/bin/bash

# Function to clone if directory doesn't exist
clone_if_missing() {
    local repo_url=$1
    local branch=$2
    local target_dir=$3
    
    if [ ! -d "$target_dir" ]; then
        echo "Cloning $target_dir..."
        git clone "$repo_url" -b "$branch" "$target_dir" -q
        echo "Done."
    fi
}

# Git clones
echo "Setting up repositories..."
clone_if_missing "https://github.com/ai94iq/android_device_xiaomi_sm8250-common" "pixelage" "device/xiaomi/sm8250-common"
clone_if_missing "https://github.com/ai94iq/android_kernel_xiaomi_sm8250" "axksu" "kernel/xiaomi/sm8250"
clone_if_missing "https://github.com/ai94iq/proprietary_vendor_xiaomi_sm8250-common" "axv-qpr2" "vendor/xiaomi/sm8250-common"
clone_if_missing "https://github.com/ai94iq/proprietary_vendor_xiaomi_pipa" "axv-qpr2" "vendor/xiaomi/pipa"

# Additional repos
clone_if_missing "https://github.com/LineageOS/android_hardware_xiaomi" "lineage-22.2" "hardware/xiaomi"
clone_if_missing "https://github.com/LineageOS/android_hardware_lineage_compat" "lineage-22.2" "hardware/lineage/compat"
clone_if_missing "https://github.com/LineageOS/android_hardware_lineage_interfaces" "lineage-22.2" "hardware/lineage/interfaces"
clone_if_missing "https://github.com/LineageOS/android_hardware_lineage_livedisplay" "lineage-22.2" "hardware/lineage/livedisplay"
clone_if_missing "https://github.com/ai94iq/android_packages_apps_XiaomiDolby" "lineage-22.2" "packages/apps/XiaomiDolby"

# Apply recovery patch
apply_recovery_patch() {
    local root_dir=$(pwd)
    local target_dir="bootable/recovery"
    local patch_path="${root_dir}/device/xiaomi/pipa/source-patches/atomic-recovery.diff"
    
    echo "Applying recovery patch..."
    
    if [ ! -f "$patch_path" ]; then
        echo "Error: Patch file not found: ${patch_path}"
        return 1
    fi
    
    # Fix line endings and move to target dir
    cd "$target_dir" || return 1
    tr -d '\r' < "$patch_path" > /tmp/atomic-recovery.patch
    
    # Try different patch methods
    if git am --3way /tmp/atomic-recovery.patch 2>/dev/null; then
        echo "Patch applied successfully."
    elif git apply --check --ignore-whitespace /tmp/atomic-recovery.patch 2>/dev/null && 
          git apply --ignore-whitespace /tmp/atomic-recovery.patch; then
        git add .
        git commit -m "Applied recovery patch" -q
        echo "Patch applied successfully."
    else
        # Try standard patch with different strip levels
        for level in 1 0 2; do
            if patch -p${level} --ignore-whitespace --no-backup-if-mismatch < /tmp/atomic-recovery.patch 2>/dev/null; then
                git add .
                git commit -m "Applied recovery patch" -q
                echo "Patch applied successfully."
                rm /tmp/atomic-recovery.patch
                cd "$root_dir"
                return 0
            fi
        done
        
        # Last resort: try partial application
        patch -p1 --forward --ignore-whitespace --no-backup-if-mismatch < /tmp/atomic-recovery.patch >/dev/null 2>&1 || true
        if git diff --name-only | grep -q .; then
            git add .
            git commit -m "Applied recovery patch (partial)" -q
            echo "Patch partially applied."
        else
            echo "Failed to apply patch."
            git reset --hard HEAD >/dev/null 2>&1
        fi
    fi
    
    rm /tmp/atomic-recovery.patch
    cd "$root_dir"
}

# Download and extract firmware
setup_firmware() {
    local root_dir=$(pwd)
    local firmware_url="https://github.com/ai94iq/proprietary_vendor_xiaomi_pipa/releases/download/fw-radio-OS2.0.2.0.UMZMIXM/vendor-pipa-fw-included.zip"
    local target_dir="${root_dir}/vendor/xiaomi"
    local temp_zip="/tmp/pipa_firmware.zip"
    local radio_dir="${target_dir}/pipa/radio"
    
    # Check if firmware already exists
    if [ -d "$radio_dir" ] && [ -f "${radio_dir}/abl.img" ] && [ -f "${radio_dir}/xbl.img" ]; then
        echo "Firmware already present, skipping download."
        return 0
    fi
    
    echo "Downloading firmware..."
    mkdir -p "$target_dir"
    
    curl -sL "$firmware_url" -o "$temp_zip"
    if [ ! -s "$temp_zip" ]; then
        echo "Error: Failed to download firmware"
        return 1
    fi
    
    echo "Extracting firmware..."
    unzip -qo "$temp_zip" -d "$target_dir"
    rm -f "$temp_zip"
    echo "Firmware setup complete."
}

# Main script execution
ROOT_DIR=$(pwd)
DEVICE_PATH="${ROOT_DIR}/device/xiaomi/pipa"

# Check if device directory exists
if [ ! -d "$DEVICE_PATH" ]; then
    echo "Error: Device directory not found. Please ensure repositories are properly cloned."
    exit 1
fi

# Create patches directory
mkdir -p "${DEVICE_PATH}/source-patches"

# Apply patches
apply_recovery_patch
cd "$ROOT_DIR"

# Setup firmware
setup_firmware
cd "$ROOT_DIR"

echo "Setup complete."
