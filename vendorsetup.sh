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
clone_if_missing "https://github.com/ai94iq/android_device_xiaomi_sm8250-common" "axv-qpr2" "device/xiaomi/sm8250-common"
clone_if_missing "https://github.com/ai94iq/android_kernel_xiaomi_sm8250" "axksu" "kernel/xiaomi/sm8250"
clone_if_missing "https://github.com/ai94iq/proprietary_vendor_xiaomi_sm8250-common" "axv-qpr2" "vendor/xiaomi/sm8250-common"
clone_if_missing "https://github.com/ai94iq/proprietary_vendor_xiaomi_pipa" "axv-qpr2" "vendor/xiaomi/pipa"

# Additional LineageOS repositories
clone_if_missing "https://github.com/LineageOS/android_hardware_xiaomi" "lineage-22.2" "hardware/xiaomi"
clone_if_missing "https://github.com/LineageOS/android_hardware_lineage_compat" "lineage-22.2" "hardware/lineage/compat"
clone_if_missing "https://github.com/LineageOS/android_hardware_lineage_interfaces" "lineage-22.2" "hardware/lineage/interfaces"
clone_if_missing "https://github.com/LineageOS/android_hardware_lineage_livedisplay" "lineage-22.2" "hardware/lineage/livedisplay"

# Additional 3rd-Party repositories
 clone_if_missing "https://github.com/ai94iq/android_packages_apps_XiaomiDolby" "lineage-22.2" "packages/apps/XiaomiDolby"

# Function for applying patches with enhanced handling
apply_atomic_recovery_patch() {
    local root_dir=$(pwd)
    local target_dir="bootable/recovery"
    local patch_path="${root_dir}/device/xiaomi/pipa/source-patches/atomic-recovery.diff"
    
    echo "==== Applying atomic-recovery patch ===="
    
    # Check if patch file exists
    if [ ! -f "$patch_path" ]; then
        echo "Error: atomic-recovery.diff patch file not found"
        echo "Please check if the file exists at: ${patch_path}"
        return 1
    fi
    
    # Create a temporary copy of the patch file with Unix line endings
    local temp_patch=$(mktemp)
    echo "Normalizing patch line endings..."
    tr -d '\r' < "$patch_path" > "$temp_patch"
    
    # Enter target directory
    echo "Navigating to ${target_dir}..."
    if ! cd "$target_dir"; then
        echo "Error: Could not change to $target_dir directory"
        rm "$temp_patch"
        return 1
    fi
    
    echo "Applying atomic-recovery patch..."
    
    # Save the current state
    local current_state=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || git rev-parse HEAD)
    
    # Try applying with git am first
    echo "Trying git am with --3way option..."
    if git am --3way "$temp_patch" 2>/dev/null; then
        echo "✓ Patch applied successfully using git am"
        rm "$temp_patch"
        cd "$root_dir"
        return 0
    fi
    git am --abort 2>/dev/null || true
    
    # Try git apply
    echo "Trying git apply with ignore-whitespace..."
    if git apply --check --ignore-whitespace "$temp_patch" 2>/dev/null && 
       git apply --ignore-whitespace "$temp_patch"; then
        echo "✓ Patch applied successfully using git apply"
        git add .
        git commit -m "Applied atomic-recovery patch"
        rm "$temp_patch"
        cd "$root_dir"
        return 0
    fi
    
    # Try patch command with various strip levels
    echo "Trying patch utility with various strip levels..."
    for level in 1 0 2 3; do
        if patch -p${level} --ignore-whitespace --no-backup-if-mismatch < "$temp_patch" 2>/dev/null; then
            echo "✓ Patch applied successfully using patch -p${level}"
            git add .
            git commit -m "Applied atomic-recovery patch"
            rm "$temp_patch"
            cd "$root_dir"
            return 0
        fi
    done
    
    # Try partial application
    echo "Attempting partial patch application..."
    patch -p1 --forward --verbose --ignore-whitespace --no-backup-if-mismatch < "$temp_patch" || true
    
    # Check if any changes were made
    if git diff --name-only | grep -q .; then
        echo "✓ Partial application of atomic-recovery patch succeeded"
        git add .
        git commit -m "Applied atomic-recovery patch (partial)"
        rm "$temp_patch"
        cd "$root_dir"
        return 0
    fi
    
    echo "✗ Failed to apply atomic-recovery patch after all attempts"
    
    # Cleanup
    git reset --hard HEAD 2>/dev/null || true
    rm "$temp_patch"
    cd "$root_dir"
    return 1
}

# Main script execution starts here
ROOT_DIR=$(pwd)
DEVICE_PATH="${ROOT_DIR}/device/xiaomi/pipa"

# Check if the device repository exists
if [ ! -d "$DEVICE_PATH" ]; then
    echo "Error: Device directory not found at ${DEVICE_PATH}"
    echo "Please ensure all repositories are properly cloned"
    exit 1
fi

# Create the patches directory if it doesn't exist
PATCHES_DIR="${DEVICE_PATH}/source-patches"
mkdir -p "$PATCHES_DIR"

# Apply patches one by one, ensuring we return to ROOT_DIR between each
echo "==== Starting patch application process ===="

# Apply atomic-recovery patch
apply_atomic_recovery_patch

# Make sure we're in the root directory
cd "$ROOT_DIR"

echo "==== Patch application complete ===="