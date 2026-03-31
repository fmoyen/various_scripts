# Migrating Linux OS from One Disk to Another (with Multipathing) - IBM Z Platform

## Overview

This guide explains how to migrate a complete Linux operating system from one disk to another when using multipath storage devices on IBM Z (s390x) platform. The process combines partition layout copying, LVM migration, and zipl bootloader configuration.

## Prerequisites

### System Requirements
- Linux operating system with multipath configured
- Root/sudo privileges
- LVM2 tools installed (`lvm2` package)
- Sufficient space on target disk
- **COMPLETE BACKUP OF ALL DATA**

### Required Tools
- `sfdisk`, `fdisk`, `blockdev`, `wipefs` (util-linux package)
- `parted` (parted package)
- LVM tools: `pvs`, `vgs`, `lvs`, `pvcreate`, `vgextend`, `pvmove`, `vgreduce`, `pvremove`
- `dd`, `rsync` for data copying
- `zipl` for bootloader (s390-tools package on IBM Z)
- `dracut` for initramfs generation

### Before Starting
1. **BACKUP YOUR DATA** - Always have a complete backup before any disk migration
2. Verify both source and target disks are accessible
3. Ensure no critical operations are running on the volume group
4. Have sufficient time for the migration (depends on data size)
5. Verify multipath configuration is working correctly

## Complete Migration Process

### Phase 1: Verify Multipath Configuration

Before starting, verify your multipath devices:

```bash
# List multipath devices
multipath -ll

# Check block devices
lsblk

# Verify both source and target disks
ls -l /dev/mapper/mpathb*
ls -l /dev/mapper/mpathd*
```

**Important:** Always use device mapper paths (`/dev/mapper/mpathX`) not raw device paths (`/dev/sdX`) when working with multipath devices.

### Phase 2: Copy Partition Layout

Use the `copy_partition_layout.sh` script from the PVCopyParts directory:

```bash
sudo ./PVCopyParts/copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd
```

**What this does:**
- Reads the partition table from source disk
- Applies the same partition layout to target disk
- Preserves partition types, sizes, and bootable flags
- Creates backup of target disk's current partition table
- Verifies partition creation

**Example output:**
```
Source Disk: /dev/mapper/mpathb
  Size: 500.0GiB

Target Disk: /dev/mapper/mpathd
  Size: 500.0GiB

Type 'YES' in capital letters to continue: YES

✓ Source partition table dumped
✓ Partition table applied successfully
✓ Partition count matches: 3 partitions created
```

See `PVCopyParts/README.md` for detailed documentation.

### Phase 3: Migrate LVM Volume Groups

For each LVM volume group, use the `migrate_lvm_vg.sh` script from the VGmigrate directory:

```bash
sudo ./VGmigrate/migrate_lvm_vg.sh /dev/mapper/mpathb1 /dev/mapper/mpathd1 datavg
```

**What this does:**
- Initializes target disk as physical volume (if needed)
- Adds target disk to volume group
- Moves all data from source to target (online operation, no downtime)
- Removes source disk from volume group
- Cleans up source disk PV label

**Migration time:** Depends on data size. Typical speeds: 50-150 MB/s
- Example: 100GB might take 10-30 minutes

**Example:**
```bash
# Migrate data volume group
sudo ./VGmigrate/migrate_lvm_vg.sh /dev/mapper/mpathb2 /dev/mapper/mpathd2 datavg

# Migrate root volume group (if separate)
sudo ./VGmigrate/migrate_lvm_vg.sh /dev/mapper/mpathb3 /dev/mapper/mpathd3 rootvg
```

See `VGmigrate/README.md` for detailed documentation.

### Phase 4: Migrate Non-LVM Partitions

For partitions not managed by LVM (boot, EFI, swap, etc.), you need to copy data manually.

#### Option A: Block-level Copy (Exact Copy)

Use `dd` for exact block-level copy:

```bash
# Copy boot partition
dd if=/dev/mapper/mpathb1 of=/dev/mapper/mpathd1 bs=4M status=progress conv=fsync

# Copy EFI partition (if exists)
dd if=/dev/mapper/mpathb2 of=/dev/mapper/mpathd2 bs=4M status=progress conv=fsync
```

**Advantages:**
- Exact copy including UUIDs
- Preserves all filesystem metadata
- Simple and reliable

**Disadvantages:**
- Slower than filesystem copy
- Copies empty space
- Target partition must be same size or larger

#### Option B: Filesystem-level Copy (Recommended for /boot)

Use `rsync` for filesystem-level copy:

```bash
# Create filesystem on target partition
mkfs.ext4 /dev/mapper/mpathd1

# Mount both partitions
mkdir -p /mnt/source /mnt/target
mount /dev/mapper/mpathb1 /mnt/source
mount /dev/mapper/mpathd1 /mnt/target

# Copy data preserving all attributes
rsync -avxHAX --progress /mnt/source/ /mnt/target/

# Unmount
umount /mnt/source
umount /mnt/target
```

