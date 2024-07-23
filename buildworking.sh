#!/bin/bash

set -x
set -e
ROOTDIR=$(pwd)

cd vyos-build
echo "Copy new default configuration to the vyos image"
#cp ${ROOTDIR}/config.boot.default data/live-build-config/includes.chroot/opt/vyatta/etc/config.boot.default
#cp ${ROOTDIR}/defaults.toml data/defaults.toml

# Build the image
#VYOS_BUILD_FLAVOR=data/generic-arm64.json
#./configure
#make iso
#./build-vyos-image iso --architecture arm64 --build-by "jfeeney@perle.com" --debug
./build-vyos-image iso --architecture arm64 --build-by "jfeeney@perle.com"
cd $ROOTDIR

# Check ISO file
LIVE_IMAGE_ISO=vyos-build/build/live-image-arm64.hybrid.iso

if [ ! -e ${LIVE_IMAGE_ISO} ]; then
  echo "File ${LIVE_IMAGE_ISO} not exists."
  exit -1
fi

ISOLOOP=$(losetup --show -f ${LIVE_IMAGE_ISO})
echo "Mounting iso on loopback: ${ISOLOOP}"

rm -rf build/tmp/
mkdir build/tmp/
mount -o ro ${ISOLOOP} build/tmp/

rm -rf build/fs
unsquashfs -d build/fs build/tmp/live/filesystem.squashfs

#rm -rf build/fs/boot/grub
mkdir build/fs/boot/dtb

cp -R build/fs/usr/lib/linux-image*/ti build/fs/boot/dtb

#rm -rf build/fs/boot/Image
cat build/fs/boot/vmlinuz* | gunzip -d > build/fs/boot/Image

umount -d build/tmp/
#losetup -d ${ISOLOOP}

# Build u-boot
#bash build-u-boot.sh

# Generate CM4 image from the iso
#DEVTREE="bcm2711-rpi-cm4" PIVERSION=4 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Generate PI4 image from the iso
#DEVTREE="bcm2711-rpi-4-b" PIVERSION=4 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Generate PI3B image from the iso
#DEVTREE="bcm2710-rpi-3-b" PIVERSION=3 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Generate PI3B+ image from the iso
#DEVTREE="bcm2710-rpi-3-b-plus" PIVERSION=3 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Symlink pi4 image
#ln -s vyos-build/build/live-image-arm64.hybrid.img live-image-arm64.hybrid.img
