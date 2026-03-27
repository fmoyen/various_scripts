#!/bin/bash

################################################################################
# LVM Volume Group Migration Script
# Purpose: Migrate LVM volume group from one physical disk to another
# Author: Bob
# Date: 2026-03-27
# Usage: ./migrate_lvm_vg.sh <source_disk> <target_disk> <vg_name>
################################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command-line arguments
SOURCE_DISK="${1:-}"
TARGET_DISK="${2:-}"
VG_NAME="${3:-}"
LOG_FILE="/var/log/lvm_migration_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Functions
################################################################################

usage() {
    cat << EOF
${BLUE}LVM Volume Group Migration Script${NC}

Usage: $0 <source_disk> <target_disk> <vg_name>

Arguments:
  source_disk    Source physical disk path (e.g., /dev/mapper/mpathb1)
  target_disk    Target physical disk path (e.g., /dev/mapper/mpathd1)
  vg_name        Volume group name to migrate (e.g., datavg)

Example:
  $0 /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg

Description:
  This script migrates an LVM volume group from one physical disk to another
  using online migration (pvmove). The operation is performed without downtime.

Requirements:
  - Root/sudo privileges
  - LVM2 tools installed
  - Sufficient space on target disk
  - Complete backup of all data

EOF
    exit 1
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

check_arguments() {
    if [[ -z "$SOURCE_DISK" || -z "$TARGET_DISK" || -z "$VG_NAME" ]]; then
        echo -e "${RED}Error: Missing required arguments${NC}\n"
        usage
    fi
    
    log "Arguments validated:"
    log "  Source Disk: $SOURCE_DISK"
    log "  Target Disk: $TARGET_DISK"
    log "  Volume Group: $VG_NAME"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if LVM tools are available
    for cmd in pvs vgs lvs pvcreate vgextend pvmove vgreduce pvremove; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found. Please install LVM2 tools."
        fi
    done
    
    log "All required tools are available"
}

verify_disks() {
    log "Verifying disk existence..."
    
    # Check source disk
    if [[ ! -b "$SOURCE_DISK" ]]; then
        error "Source disk $SOURCE_DISK does not exist or is not a block device"
    fi
    log "Source disk $SOURCE_DISK verified"
    
    # Check target disk
    if [[ ! -b "$TARGET_DISK" ]]; then
        error "Target disk $TARGET_DISK does not exist or is not a block device"
    fi
    log "Target disk $TARGET_DISK verified"
}

verify_vg() {
    log "Verifying volume group..."
    
    # Check if VG exists
    if ! vgs "$VG_NAME" &> /dev/null; then
        error "Volume group $VG_NAME does not exist"
    fi
    
    # Check if source disk is part of the VG
    if ! pvs "$SOURCE_DISK" 2>/dev/null | grep -q "$VG_NAME"; then
        error "Source disk $SOURCE_DISK is not part of volume group $VG_NAME"
    fi
    
    log "Volume group $VG_NAME verified"
}

display_current_state() {
    log "Current LVM configuration:"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    echo "Physical Volumes:" | tee -a "$LOG_FILE"
    pvs | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Volume Groups:" | tee -a "$LOG_FILE"
    vgs | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Logical Volumes:" | tee -a "$LOG_FILE"
    lvs | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
}

check_target_disk_status() {
    log "Checking target disk status..."
    
    # Check if target disk is already a PV
    if pvs "$TARGET_DISK" &> /dev/null; then
        warning "Target disk $TARGET_DISK is already initialized as a physical volume"
        
        # Check if it's part of another VG
        local target_vg=$(pvs "$TARGET_DISK" --noheadings -o vg_name 2>/dev/null | tr -d ' ')
        if [[ -n "$target_vg" && "$target_vg" != "$VG_NAME" ]]; then
            error "Target disk is part of another volume group: $target_vg"
        fi
        
        if [[ "$target_vg" == "$VG_NAME" ]]; then
            log "Target disk is already part of $VG_NAME"
            return 0
        fi
    fi
    
    return 1
}

check_space() {
    log "Checking available space..."
    
    # Get source disk size
    local source_size=$(pvs "$SOURCE_DISK" --noheadings --units g -o pv_size | tr -d ' ' | sed 's/g//')
    local source_used=$(pvs "$SOURCE_DISK" --noheadings --units g -o pv_used | tr -d ' ' | sed 's/g//')
    
    # Get target disk size
    local target_size=$(blockdev --getsize64 "$TARGET_DISK" | awk '{print $1/1024/1024/1024}')
    
    log "Source disk size: ${source_size}G (Used: ${source_used}G)"
    log "Target disk size: ${target_size}G"
    
    # Compare sizes (with some margin for metadata)
    if (( $(echo "$target_size < $source_used * 1.1" | bc -l) )); then
        error "Target disk is too small. Need at least ${source_used}G, but target has only ${target_size}G"
    fi
    
    log "Target disk has sufficient space"
}

prepare_target_disk() {
    log "Preparing target disk..."
    
    if ! check_target_disk_status; then
        log "Initializing $TARGET_DISK as a physical volume..."
        pvcreate "$TARGET_DISK" 2>&1 | tee -a "$LOG_FILE"
        
        log "Adding $TARGET_DISK to volume group $VG_NAME..."
        vgextend "$VG_NAME" "$TARGET_DISK" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log "Target disk prepared successfully"
}

migrate_data() {
    log "Starting data migration from $SOURCE_DISK to $TARGET_DISK..."
    log "This may take a considerable amount of time depending on data size..."
    
    # Perform the migration
    if pvmove -i 5 "$SOURCE_DISK" "$TARGET_DISK" 2>&1 | tee -a "$LOG_FILE"; then
        log "Data migration completed successfully"
    else
        error "Data migration failed. Check the log file: $LOG_FILE"
    fi
}

remove_source_disk() {
    log "Removing source disk from volume group..."
    
    # Remove the source PV from the VG
    vgreduce "$VG_NAME" "$SOURCE_DISK" 2>&1 | tee -a "$LOG_FILE"
    
    log "Removing physical volume label from source disk..."
    pvremove "$SOURCE_DISK" 2>&1 | tee -a "$LOG_FILE"
    
    log "Source disk removed successfully"
}

verify_migration() {
    log "Verifying migration..."
    
    # Check if target disk is now part of VG
    if ! pvs "$TARGET_DISK" 2>/dev/null | grep -q "$VG_NAME"; then
        error "Verification failed: Target disk is not part of $VG_NAME"
    fi
    
    # Check if source disk is no longer part of VG
    if pvs "$SOURCE_DISK" 2>/dev/null | grep -q "$VG_NAME"; then
        error "Verification failed: Source disk is still part of $VG_NAME"
    fi
    
    # Check VG health
    if ! vgs "$VG_NAME" &> /dev/null; then
        error "Verification failed: Volume group $VG_NAME is not accessible"
    fi
    
    log "Migration verified successfully"
}

prompt_confirmation() {
    echo ""
    warning "WARNING: This script will migrate the volume group '$VG_NAME'"
    warning "         FROM: $SOURCE_DISK"
    warning "         TO:   $TARGET_DISK"
    echo ""
    warning "This operation will:"
    warning "  1. Initialize $TARGET_DISK as a physical volume (if needed)"
    warning "  2. Add $TARGET_DISK to $VG_NAME"
    warning "  3. Move all data from $SOURCE_DISK to $TARGET_DISK"
    warning "  4. Remove $SOURCE_DISK from $VG_NAME"
    echo ""
    warning "Ensure you have:"
    warning "  - A complete backup of all data"
    warning "  - Verified that $TARGET_DISK is the correct disk"
    warning "  - Sufficient time for the migration to complete"
    echo ""
    
    read -p "Do you want to proceed? (yes/no): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        log "Migration cancelled by user"
        exit 0
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    # Check arguments first (before logging starts)
    check_arguments
    
    log "=========================================="
    log "LVM Volume Group Migration Script"
    log "=========================================="
    log "Source: $SOURCE_DISK"
    log "Target: $TARGET_DISK"
    log "Volume Group: $VG_NAME"
    log "Log File: $LOG_FILE"
    log "=========================================="
    
    # Pre-flight checks
    check_root
    check_prerequisites
    verify_disks
    verify_vg
    check_space
    
    # Display current state
    display_current_state
    
    # Get user confirmation
    prompt_confirmation
    
    # Perform migration
    log "Starting migration process..."
    prepare_target_disk
    migrate_data
    remove_source_disk
    
    # Verify and display final state
    verify_migration
    display_current_state
    
    log "=========================================="
    log "Migration completed successfully!"
    log "Log file saved to: $LOG_FILE"
    log "=========================================="
}

# Run main function
main "$@"

# Made with Bob