**Advantages:**
- Faster (only copies actual data)
- Can resize filesystem
- More flexible

**Disadvantages:**
- Changes UUIDs (requires fstab update)
- Requires filesystem creation

#### Swap Partition

For swap partitions, simply recreate:

```bash
# Create new swap
mkswap /dev/mapper/mpathd3

# Get new UUID
blkid /dev/mapper/mpathd3
```

### Phase 5: Update Bootloader (zipl for IBM Z)

After copying all partitions, update the zipl bootloader to use the new disk.

#### Understanding zipl on IBM Z

On IBM Z (s390x) systems, zipl (z Initial Program Load) is used instead of GRUB. The bootloader is written directly to the disk and configured via `/etc/zipl.conf`.

```bash
# Mount the new root filesystem
mount /dev/mapper/mpathd-root /mnt

# Mount boot partition
mount /dev/mapper/mpathd1 /mnt/boot

# Bind mount system directories
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# Chroot into the new system
chroot /mnt

# Verify zipl configuration file
cat /etc/zipl.conf

# Update zipl.conf if needed (see configuration section below)
vi /etc/zipl.conf

# Run zipl to install bootloader on new disk
zipl -V

# Verify zipl installation
zipl -V -t

# Exit chroot
exit

# Unmount everything
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev
umount /mnt/boot
umount /mnt
```

#### zipl Configuration (/etc/zipl.conf)

Example zipl.conf for IBM Z with multipath:

```ini
[defaultboot]
defaultmenu = menu

[menu]
    target = /boot/
    timeout = 10
    prompt = 1
    1 = Linux
    default = 1

[Linux]
    image = /boot/vmlinuz-$(uname -r)
    ramdisk = /boot/initramfs-$(uname -r).img
    parameters = "root=/dev/mapper/mpathd-root rd.lvm.lv=rootvg/root rd.multipath=1 crashkernel=auto"
    target = /boot/
```

**Key parameters for multipath:**
- `rd.multipath=1` - Enable multipath in initramfs
- `rd.lvm.lv=vgname/lvname` - Specify LVM volumes to activate
- `root=/dev/mapper/device` - Root device path

**Important zipl notes:**
- zipl writes bootloader directly to disk sectors
- Must run `zipl` after any kernel or initramfs changes
- Configuration is in `/etc/zipl.conf`
- No separate boot partition required (but recommended)

### Phase 6: Update /etc/fstab

Update the filesystem table to use new UUIDs (if you used rsync or created new filesystems):

```bash
# Get new UUIDs
blkid /dev/mapper/mpathd1
blkid /dev/mapper/mpathd2
blkid /dev/mapper/mpathd-root
blkid /dev/mapper/mpathd-swap

# Edit fstab on the new disk
mount /dev/mapper/mpathd-root /mnt
vi /mnt/etc/fstab

# Update UUID entries to match new disk
# Example:
# UUID=old-uuid-here  /boot  ext4  defaults  0  2
# Change to:
# UUID=new-uuid-here  /boot  ext4  defaults  0  2

umount /mnt
```

**Example fstab:**
```
UUID=12345678-1234-1234-1234-123456789abc  /          ext4    defaults        1 1
UUID=abcdef12-3456-7890-abcd-ef1234567890  /boot      ext4    defaults        1 2
UUID=fedcba98-7654-3210-fedc-ba9876543210  /boot/efi  vfat    umask=0077      0 2
UUID=11111111-2222-3333-4444-555555555555  swap       swap    defaults        0 0
```

### Phase 7: Update Multipath Configuration

Verify and update multipath configuration if needed:

```bash
# Check multipath configuration
cat /etc/multipath.conf

# Verify new disk is recognized
multipath -ll

# If needed, add new disk to multipath.conf
vi /etc/multipath.conf

# Reload multipath configuration
systemctl reload multipathd

# Or restart multipath service
systemctl restart multipathd
```

### Phase 8: Rebuild initramfs with dracut (IBM Z)

Rebuild the initial RAM filesystem to include multipath and new disk configuration for IBM Z:

#### Configure dracut for multipath

Create or update dracut configuration to include multipath modules:

```bash
# Create dracut configuration for multipath
cat > /etc/dracut.conf.d/multipath.conf << 'EOF'
# Enable multipath support in initramfs
add_dracutmodules+=" multipath "
add_drivers+=" dm-multipath dm-service-time "
install_items+=" /etc/multipath.conf /etc/multipath/bindings "
EOF

# Create dracut configuration for LVM
cat > /etc/dracut.conf.d/lvm.conf << 'EOF'
# Enable LVM support in initramfs
add_dracutmodules+=" lvm "
EOF
```

