# LVM Volume Group Migration Script

This bash script safely migrates an LVM volume group from one physical disk to another on Linux systems.

## Overview

The script migrates an LVM volume group from a source physical disk to a target disk using LVM's `pvmove` command, which performs an online migration without downtime. The script accepts command-line parameters for flexibility.

## Features

- ✅ Comprehensive pre-flight checks
- ✅ Automatic space verification
- ✅ Safe migration with error handling
- ✅ Detailed logging
- ✅ Color-coded output
- ✅ User confirmation prompts
- ✅ Post-migration verification

## Prerequisites

### System Requirements
- Linux operating system
- Root/sudo access
- LVM2 tools installed (`lvm2` package)
- Sufficient free space on target disk

### Before Running
1. **BACKUP YOUR DATA** - Always have a complete backup before any disk migration
2. Verify both source and target disks are accessible
3. Ensure no critical operations are running on the volume group
4. Have sufficient time for the migration (depends on data size)

## Installation

1. Download the script:
```bash
wget https://your-repo/migrate_lvm_vg.sh
# or
curl -O https://your-repo/migrate_lvm_vg.sh
```

2. Make it executable:
```bash
chmod +x migrate_lvm_vg.sh
```

## Usage

### Command Syntax

```bash
./migrate_lvm_vg.sh <source_disk> <target_disk> <vg_name>
```

### Parameters

- **source_disk**: Source physical disk path (e.g., `/dev/mapper/mpathb1`)
- **target_disk**: Target physical disk path (e.g., `/dev/mapper/mpathd1`)
- **vg_name**: Volume group name to migrate (e.g., `datavg`)

### Basic Usage

Run the script as root with the required parameters:
```bash
sudo ./migrate_lvm_vg.sh /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg
```

### Display Help

To see usage information:
```bash
./migrate_lvm_vg.sh
```

### What the Script Does

1. **Pre-flight Checks**
   - Verifies root privileges
   - Checks for required LVM tools
   - Validates source and target disks exist
   - Confirms volume group configuration
   - Verifies sufficient space on target disk

2. **Display Current State**
   - Shows current physical volumes
   - Lists volume groups
   - Displays logical volumes

3. **User Confirmation**
   - Prompts for explicit confirmation before proceeding
   - Type `yes` to continue

4. **Migration Process**
   - Initializes target disk as physical volume (if needed)
   - Adds target disk to volume group
   - Moves all data from source to target (online operation)
   - Removes source disk from volume group
   - Cleans up source disk PV label

5. **Verification**
   - Confirms target disk is part of volume group
   - Verifies source disk is removed
   - Checks volume group health
   - Displays final state

## Examples

### Example 1: Migrate datavg from mpathb1 to mpathd1
```bash
sudo ./migrate_lvm_vg.sh /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg
```

### Example 2: Migrate custom volume group
```bash
sudo ./migrate_lvm_vg.sh /dev/sdb1 /dev/sdc1 myvg
```

### Example 3: Migrate with different multipath devices
```bash
sudo ./migrate_lvm_vg.sh /dev/mapper/3600508b1001c1234 /dev/mapper/3600508b1001c5678 prodvg
```

## Logging

The script creates a detailed log file at:
```
/var/log/lvm_migration_YYYYMMDD_HHMMSS.log
```

All operations are logged with timestamps for audit purposes.

## Example Output

```bash
$ sudo ./migrate_lvm_vg.sh /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg

[2026-03-27 14:30:00] Arguments validated:
[2026-03-27 14:30:00]   Source Disk: /dev/mapper/mpathb1
[2026-03-27 14:30:00]   Target Disk: /dev/mapper/mpathd1
[2026-03-27 14:30:00]   Volume Group: datavg
[2026-03-27 14:30:00] ==========================================
[2026-03-27 14:30:00] LVM Volume Group Migration Script
[2026-03-27 14:30:00] ==========================================
[2026-03-27 14:30:00] Source: /dev/mapper/mpathb1
[2026-03-27 14:30:00] Target: /dev/mapper/mpathd1
[2026-03-27 14:30:00] Volume Group: datavg
[2026-03-27 14:30:00] ==========================================
[2026-03-27 14:30:01] Checking prerequisites...
[2026-03-27 14:30:01] All required tools are available
[2026-03-27 14:30:01] Verifying disk existence...
[2026-03-27 14:30:01] Source disk /dev/mapper/mpathb1 verified
[2026-03-27 14:30:01] Target disk /dev/mapper/mpathd1 verified
...
```

## Troubleshooting

### Common Issues

**Error: "Missing required arguments"**
- Solution: Provide all three required parameters: source disk, target disk, and volume group name
- Example: `sudo ./migrate_lvm_vg.sh /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg`

**Error: "This script must be run as root"**
- Solution: Run with `sudo` or as root user

**Error: "Source disk is not part of volume group"**
- Solution: Verify the correct source disk path with `pvs` command
- Check that you specified the correct volume group name

**Error: "Target disk is too small"**
- Solution: Use a larger target disk or free up space on the source

**Error: "Data migration failed"**
- Solution: Check the log file for details. The migration can be resumed with `pvmove --abort` followed by rerunning the script

### Manual Verification

Check physical volumes:
```bash
pvs
pvdisplay /dev/mapper/mpathd1
```

Check volume group:
```bash
vgs datavg
vgdisplay datavg
```

Check logical volumes:
```bash
lvs
lvdisplay datavg
```

## Safety Features

- **Error Handling**: Script exits on any error (`set -euo pipefail`)
- **Confirmation Prompt**: Requires explicit "yes" to proceed
- **Space Verification**: Ensures target disk has sufficient space
- **Comprehensive Logging**: All operations logged for audit trail
- **Post-Migration Verification**: Confirms successful migration

## Migration Time

Migration time depends on:
- Amount of data to migrate
- Disk I/O performance
- System load

Typical speeds: 50-150 MB/s (varies by hardware)

Example: 100GB of data might take 10-30 minutes

## Important Notes

⚠️ **WARNING**: 
- Always backup your data before migration
- The migration is performed online (no downtime required)
- Do not interrupt the migration process
- Ensure stable power supply during migration
- Monitor system resources during migration

## Recovery

If migration is interrupted:

1. Check migration status:
```bash
pvmove --abort
```

2. Review the log file for errors

3. Verify volume group integrity:
```bash
vgck datavg
```

4. Rerun the script if needed

## License

This script is provided as-is for educational and operational purposes.

## Support

For issues or questions:
1. Check the log file in `/var/log/`
2. Review LVM documentation: `man lvm`, `man pvmove`
3. Verify system logs: `journalctl -xe`

## Version History

- v1.0 (2026-03-27): Initial release
  - Basic migration functionality
  - Comprehensive error checking
  - Detailed logging