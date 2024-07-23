#!/bin/bash

set -x
set -e
ROOTDIR=$(pwd)

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build
git clone -b current --single-branch https://github.com/johnlfeeney/vyos-build
#git clone -b sagitta --single-branch https://github.com/johnlfeeney/vyos-build

# fixing up issue with iso for arm builds
cp -rf iso.toml vyos-build/data/build-flavors/iso.toml

#if [ ! -f build/telegraf*.deb ]; then
	pushd vyos-build/packages/telegraf
# 1.28.3 from Jenkins File - does not exist prebuild as deb on arm so must build it
	git clone https://github.com/influxdata/telegraf.git -b v1.28.3 telegraf
	bash -x ./build.sh
	popd
	mkdir -p build
	cp -rf vyos-build/packages/telegraf/telegraf/build/dist/telegraf_1.28.3-1_arm64.deb build/
#fi

#if [ ! -f build/owamp*.deb ]; then
	pushd vyos-build/packages/owamp
# 4.4.6 from Jenkins File - does not exist prebuild as deb on arm so must build it
	git clone https://github.com/perfsonar/owamp -b v4.4.6 owamp
	bash -x ./build.sh
	popd
	mkdir -p build
	cp -rf vyos-build/packages/owamp/owamp-server_4.4.6-1_arm64.deb build/
	cp -rf vyos-build/packages/owamp/twamp-server_4.4.6-1_arm64.deb build/
	cp -rf vyos-build/packages/owamp/owamp-client_4.4.6-1_arm64.deb build/
	cp -rf vyos-build/packages/owamp/twamp-client_4.4.6-1_arm64.deb build/
#fi

for a in $(find build -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
	echo "Copying package: $a"
	cp $a vyos-build/packages/
done


cd vyos-build/packages/strongswan
git clone https://github.com/johnlfeeney/vyos-strongswan.git -b current strongswan

# this patch is to solve a newer compiler error, it is fixed in newer versions of strongswan
cp $ROOTDIR/swanctl.h strongswan/src/swanctl/swanctl.h

cd strongswan
# dpkg-buildpackage -uc -us -tc -b
dpkg-buildpackage -uc -us -b

# the following is to build a version of vici for debian, some is described in the vyos packages documentation but the following three lines generate needed files. Check if all are required
./configure --enable-python-eggs
cd src/libcharon/plugins/vici/python
make
python3 setup.py --command-packages=stdeb.command bdist_deb
cd $ROOTDIR/vyos-build/packages
cp -rf strongswan/strongswan/src/libcharon/plugins/vici/python/deb_dist/python3-vici_5.7.2-1_all.deb python3-vici_5.7.2-1_all.deb

git clone https://github.com/johnlfeeney/vyos-1x -b current
cd vyos-1x
dpkg-buildpackage -uc -us -tc -b

git clone https://github.com/johnlfeeney/vyos-user-utils -b current
cd vyos-user-utils
dpkg-buildpackage -uc -us -tc -b

cd ..


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

echo "Copy new default configuration to the vyos image"
cp -rf ${ROOTDIR}/config.boot.default ${ROOTDIR}/fs/usr/share/vyos/config.boot.default

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