#### Rebuild initramfs

```bash
# Rebuild initramfs for current kernel
dracut -f

# Or rebuild for specific kernel version
dracut -f /boot/initramfs-$(uname -r).img $(uname -r)

# Rebuild with verbose output for troubleshooting
dracut -f -v

# Verify initramfs was created
ls -lh /boot/initramfs-*

# Check initramfs contents (verify multipath is included)
lsinitrd /boot/initramfs-$(uname -r).img | grep -i multipath
lsinitrd /boot/initramfs-$(uname -r).img | grep -i dm-multipath
```

#### Verify dracut configuration

```bash
# List all dracut modules
dracut --list-modules

# Show what will be included in initramfs
dracut --print-cmdline

# Test initramfs generation (dry-run)
dracut --force --verbose --add multipath --add lvm /tmp/test-initramfs.img $(uname -r)
```

#### Important dracut options for IBM Z

```bash
# Full rebuild with all necessary modules
dracut -f \
  --add multipath \
  --add lvm \
  --add dm \
  --add cio \
  --add zfcp \
  --add dasd \
  --force-drivers "dm-multipath dm-service-time" \
  /boot/initramfs-$(uname -r).img $(uname -r)
```

**Key dracut modules for IBM Z:**
- `multipath` - Multipath support
- `lvm` - LVM support
- `dm` - Device mapper
- `cio` - Channel I/O (s390x specific)
- `zfcp` - FCP devices (Fibre Channel)
- `dasd` - DASD devices (if using DASD)

### Phase 9: Verification and Testing

Before rebooting, verify everything is configured correctly:

```bash
# Verify partition layout
fdisk -l /dev/mapper/mpathd

# Verify LVM configuration
pvs
vgs
lvs

# Verify filesystems
lsblk -f /dev/mapper/mpathd

# Verify fstab entries
cat /mnt/etc/fstab

# Verify zipl configuration
cat /etc/zipl.conf

# Verify initramfs includes multipath
lsinitrd /boot/initramfs-$(uname -r).img | grep multipath

# Verify multipath
multipath -ll
```

### Phase 10: Boot from New Disk

1. **Set boot order in BIOS/UEFI** to boot from new disk first
2. **Reboot the system**
3. **Monitor boot process** for any errors
4. **Verify system boots successfully**

```bash
# After reboot, verify you're on the new disk
df -h
lsblk
pvs
multipath -ll
```

### Phase 11: Test Multipath Failover

After successful boot, test multipath failover:

```bash
# Check current paths
multipath -ll

# Simulate path failure (be careful!)
echo 1 > /sys/block/sdX/device/delete

# Verify system continues to work
df -h
ls /

# Rescan to restore path
echo "- - -" > /sys/class/scsi_host/host0/scan

# Verify both paths are active again
multipath -ll
```

## Complete Example Workflow

Here's a complete example migrating from mpathb to mpathd:

```bash
# 1. Verify multipath
multipath -ll

# 2. Copy partition layout
sudo ./PVCopyParts/copy_partition_layout.sh /dev/mapper/mpathb /dev/mapper/mpathd

# 3. Migrate LVM volume groups
sudo ./VGmigrate/migrate_lvm_vg.sh /dev/mapper/mpathb3 /dev/mapper/mpathd3 rootvg
sudo ./VGmigrate/migrate_lvm_vg.sh /dev/mapper/mpathb4 /dev/mapper/mpathd4 datavg

# 4. Copy boot partition
dd if=/dev/mapper/mpathb1 of=/dev/mapper/mpathd1 bs=4M status=progress

# 5. Copy EFI partition (if UEFI)
dd if=/dev/mapper/mpathb2 of=/dev/mapper/mpathd2 bs=4M status=progress

# 6. Recreate swap
mkswap /dev/mapper/mpathd5

# 7. Update zipl bootloader (IBM Z)
mount /dev/mapper/mpathd3 /mnt
mount /dev/mapper/mpathd1 /mnt/boot
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt

# Configure dracut for multipath
cat > /etc/dracut.conf.d/multipath.conf << 'EOF'
add_dracutmodules+=" multipath "
add_drivers+=" dm-multipath dm-service-time "
install_items+=" /etc/multipath.conf "
EOF

# Rebuild initramfs with multipath support
dracut -f --add multipath --add lvm

# Update zipl configuration if needed
vi /etc/zipl.conf

# Install zipl bootloader
zipl -V

exit

# 8. Update fstab (if needed)
vi /mnt/etc/fstab

# 9. Unmount and reboot
umount /mnt/sys /mnt/proc /mnt/dev /mnt/boot /mnt
reboot
```

## Troubleshooting

### System Won't Boot

**Problem:** System fails to boot from new disk

