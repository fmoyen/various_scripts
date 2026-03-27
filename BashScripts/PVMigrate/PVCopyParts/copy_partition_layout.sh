#!/bin/bash

################################################################################
# Script: copy_partition_layout.sh
# Description: Copies the physical partition layout from one disk to another
#              using fdisk/sfdisk
# Usage: ./copy_partition_layout.sh [SOURCE_DISK] [TARGET_DISK]
#        ./copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd
#
# This script will:
# 1. Read the partition table from source disk
# 2. Apply the same partition layout to target disk
# 3. Preserve partition types, sizes, and bootable flags
#
# WARNING: This will DESTROY all data on the target disk!
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

# Log file
LOG_FILE="/var/log/copy_partition_layout_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Function: show_usage
# Description: Displays usage information
################################################################################
show_usage() {
    cat << EOF
${BLUE}Usage:${NC}
  $0 SOURCE_DISK TARGET_DISK

${BLUE}Examples:${NC}
  $0 /dev/mapper/mpathb /dev/mapper/mpathd
    Copy partition layout from mpathb to mpathd

  $0 /dev/sda /dev/sdb
    Copy partition layout from sda to sdb

${BLUE}Arguments:${NC}
  SOURCE_DISK    Source disk to copy partition layout from (required)
  TARGET_DISK    Target disk to apply partition layout to (required)

${YELLOW}WARNING:${NC} This will DESTROY all data on the target disk!

${BLUE}Options:${NC}
  -h, --help     Show this help message

EOF
}

################################################################################
# Function: log_message
# Description: Logs messages to both console and log file
################################################################################
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

################################################################################
# Function: print_header
# Description: Prints a formatted header
################################################################################
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

################################################################################
# Function: check_root
# Description: Ensures script is run as root
################################################################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR: This script must be run as root${NC}" >&2
        exit 1
    fi
}

################################################################################
# Function: check_dependencies
# Description: Checks if required commands are available
################################################################################
check_dependencies() {
    local deps=("sfdisk" "fdisk" "blockdev" "partprobe")
    local missing=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}ERROR: Missing required commands: ${missing[*]}${NC}" >&2
        echo "Please install the required packages (util-linux, parted)" >&2
        exit 1
    fi
}

################################################################################
# Function: check_disk_exists
# Description: Verifies that a disk device exists
################################################################################
check_disk_exists() {
    local disk="$1"
    local disk_type="$2"
    
    if [[ ! -b "$disk" ]]; then
        echo -e "${RED}ERROR: ${disk_type} disk '$disk' does not exist or is not a block device${NC}" >&2
        exit 1
    fi
    
    log_message "INFO" "${disk_type} disk '$disk' found"
}

################################################################################
# Function: get_disk_size
# Description: Gets the size of a disk in bytes
################################################################################
get_disk_size() {
    local disk="$1"
    blockdev --getsize64 "$disk" 2>/dev/null || echo "0"
}

################################################################################
# Function: display_disk_info
# Description: Displays information about source and target disks
################################################################################
display_disk_info() {
    local source_size=$(get_disk_size "$SOURCE_DISK")
    local target_size=$(get_disk_size "$TARGET_DISK")
    
    echo ""
    print_header "Disk Information"
    echo -e "${YELLOW}Source Disk:${NC} $SOURCE_DISK"
    echo -e "  Size: $(numfmt --to=iec-i --suffix=B $source_size 2>/dev/null || echo "$source_size bytes")"
    echo ""
    echo -e "${YELLOW}Target Disk:${NC} $TARGET_DISK"
    echo -e "  Size: $(numfmt --to=iec-i --suffix=B $target_size 2>/dev/null || echo "$target_size bytes")"
    echo ""
    
    if [[ $target_size -lt $source_size ]]; then
        echo -e "${RED}WARNING: Target disk is smaller than source disk!${NC}"
        echo -e "${RED}This may cause issues with partition layout.${NC}"
        echo ""
    fi
}

################################################################################
# Function: display_source_partitions
# Description: Shows the current partition layout of the source disk
################################################################################
display_source_partitions() {
    print_header "Source Disk Partition Layout"
    echo ""
    fdisk -l "$SOURCE_DISK" 2>/dev/null || true
    echo ""
}

################################################################################
# Function: check_target_mounted
# Description: Checks if any partitions on target disk are mounted
################################################################################
check_target_mounted() {
    local mounted_parts=$(mount | grep "^${TARGET_DISK}" | awk '{print $1}')
    
    if [[ -n "$mounted_parts" ]]; then
        echo -e "${RED}ERROR: The following partitions on target disk are mounted:${NC}" >&2
        echo "$mounted_parts" >&2
        echo -e "${RED}Please unmount them before proceeding.${NC}" >&2
        exit 1
    fi
}

################################################################################
# Function: backup_partition_table
# Description: Creates a backup of the target disk's current partition table
################################################################################
backup_partition_table() {
    local backup_file="/tmp/partition_backup_${TARGET_DISK##*/}_$(date +%Y%m%d_%H%M%S).dump"
    
    log_message "INFO" "Backing up current partition table of $TARGET_DISK to $backup_file"
    
    if sfdisk -d "$TARGET_DISK" > "$backup_file" 2>/dev/null; then
        echo -e "${GREEN}Backup saved to: $backup_file${NC}"
        log_message "INFO" "Backup successful"
    else
        log_message "WARN" "Could not backup partition table (disk may be empty)"
    fi
}

