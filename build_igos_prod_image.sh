#!/usr/bin/env bash
set -e

ROOTDIR=$(pwd)

. $ROOTDIR/.defs.mk

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
DATECODE=$(date +%Y%m%d%H%M%S00)

ISOPATH=$ROOTDIR/iso-images/$BUILDTYPE
ISOPATH_STAGE=$ROOTDIR/iso-images/$BUILDTYPE/stage_iso
IMAGEPATH=$ROOTDIR/images/$BUILDTYPE

BOOT3OFFSET=0
SPLOFFSET=0x800
UBOOTOFFSET=0x1800
BOOTIMGSIZE_MB=7

if [[ "$BUILDTYPE" == "bookworm-am64xx-evm" ]]; then
    UENVFILE="$ROOTDIR/updates/uEnv/uEnv-am64x-evm.txt"
elif [[ "$BUILDTYPE" == "bookworm-j7200-evm" ]]; then
    UENVFILE="$ROOTDIR/updates/uEnv/uEnv-j72x-evm.txt"
else
    UENVFILE="$ROOTDIR/updates/uEnv/uEnv-iolan.txt"
    SPLOFFSET=0x700
    UBOOTOFFSET=0x1000
    BOOTIMGSIZE_MB=4
fi

if [[ ! -d "$ISOPATH_STAGE" ]]; then
    echo "Error: missing iso staging directory: $ISOPATH_STAGE"
    exit 1
fi

IMG=$ROOTDIR/iso-images/$BUILDTYPE/igos-prod-${DATECODE}.img
BOOTIMG=$ROOTDIR/iso-images/$BUILDTYPE/igos-boot-${DATECODE}.img
SIZE=14G

WORKDIR=$ISOPATH/prod-work
ROOTFS=$WORKDIR/rootfs
UBOOTWORK=$WORKDIR/boot
MOUNT=$ROOTFS/mnt
MOUNT_P2=$ROOTFS/mnt/p3/boot/efi
MOUNT_P3=$ROOTFS/mnt/p3


cleanup() {
    echo "Cleaning up..."

    sudo umount -lf "$ROOTFS/mnt/iso" 2>/dev/null || true
    sudo umount -lf "$ROOTFS/dev" 2>/dev/null || true
    sudo umount -lf "$ROOTFS/proc" 2>/dev/null || true
    sudo umount -lf "$ROOTFS/sys" 2>/dev/null || true
    sudo umount -lf "$ROOTFS/run" 2>/dev/null || true
    sudo umount -lf "$MOUNT_P2" 2>/dev/null || true
    sudo umount -lf "$MOUNT_P3" 2>/dev/null || true
    sudo losetup -d "$LOOP" 2>/dev/null || true
    # cleanup the prod-work/rootfs and prod-work/boot work unsquashed directories
    sudo rm -rf $WORKDIR
}
trap cleanup EXIT

echo "Current pwd is ...${ROOTDIR}"
sudo mkdir -p $WORKDIR
sudo mkdir -p $ROOTFS

echo "Creating target partition p3 mount point ...${MOUNT_P3}"
sudo mkdir -p $MOUNT_P3

echo "Removing existing raw disk images ..."
files=$(find $ROOTDIR/iso-images/$BUILDTYPE -maxdepth 1 -type f -name "*.img")
if [ -n "$files" ]; then
    echo "Found .img files:"
    echo "$files"
    sudo find $ROOTDIR/iso-images/$BUILDTYPE -maxdepth 1 -type f -name "*.img" -delete
fi
sync

echo "Creating raw disk image..."
sudo truncate -s $SIZE "$IMG"

echo "Attaching loop device..."
LOOP=$(sudo losetup --show -fP "$IMG")

echo "Partitioning disk..."

sudo parted -s $LOOP mklabel gpt

# p1: U-Boot environment (RAW ~256KB)
sudo parted -s $LOOP mkpart UBOOT_ENV 1MiB 1.25MiB

# p2: EFI (FAT32)
sudo parted -s $LOOP mkpart EFI fat32 1.25MiB 513MiB
sudo parted -s $LOOP set 2 esp on

# p3: ROOT (EXT4)
sudo parted -s $LOOP mkpart ROOT ext4 513MiB 100%

sudo partprobe $LOOP
sleep 2

echo "Formatting filesystems..."

# DO NOT format p1 (raw env partition)

# Format EFI
sudo mkfs.vfat -n EFI ${LOOP}p2

# Format rootfs
sudo mkfs.ext4 -L persistence ${LOOP}p3

echo "Mounting target..."

# Mount root FIRST (now p3)
sudo mount ${LOOP}p3 "$MOUNT_P3"

# Create EFI mountpoint inside rootfs
sudo mkdir -p "$MOUNT_P2"

# Mount EFI (p2)
sudo mount ${LOOP}p2 "$MOUNT_P2"

# Copy any customized uEnv.txt file for uboot into vFAT EFI partition
echo "Copying uEnv file ${UENVFILE} to uEnv.txt in the EFI partition"
sudo cp $UENVFILE $MOUNT_P2/uEnv.txt

echo "Extracting root filesystem..."
  
if [[ ! -d "$ROOTFS" ]]; then
    echo "Removing existing rootfs staging directory: $ROOTFS"
    sudo rm -rf $ROOTFS
fi

sudo unsquashfs -f -d "$ROOTFS" "$ISOPATH_STAGE/live/filesystem.squashfs"

echo "Preparing to chroot..."

sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"
sudo mount --bind /run "$ROOTFS/run"

sudo mkdir -p "$ROOTFS/mnt/iso"
sudo mount --bind "$ISOPATH_STAGE" "$ROOTFS/mnt/iso"

echo "Running prod_image.py with GRUB target: $LOOP"
# sudo chroot "$ROOTFS" ls -l "$LOOP"
sudo chroot "$ROOTFS" python3 /usr/lib/python3/dist-packages/vyos/system/prod_image.py --grub-target "$LOOP"

echo "==========================================================================="
echo "Production firmware image build complete: $IMG"
echo "==========================================================================="

shopt -s nullglob
if [[ "$BUILDTYPE" == "bookworm-am64xx-evm" ]]; then
    set -- "$IMAGEPATH"/ti*-boot-emmc.squashfs
elif [[ "$BUILDTYPE" == "bookworm-j7200-evm" ]]; then
    set -- "$IMAGEPATH"/ti*-boot-emmc.squashfs
else
    set -- "$IMAGEPATH"/ti*-boot.squashfs
fi

if [[ ! -d "$IMAGEPATH" || $# -eq 0 ]]; then
    echo "Warning: no boot squash image found in: $IMAGEPATH"
else
    echo "Unsquashing boot squash image $1 found in: $IMAGEPATH"
    sudo unsquashfs -f -d "$UBOOTWORK" "$1"

    sudo dd if=/dev/zero of=$BOOTIMG bs=1M count=$BOOTIMGSIZE_MB    

    # tiboot3.bin
    sudo dd if=$UBOOTWORK/tiboot3.bin of=$BOOTIMG bs=512 seek=$BOOT3OFFSET conv=notrunc

    # tispl.bin
    sudo dd if=$UBOOTWORK/tispl.bin of=$BOOTIMG bs=512 seek=$(($SPLOFFSET)) conv=notrunc

    # u-boot.img
    sudo dd if=$UBOOTWORK/u-boot.img of=$BOOTIMG bs=512 seek=$(($UBOOTOFFSET)) conv=notrunc

    echo "==========================================================================="
    echo "Production boot image build complete: $BOOTIMG"
    echo "==========================================================================="
fi
shopt -u nullglob


