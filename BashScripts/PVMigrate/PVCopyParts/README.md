# Copy Partition Layout Script

## Overview

This bash script (`copy_partition_layout.sh`) copies the physical partition layout from one disk to another using `sfdisk`. It's specifically designed to replicate the partition table from `/dev/mapper/mpathb` (source) to `/dev/mapper/mpathd` (target).

## Features

- ✅ **Safe Operation**: Multiple safety checks and user confirmation
- ✅ **Comprehensive Logging**: All operations logged to `/var/log/`
- ✅ **Backup**: Automatically backs up target disk's current partition table
- ✅ **Verification**: Validates partition creation after copying
- ✅ **Error Handling**: Robust error checking with informative messages
- ✅ **Colored Output**: Easy-to-read console output with color coding

## Requirements

### System Requirements
- Linux operating system
- Root/sudo privileges
- Multipath devices configured (for `/dev/mapper/mpathd`)

### Required Packages
- `util-linux` (provides `sfdisk`, `fdisk`, `blockdev`, `wipefs`)
- `parted` (provides `partprobe`)

Install on Debian/Ubuntu:
```bash
sudo apt-get install util-linux parted
```

Install on RHEL/CentOS/Rocky:
```bash
sudo yum install util-linux parted
```

## Usage

### Basic Usage

1. Make the script executable:
```bash
chmod +x copy_partition_layout.sh
```

2. Run the script as root with source and target disks:

**Copy from mpathb to mpathd**:
```bash
sudo ./copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd
```

**Copy from sda to sdb**:
```bash
sudo ./copy_partition_layout.sh /dev/sda /dev/sdb
```

**Show help**:
```bash
./copy_partition_layout.sh --help
```

### What the Script Does

1. **Pre-flight Checks**:
   - Verifies root privileges
   - Checks for required commands
   - Validates that both source and target disks exist
   - Displays disk information and sizes
   - Shows current partition layout of source disk

2. **Safety Checks**:
   - Checks if target disk partitions are mounted
   - Creates backup of target disk's current partition table
   - Requires explicit user confirmation (type "YES")

3. **Partition Copy**:
   - Dumps partition table from source disk using `sfdisk`
   - Wipes existing partition signatures on target disk
   - Applies source partition layout to target disk
   - Informs kernel of partition changes

4. **Verification**:
   - Displays new partition layout
   - Compares partition counts between source and target
   - Provides next steps guidance

## Important Warnings

⚠️ **DATA DESTRUCTION WARNING**: This script will **DESTROY ALL DATA** on the target disk (`/dev/mapper/mpathd`). Ensure you have backups of any important data.

⚠️ **Disk Size**: If the target disk is smaller than the source disk, some partitions may not fit or may be truncated.

⚠️ **Mounted Partitions**: The script will refuse to run if any partitions on the target disk are mounted. Unmount them first.

## Command-Line Arguments

The script requires two command-line arguments:

```bash
./copy_partition_layout.sh SOURCE_DISK TARGET_DISK
```

**Arguments:**
- `SOURCE_DISK` - Source disk to copy partition layout from (required)
- `TARGET_DISK` - Target disk to apply partition layout to (required)

**Examples:**
```bash
# Copy from mpathb to mpathd
sudo ./copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd

# Copy from sda to sdb
sudo ./copy_partition_layout.sh /dev/sda /dev/sdb

# Show help
./copy_partition_layout.sh --help
```

## Output

### Log Files
All operations are logged to:
```
/var/log/copy_partition_layout_YYYYMMDD_HHMMSS.log
```

### Backup Files
Target disk partition table backups are saved to:
```
/tmp/partition_backup_mpathd_YYYYMMDD_HHMMSS.dump
```

## Example Output