################################################################################
# Function: confirm_operation
# Description: Asks user for confirmation before proceeding
################################################################################
confirm_operation() {
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                        ⚠️  WARNING  ⚠️                          ║${NC}"
    echo -e "${RED}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║  This operation will DESTROY ALL DATA on the target disk:     ║${NC}"
    echo -e "${RED}║  ${TARGET_DISK}${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║  The partition table from ${SOURCE_DISK} will be copied.${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║  This action is IRREVERSIBLE!                                 ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Type 'YES' in capital letters to continue: " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        echo -e "${YELLOW}Operation cancelled by user.${NC}"
        log_message "INFO" "Operation cancelled by user"
        exit 0
    fi
    
    log_message "INFO" "User confirmed operation"
}

################################################################################
# Function: copy_partition_layout
# Description: Copies the partition layout from source to target
################################################################################
copy_partition_layout() {
    local temp_dump="/tmp/partition_layout_${SOURCE_DISK##*/}_$(date +%Y%m%d_%H%M%S).dump"
    
    print_header "Copying Partition Layout"
    
    # Dump source partition table
    log_message "INFO" "Dumping partition table from $SOURCE_DISK"
    if ! sfdisk -d "$SOURCE_DISK" > "$temp_dump" 2>/dev/null; then
        echo -e "${RED}ERROR: Failed to dump partition table from source disk${NC}" >&2
        log_message "ERROR" "Failed to dump partition table from $SOURCE_DISK"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Source partition table dumped${NC}"
    log_message "INFO" "Source partition table dumped to $temp_dump"
    
    # Show what will be applied
    echo ""
    echo -e "${YELLOW}Partition layout to be applied:${NC}"
    cat "$temp_dump"
    echo ""
    
    # Wipe existing partition table on target
    log_message "INFO" "Wiping existing partition signatures on $TARGET_DISK"
    wipefs -a "$TARGET_DISK" &>/dev/null || true
    
    # Apply partition table to target
    log_message "INFO" "Applying partition table to $TARGET_DISK"
    if ! sfdisk "$TARGET_DISK" < "$temp_dump" 2>&1 | tee -a "$LOG_FILE"; then
        echo -e "${RED}ERROR: Failed to apply partition table to target disk${NC}" >&2
        log_message "ERROR" "Failed to apply partition table to $TARGET_DISK"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Partition table applied successfully${NC}"
    log_message "INFO" "Partition table applied successfully"
    
    # Inform kernel of partition changes
    log_message "INFO" "Informing kernel of partition table changes"
    partprobe "$TARGET_DISK" 2>/dev/null || true
    sleep 2  # Give kernel time to recognize new partitions
    
    # Clean up temp file
    rm -f "$temp_dump"
}

################################################################################
# Function: verify_partitions
# Description: Verifies that partitions were created successfully
################################################################################
verify_partitions() {
    print_header "Verification"
    
    echo ""
    echo -e "${YELLOW}New partition layout on target disk:${NC}"
    fdisk -l "$TARGET_DISK" 2>/dev/null || true
    echo ""
    
    # Compare partition counts
    local source_count=$(fdisk -l "$SOURCE_DISK" 2>/dev/null | grep "^${SOURCE_DISK}" | wc -l)
    local target_count=$(fdisk -l "$TARGET_DISK" 2>/dev/null | grep "^${TARGET_DISK}" | wc -l)
    
    if [[ $source_count -eq $target_count ]]; then
        echo -e "${GREEN}✓ Partition count matches: $target_count partitions created${NC}"
        log_message "INFO" "Verification successful: $target_count partitions created"
    else
        echo -e "${YELLOW}⚠ Partition count mismatch: Source=$source_count, Target=$target_count${NC}"
        log_message "WARN" "Partition count mismatch: Source=$source_count, Target=$target_count"
    fi
}

################################################################################
# Function: display_next_steps
# Description: Shows recommended next steps
################################################################################
display_next_steps() {
    echo ""
    print_header "Next Steps"
    echo ""
    echo -e "${YELLOW}The partition layout has been copied successfully.${NC}"
    echo ""
    echo "Recommended next steps:"
    echo "  1. Format the new partitions with appropriate filesystems"
    echo "  2. Create physical volumes if using LVM: pvcreate <partition>"
    echo "  3. Add to volume groups if needed: vgextend <vg_name> <partition>"
    echo "  4. Copy data from source partitions to target partitions"
    echo ""
    echo -e "${BLUE}Log file saved to: $LOG_FILE${NC}"
    echo ""
}

################################################################################
# Main execution
################################################################################
main() {
    # Check for help flag
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Validate required arguments
    if [[ -z "$SOURCE_DISK" ]] || [[ -z "$TARGET_DISK" ]]; then
        echo -e "${RED}ERROR: Both SOURCE_DISK and TARGET_DISK are required${NC}" >&2
        echo ""
        show_usage
        exit 1
    fi
    
    # Initial checks
    check_root
    check_dependencies
    
    # Start logging
    log_message "INFO" "========== Script started =========="
    log_message "INFO" "Source disk: $SOURCE_DISK"
    log_message "INFO" "Target disk: $TARGET_DISK"
    
    # Verify disks exist
    check_disk_exists "$SOURCE_DISK" "Source"
    check_disk_exists "$TARGET_DISK" "Target"
    
    # Display information
    display_disk_info
    display_source_partitions
    
    # Safety checks
    check_target_mounted
    
    # Backup current target partition table
    backup_partition_table
    
    # Get user confirmation
    confirm_operation
    
    # Perform the copy
    copy_partition_layout
    
    # Verify results
    verify_partitions
    
    # Show next steps
    display_next_steps
    
    log_message "INFO" "========== Script completed successfully =========="
    echo -e "${GREEN}✓ Operation completed successfully!${NC}"
}

# Run main function
main "$@"

# Made with Bob
