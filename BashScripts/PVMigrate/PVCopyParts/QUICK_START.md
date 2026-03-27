# Quick Start Guide - Copy Partition Layout

## TL;DR

Copy partition layout from `/dev/mapper/mpathb` to `/dev/mapper/mpathd`:

```bash
cd PVCopyParts
chmod +x copy_partition_layout.sh

# Copy partition layout (specify both disks)
sudo ./copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd

# Or use different disks
sudo ./copy_partition_layout.sh /dev/sda /dev/sdb
```

Type `YES` when prompted to confirm.

**Show help:**
```bash
./copy_partition_layout.sh --help
```

---

## Prerequisites Checklist

- [ ] Running as root or with sudo
- [ ] Both disks exist and are accessible
- [ ] Target disk (`/dev/mapper/mpathd`) is NOT mounted
- [ ] You have backed up any important data on target disk
- [ ] Required packages installed: `util-linux`, `parted`

---

## Command-Line Usage

```bash
./copy_partition_layout.sh SOURCE_DISK TARGET_DISK
```

**Both arguments are required!**

**Examples:**
- Multipath disks: `sudo ./copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd`
- Regular disks: `sudo ./copy_partition_layout.sh /dev/sda /dev/sdb`
- Show help: `./copy_partition_layout.sh --help`

---

## Quick Commands

### Check if disks exist
```bash
ls -l /dev/mapper/mpathb /dev/mapper/mpathd
lsblk /dev/mapper/mpathb /dev/mapper/mpathd
```

### Check disk sizes
```bash
blockdev --getsize64 /dev/mapper/mpathb
blockdev --getsize64 /dev/mapper/mpathd
```

### View current partition layout
```bash
fdisk -l /dev/mapper/mpathb
fdisk -l /dev/mapper/mpathd
```

### Check if target is mounted
```bash
mount | grep mpathd
```

### Unmount target partitions (if needed)
```bash
umount /dev/mapper/mpathd*
```

### Install required packages

**Debian/Ubuntu:**
```bash
sudo apt-get install util-linux parted
```

**RHEL/CentOS/Rocky:**
```bash
sudo yum install util-linux parted
```

---

## What Happens

1. Script validates disks and shows information
2. Displays source partition layout
3. Asks for confirmation (type `YES`)
4. Backs up target disk's current partition table
5. Copies partition layout from source to target
6. Verifies partitions were created
7. Shows next steps

---

## After Running

### Format new partitions
```bash
# Example for ext4
mkfs.ext4 /dev/mapper/mpathd1

# Example for xfs
mkfs.xfs /dev/mapper/mpathd2
```

### For LVM
```bash
# Create physical volume
pvcreate /dev/mapper/mpathd1

# Extend volume group
vgextend my_vg /dev/mapper/mpathd1
```

### Copy data
```bash
# Block-level copy
dd if=/dev/mapper/mpathb1 of=/dev/mapper/mpathd1 bs=4M status=progress

# Or filesystem copy (after mounting)
rsync -avxHAX /source/ /target/
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Must be run as root" | Use `sudo` |
| "Missing required commands" | Install `util-linux` and `parted` |
| "Disk does not exist" | Check with `lsblk`, verify multipath config |
| "Partitions are mounted" | Unmount with `umount /dev/mapper/mpathd*` |
| Partitions not visible | Run `partprobe /dev/mapper/mpathd` |

---

## Important Notes

⚠️ **This DESTROYS all data on `/dev/mapper/mpathd`**

⚠️ **Only copies partition layout, NOT data**

⚠️ **Target disk must be ≥ source disk size**

---

## Log Files

- Operation log: `/var/log/copy_partition_layout_*.log`
- Backup: `/tmp/partition_backup_mpathd_*.dump`

---

## Need More Info?

See [README.md](README.md) for complete documentation.