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

    # run GPG commands and signature kernel, initrd and dtb files
    export GPG_USER_ID="perle@perle.com"
    export PASSPHRASE_FILE="$ROOTDIR/gpgkeys/perle-passphrase.txt"

    sudo gpg --import $ROOTDIR/gpgkeys/perle.pubkey.bin
    sudo gpg --batch --yes --pinentry-mode loopback --passphrase-file $PASSPHRASE_FILE --import "$ROOTDIR/gpgkeys/perle.privatekey.bin"

    # copy the dtbs from built location to /boot/dtb for uboot to access this is different
    # than copying it WITHIN the /boot/dtb in the LINUX rootfs that install_image.py needs
    # to copy to another image's /boot/dtb that uboot needs to access
    sudo rm -rf $STAGE_ISO/boot/dtb
    sudo mkdir -p $STAGE_ISO/boot/dtb
    sudo cp -R $ROOTFS/boot/dtb/* $STAGE_ISO/boot/dtb
    sudo cp -R $ROOTFS/boot/vmlinuz* $STAGE_ISO/live/
    sudo cp -R $ROOTFS/boot/initrd* $STAGE_ISO/live/

    # Extract the kernel version from the initrd.img-* file (assuming it follows the pattern)
    KERNEL_VER=$(ls ${STAGE_ISO}/live/initrd.img-* | sed 's/.*initrd.img-\(.*\)/\1/' | head -n 1)

    # Decompress the vmlinuz into vmlinux
    # gunzip < ${STAGE_ISO}/live/vmlinuz-${KERNEL_VER} | sudo sh -c "cat > ${STAGE_ISO}/live/vmlinux-${KERNEL_VER}"

    echo "Creating initrd.img-${KERNEL_VER}, vmlinuz-${KERNEL_VER}  and vmlinux-${KERNEL_VER} symlinks"

    # Create the symlinks
    sudo ln -sf initrd.img-${KERNEL_VER} ${STAGE_ISO}/live/initrd.img
    sudo ln -sf vmlinuz-${KERNEL_VER} ${STAGE_ISO}/live/vmlinuz
    # sudo ln -sf vmlinux-${KERNEL_VER} ${STAGE_ISO}/live/vmlinux

    cd $STAGE_ISO/live
    # Loop through all initrd and vmlinuz in current directory
    for file in initrd.img-*-vyos; do
        sudo gpg --batch --verbose --detach-sign --pinentry-mode loopback \
                 --passphrase-file $PASSPHRASE_FILE -u $GPG_USER_ID $file
        sudo cp initrd.img-*-vyos.sig initrd.img.sig
    done
    for file in vmlinuz-*-vyos; do
        sudo gpg --batch --verbose --detach-sign --pinentry-mode loopback \
                 --passphrase-file $PASSPHRASE_FILE -u $GPG_USER_ID $file
        sudo cp vmlinuz-*-vyos.sig vmlinuz.sig
    done

    # for file in vmlinux-*-vyos; do
    #     sudo gpg --batch --verbose --detach-sign --pinentry-mode loopback \
    #              --passphrase-file $PASSPHRASE_FILE -u $GPG_USER_ID $file
    #     sudo cp vmlinux-*-vyos.sig vmlinux.sig
    # done

    # Loop through all grub *.mod files n  directory
    cd $STAGE_ISO/boot/grub/arm64-efi/
    for file in *.mod; do
        sudo gpg --batch --verbose --detach-sign --pinentry-mode loopback \
                 --passphrase-file $PASSPHRASE_FILE -u $GPG_USER_ID $file
    done

    cd $STAGE_ISO/boot/dtb/perle/
    # Loop through all dtbs in current directory
    # Create symlinks
    for file in *.dtb; do
        if [[ $file =~ ^.*-(IOLAN|IRG)-(.*\.dtb)$ ]]; then
            linkname="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"

            sudo ln -sf -- "$file" "$linkname"
            echo "$linkname -> $file"
        fi
    done

    # Sign the symlinks
    for file in IOLAN-*.dtb IRG-*.dtb; do
        [[ -e "$file" ]] || continue

        sudo gpg --batch --verbose --detach-sign --pinentry-mode loopback \
            --passphrase-file "$PASSPHRASE_FILE" -u "$GPG_USER_ID" "$file"
    done

    cd $ROOTDIR

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

    # cleanup the staging filesystem directory
    # sudo rm -rf $ISO_ROOTFS
    if [[ ! -d "$ISOPATH_BUILD" ]]; then
       sudo mkdir -p $ISOPATH_BUILD
    fi
    sudo rm -rf $ISOPATH_BUILD/stage_iso
    sudo mv $STAGE_ISO $ISOPATH_BUILD/stage_iso
    sudo rm -rf $STAGE_ISO

    # housekeeping - remove vyos-build/build/vyos*.iso
    sudo rm -f vyos-build/build/vyos*.iso

    sudo umount -d $ISO_DIR
    sudo rmdir $ISO_DIR

    echo "=== I: $0: COMPLETED"