```
========================================
Disk Information
========================================
Source Disk: /dev/mapper/mpathb
  Size: 500.0GiB

Target Disk: /dev/mapper/mpathd
  Size: 500.0GiB

========================================
Source Disk Partition Layout
========================================

Disk /dev/mapper/mpathb: 500 GiB, 536870912000 bytes, 1048576000 sectors
...

╔════════════════════════════════════════════════════════════════╗
║                        ⚠️  WARNING  ⚠️                          ║
╠════════════════════════════════════════════════════════════════╣
║  This operation will DESTROY ALL DATA on the target disk:     ║
║  /dev/mapper/mpathd                                            ║
...
╚════════════════════════════════════════════════════════════════╝

Type 'YES' in capital letters to continue: YES

========================================
Copying Partition Layout
========================================
✓ Source partition table dumped
✓ Partition table applied successfully

========================================
Verification
========================================
✓ Partition count matches: 3 partitions created
```

## Next Steps After Running

After successfully copying the partition layout:

1. **Format Partitions**: Create filesystems on the new partitions
   ```bash
   mkfs.ext4 /dev/mapper/mpathd1
   mkfs.xfs /dev/mapper/mpathd2
   ```

2. **LVM Setup** (if using LVM):
   ```bash
   # Create physical volumes
   pvcreate /dev/mapper/mpathd1
   
   # Extend volume group
   vgextend my_vg /dev/mapper/mpathd1
   ```

3. **Copy Data**: Use appropriate tools to copy data from source to target
   ```bash
   # Using dd (for exact copy)
   dd if=/dev/mapper/mpathb1 of=/dev/mapper/mpathd1 bs=4M status=progress
   
   # Or using rsync (for filesystem copy)
   rsync -avxHAX /source/mount/ /target/mount/
   ```

## Troubleshooting

### Error: "This script must be run as root"
**Solution**: Run with `sudo` or as root user

### Error: "Missing required commands"
**Solution**: Install required packages (util-linux, parted)

### Error: "Disk does not exist or is not a block device"
**Solution**: 
- Verify disk paths with `lsblk` or `ls -l /dev/mapper/`
- Check multipath configuration with `multipath -ll`
- Ensure multipath devices are properly configured

### Error: "Partitions on target disk are mounted"
**Solution**: Unmount all partitions on target disk:
```bash
umount /dev/mapper/mpathd1
umount /dev/mapper/mpathd2
# etc.
```

### Warning: "Target disk is smaller than source disk"
**Solution**: 
- Use a target disk of equal or larger size
- Or manually adjust partition sizes after copying

### Partitions not visible after script
**Solution**: 
```bash
# Manually inform kernel
partprobe /dev/mapper/mpathd

# Or rescan multipath devices
multipath -r

# Check with
lsblk /dev/mapper/mpathd
```

## Technical Details

### Tools Used

- **sfdisk**: Partition table manipulation (dump and restore)
- **fdisk**: Display partition information
- **blockdev**: Get disk size information
- **wipefs**: Remove partition signatures
- **partprobe**: Inform kernel of partition changes

### Partition Table Format

The script uses `sfdisk` which supports:
- MBR (Master Boot Record)
- GPT (GUID Partition Table)

The format is automatically detected and preserved.

## Safety Features

1. **Root Check**: Ensures script runs with proper privileges
2. **Dependency Check**: Verifies all required commands are available
3. **Disk Existence**: Validates both disks exist before proceeding
4. **Mount Check**: Prevents operation on mounted filesystems
5. **Backup**: Creates backup of target partition table
6. **Confirmation**: Requires explicit "YES" confirmation
7. **Logging**: Comprehensive logging of all operations
8. **Error Handling**: Exits on any error with informative messages

## Limitations

- Does not copy data, only partition layout
- Does not preserve filesystem UUIDs
- Does not handle encrypted partitions specially
- Requires target disk to be at least as large as source disk
- Does not modify bootloader configuration

## Related Scripts

- `migrate_lvm_vg.sh` - For migrating LVM volume groups
- Other scripts in the VGmigrate directory

## License

This script is provided as-is for system administration purposes.

## Author

Created for partition layout migration tasks on Linux systems with multipath storage.

## Version History

- **v1.0** (2026-03-27): Initial release
  - Basic partition layout copying
  - Safety checks and confirmations
  - Comprehensive logging and verification