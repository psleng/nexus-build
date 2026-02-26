#!/bin/bash

DATECODE=$(date +%Y%m%d%H%M%S00)
ROOTDIR=$(pwd)

. $ROOTDIR/.defs.mk

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

    ISO_DIR=$ROOTDIR/build/tmp
    STAGE_ISO=$ROOTDIR/build/stage_iso
    # ISO_ROOTFS=$ROOTDIR/build/iso_rootfs
    ISOPATH_BUILD=$ROOTDIR/iso-images/$BUILDTYPE
    LIVE_IMAGE_ISO=vyos-build/build/live-image-$ARCH.hybrid.iso
    ROOTFS_PATTERN="tisdk-debian-$BUILDTYPE-*rootfs"
    ROOTFS=$(find build/$BUILDTYPE -type d -name "$ROOTFS_PATTERN" -print -quit)

    if [[ -z "$ROOTFS" ]]; then
        echo "Error: No rootfs path matches pattern: $ROOTFS_PATTERN"
        exit 1
    fi

    if [[ ! -d "$ROOTFS" ]]; then
        echo "Error: rootfs path does not exist: $ROOTFS"
        exit 1
    fi

    echo "ROOTFS path found: $ROOTFS"

    if [[ ! -d "$ROOTFS" ]]; then
        echo "Error: rootfs path does not exist: $ROOTFS"
        exit 1
    fi

    # Check ISO file exists
    if [ ! -e ${LIVE_IMAGE_ISO} ]; then
      echo "=== E: $0: File ${LIVE_IMAGE_ISO} does not exist."
      exit 1
    fi

    # create directories for staging the squashfs version of the image and the expanded iso image
    sudo rm -rf $STAGE_ISO
    sudo mkdir -p $STAGE_ISO
    sudo chmod u+w $STAGE_ISO
    # sudo rm -rf $ISO_ROOTFS
    # sudo mkdir -p $ISO_ROOTFS
    # sudo chmod u+w $ISO_ROOTFS

    ISOLOOP=$(sudo losetup --show -f ${LIVE_IMAGE_ISO})
    echo "Mounting iso on loopback: ${ISOLOOP}"

    sudo mkdir -p $ISO_DIR
    sudo mount -o ro ${ISOLOOP} $ISO_DIR
    # sudo unsquashfs -d $ISO_ROOTFS $ISO_DIR/live/filesystem.squashfs

    # copy entire iso from loop device to staging ISO including hidden files,
    # and then overlay the customized rootfs for $BUILDTYPE to staging area, preserving
    # all attrs, hidden, symlinks and remove original filesystem.squashfs in prep for updated one
    sudo cp -a $ISO_DIR/. $STAGE_ISO/
    # sudo cp -a $ROOTFS/* $ISO_ROOTFS/
    sudo rm -f $STAGE_ISO/live/filesystem.squashfs

    # copy the dtbs from built location to /boot/dtb for uboot to access this is different
    # than copying it WITHIN the /boot/dtb in the LINUX rootfs that install_image.py needs
    # to copy to another image's /boot/dtb that uboot needs to access
    sudo rm -rf $STAGE_ISO/boot/dtb
    sudo mkdir -p $STAGE_ISO/boot/dtb
    sudo cp -R $ROOTFS/usr/lib/linux-image*/ti $STAGE_ISO/boot/dtb

    SQUASHFILE=$STAGE_ISO/live/filesystem.squashfs
    # now we need to squash everthing back to the /live/filesystem.squashfs and zap the rest of the rootfs
    # except for what was in the original ISO
    # sudo mksquashfs $ISO_ROOTFS $SQUASHFILE -comp xz -b 262144 -always-use-fragments -noappend
    sudo mksquashfs $ROOTFS $SQUASHFILE -comp xz -b 262144 -always-use-fragments -noappend

    # we need to replace the sha256 checksum, in the live/sha256sum.txt as the last thing, otherwise
    # the "add system image <file.iso> will fail on checksum verificatiom
    SHA256TXTFILE=$STAGE_ISO/sha256sum.txt
    RELSQUASHFILE=./live/filesystem.squashfs

    # make the sha256sum.txt writeable
    sudo chmod u+w $SHA256TXTFILE

    # Calculate new hash
    NEWHASH=$(sha256sum "$SQUASHFILE" | awk '{print $1}')

    # Update the entry inside sha256sum.txt
    sudo sed -i "s|^[0-9a-f]\{64\}  $RELSQUASHFILE|$NEWHASH $RELSQUASHFILE|" "$SHA256TXTFILE"

    # make the sha256sum.txt non-writeable
    sudo chmod u-w $SHA256TXTFILE

    # Extract the kernel version from the initrd.img-* file (assuming it follows the pattern)
    KERNEL_VER=$(ls ${STAGE_ISO}/live/initrd.img-* | sed 's/.*initrd.img-\(.*\)/\1/' | head -n 1)

    echo "Creating initrd.img-${KERNEL_VER} and vmlinuz-${KERNEL_VER} symlinks"

    # Create the symlinks
    sudo ln -sf initrd.img-${KERNEL_VER} ${STAGE_ISO}/live/initrd.img
    sudo ln -sf vmlinuz-${KERNEL_VER} ${STAGE_ISO}/live/vmlinuz

    # cleanup the staging filesystem directory
    # sudo rm -rf $ISO_ROOTFS
    sudo rm -rf $ISOPATH_BUILD/stage_iso
    # sudo mkdir -p $ISOPATH_BUILD/stage_iso
    sudo mv $STAGE_ISO $ISOPATH_BUILD/stage_iso
    # sudo rm -rf $STAGE_ISO

    # housekeeping - remove vyos-build/build/vyos*.iso
    sudo rm -f vyos-build/build/vyos*.iso

    sudo umount -d $ISO_DIR
    sudo rmdir $ISO_DIR

    echo "=== I: $0: COMPLETED"

