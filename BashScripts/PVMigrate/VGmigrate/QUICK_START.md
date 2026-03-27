# Quick Start Guide

## Basic Command

```bash
sudo ./migrate_lvm_vg.sh <source_disk> <target_disk> <vg_name>
```

## Example: Migrate datavg from mpathb1 to mpathd1

```bash
sudo ./migrate_lvm_vg.sh /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg
```

## Before Running

1. ✅ **BACKUP YOUR DATA** - Always have a complete backup
2. ✅ Verify source disk: `pvs /dev/mapper/mpathb1`
3. ✅ Verify target disk exists: `ls -l /dev/mapper/mpathd1`
4. ✅ Check volume group: `vgs datavg`
5. ✅ Ensure sufficient space on target disk

## Quick Verification Commands

### Check current LVM configuration
```bash
pvs                    # List physical volumes
vgs                    # List volume groups
lvs                    # List logical volumes
```

### Check specific disk
```bash
pvdisplay /dev/mapper/mpathb1
```

### Check volume group details
```bash
vgdisplay datavg
```

### Check disk size
```bash
blockdev --getsize64 /dev/mapper/mpathd1
```

## What Happens During Migration

1. Script validates all parameters and prerequisites
2. Displays current LVM configuration
3. Asks for confirmation (type `yes` to proceed)
4. Initializes target disk as physical volume
5. Adds target disk to volume group
6. Migrates data from source to target (this takes time!)
7. Removes source disk from volume group
8. Verifies successful migration
9. Displays final configuration

## Migration Time Estimate

- **Small volumes (< 50GB)**: 5-15 minutes
- **Medium volumes (50-200GB)**: 15-60 minutes
- **Large volumes (> 200GB)**: 1+ hours

*Actual time depends on disk I/O performance and system load*

## Monitoring Progress

The script shows progress every 5 seconds during data migration.

You can also monitor in another terminal:
```bash
# Watch LVM operations
watch -n 2 'pvs; echo ""; lvs'

# Check system I/O
iostat -x 2

# View log file in real-time
tail -f /var/log/lvm_migration_*.log
```

## If Something Goes Wrong

1. **Don't panic** - The migration can be safely aborted
2. Check the log file: `/var/log/lvm_migration_*.log`
3. Abort ongoing migration: `sudo pvmove --abort`
4. Verify VG health: `sudo vgck datavg`
5. Contact your system administrator if needed

## Post-Migration

After successful migration:
- Source disk is removed from the volume group
- Target disk contains all data
- All logical volumes remain accessible
- No downtime was required

Verify everything works:
```bash
# Check final state
sudo pvs
sudo vgs datavg
sudo lvs

# Verify data accessibility
ls -la /mount/point/of/your/lv
```

## Need Help?

Display usage information:
```bash
./migrate_lvm_vg.sh
```

See full documentation:
```bash
cat README.md