**Solutions:**
1. Boot from rescue media or use IBM Z console
2. Verify zipl installation: `zipl -V`
3. Check zipl configuration: `cat /etc/zipl.conf`
4. Verify boot parameters include `rd.multipath=1`
5. Check fstab for correct UUIDs
6. Verify initramfs includes multipath modules: `lsinitrd | grep multipath`
7. Use IPL (Initial Program Load) from correct device

### Multipath Not Working

**Problem:** Multipath devices not recognized

**Solutions:**
```bash
# Reload multipath
systemctl restart multipathd

# Rescan SCSI bus
echo "- - -" > /sys/class/scsi_host/host0/scan

# Check multipath configuration
multipath -v3

# Verify multipath.conf
cat /etc/multipath.conf
```

### LVM Not Found

**Problem:** LVM volumes not accessible after boot

**Solutions:**
```bash
# Scan for volume groups
vgscan

# Activate volume groups
vgchange -ay

# Rebuild initramfs with LVM support
dracut -f --add lvm
```

### Wrong Root Device

**Problem:** System tries to boot from old disk

**Solutions:**
1. Update zipl configuration in `/etc/zipl.conf`
2. Verify `root=` parameter points to correct device
3. Ensure `rd.lvm.lv=` parameters are correct
4. Run `zipl -V` to apply changes
5. Check kernel command line: `cat /proc/cmdline` (after boot)

## Safety Checklist

Before starting migration:
- [ ] Complete backup of all data
- [ ] Verified source and target disks
- [ ] Confirmed multipath configuration
- [ ] Sufficient time allocated
- [ ] Tested rescue/recovery media
- [ ] Documented current configuration

During migration:
- [ ] Monitor disk space
- [ ] Check for errors in logs
- [ ] Verify each step completes successfully
- [ ] Keep log files for reference

After migration:
- [ ] System boots successfully
- [ ] All filesystems accessible
- [ ] LVM volumes working
- [ ] Multipath failover tested
- [ ] Applications running normally
- [ ] Old disk kept as backup (don't wipe immediately)

## Important Notes

⚠️ **WARNINGS:**
- Always backup your data before migration
- The migration can take several hours depending on data size
- Do not interrupt the migration process
- Ensure stable power supply during migration
- Test thoroughly before removing old disk
- Keep old disk as backup for at least a week

✅ **ADVANTAGES:**
- LVM migration is performed online (no downtime for data volumes)
- Multipath provides redundancy during migration
- Can be done in phases
- Reversible if old disk is kept

## Related Scripts

- `PVCopyParts/copy_partition_layout.sh` - Copies partition layout
- `VGmigrate/migrate_lvm_vg.sh` - Migrates LVM volume groups
- See respective README files for detailed documentation

## Additional Resources

- LVM documentation: `man lvm`, `man pvmove`
- Multipath documentation: `man multipath`, `man multipathd`
- zipl documentation: `man zipl`, `man zipl.conf`
- dracut documentation: `man dracut`, `man dracut.conf`
- IBM Z documentation: `/usr/share/doc/s390-tools/`
- System logs: `journalctl -xe`, `/var/log/messages`

## IBM Z Specific Considerations

### IPL (Initial Program Load)

On IBM Z, booting is called IPL. After migration:

1. **Update IPL device** in HMC (Hardware Management Console) or SE (Support Element)
2. **Load from correct device** using the device number
3. **Verify device configuration** with `lsdasd` or `lszfcp`

### Device Types on IBM Z

**DASD (Direct Access Storage Device):**
```bash
# List DASD devices
lsdasd

# Format DASD (if needed)
dasdfmt -b 4096 -d cdl -y /dev/dasda
```

**FCP/SCSI (Fibre Channel Protocol):**
```bash
# List FCP devices
lszfcp

# Configure FCP device
zfcp_host_configure 0.0.1234 1
zfcp_disk_configure 0.0.1234 0x5005076300c213e9 0x4000404600000000 1
```

### s390-tools Package

Ensure s390-tools is installed and up to date:
```bash
# RHEL/SLES
yum install s390utils
# or
zypper install s390-tools

# Verify zipl version
zipl --version
```

## Version History

- v1.1 (2026-03-31): Updated for IBM Z platform
  - Changed from GRUB to zipl bootloader
  - Added comprehensive dracut configuration
  - Added IBM Z specific considerations
  - Added IPL and device management sections
- v1.0 (2026-03-31): Initial comprehensive guide
  - Complete OS migration workflow
  - Multipath-specific considerations
  - Integration with existing scripts
  - Troubleshooting section

---

**Platform:** IBM Z (s390x) with Linux
**Bootloader:** zipl (z Initial Program Load)
**Author:** Created for Linux OS migration with multipath storage on IBM Z
**Last Updated:** 2026-03-31