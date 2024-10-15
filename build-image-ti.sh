#!/bin/bash
if test $(hostname) != 'vyos-build'; then
    echo 'This script must be run from within the vyos-build container:'
    echo '	./rundocker.sh'
    exit 1
fi
if test $(id -u) != 0; then
    echo 'This script must be run via sudo'
    exit 1
fi

set -xe
ROOTDIR=$(pwd)

# start time output
date > vyos-build.out

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build
git clone -b current --single-branch https://github.com/psleng/vyos-build
cd vyos-build
git remote set-url origin git@github.com:psleng/vyos-build
cd ..

# fixing up issue with iso for arm builds
cp -rf iso.toml vyos-build/data/build-flavors/iso.toml

#if [ ! -f build/telegraf*.deb ]; then
	pushd vyos-build/scripts/package-build/telegraf
# 1.28.3 from Jenkins File - does not exist prebuild as deb on arm so must build it
	git clone https://github.com/psleng/telegraf.git -b v1.28.3 telegraf
	cd telegraf
	git remote set-url origin git@github.com:psleng/telegraf
	cd ..
#	bash -x ./build.sh
	./build.py
	popd
	mkdir -p build
	cp -rf vyos-build/scripts/package-build/telegraf/telegraf/build/dist/telegraf_1.28.3-1_arm64.deb build/
#fi

#if [ ! -f build/owamp*.deb ]; then
	pushd vyos-build/scripts/package-build/owamp
# 4.4.6 from Jenkins File - does not exist prebuild as deb on arm so must build it
	git clone https://github.com/psleng/owamp -b v4.4.6 owamp
	cd owamp
	git remote set-url origin git@github.com:psleng/owamp
	cd ..
#	bash -x ./build.sh
	./build.py
	popd
	mkdir -p build
	cp -rf vyos-build/scripts/package-build/owamp/owamp-server_4.4.6-1_arm64.deb build/
	cp -rf vyos-build/scripts/package-build/owamp/twamp-server_4.4.6-1_arm64.deb build/
	cp -rf vyos-build/scripts/package-build/owamp/owamp-client_4.4.6-1_arm64.deb build/
	cp -rf vyos-build/scripts/package-build/owamp/twamp-client_4.4.6-1_arm64.deb build/
#fi

for a in $(find build -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
	echo "Copying package: $a"
	cp $a vyos-build/scripts/package-build/
done

#frr and Dependencies
export EMAIL="psleng@gmail.com"
cd $ROOTDIR/vyos-build/scripts/package-build/frr
git clone https://github.com/psleng/rtrlib.git
cd rtrlib
git checkout v0.8.0
git remote set-url origin git@github.com:psleng/rtrlib
mk-build-deps --install --tool "apt-get --yes --no-install-recommends"
dpkg-buildpackage -uc -us -tc -b
#dpkg -i ../librtr0*_${ARCH}.deb ../librtr-dev*_${ARCH}.deb ../rtr-tools*_${ARCH}.deb
cd $ROOTDIR/vyos-build/scripts/package-build/frr
git clone https://github.com/psleng/libyang.git
cd libyang
git checkout v2.1.148
git remote set-url origin git@github.com:psleng/libyang
pipx run apkg build -i && find pkg/pkgs -type f -name *.deb -exec mv -t .. {} +
cd ..
#dpkg -i *.deb
#dpkg -i ../libyang*.deb
cd $ROOTDIR/vyos-build/scripts/package-build/frr
git clone https://github.com/psleng/frr.git
cd frr
git checkout stable/9.1
git remote set-url origin git@github.com:psleng/frr
#dpkg -i ../*.deb; mk-build-deps --install --tool "apt-get --yes --no-install-recommends"; cd ..; ./build-frr.sh
dpkg -i ../*.deb; mk-build-deps --install --tool "apt-get --yes --no-install-recommends"; cd ..; ./build.py
cp -rf *.deb ..
# frr end

cd $ROOTDIR/vyos-build/scripts/package-build/strongswan
git clone https://github.com/psleng/vyos-strongswan.git -b current strongswan

# this patch is to solve a newer compiler error, it is fixed in newer versions of strongswan
cp $ROOTDIR/swanctl.h strongswan/src/swanctl/swanctl.h

cd strongswan
git remote set-url origin git@github.com:psleng/vyos-strongswan
# dpkg-buildpackage -uc -us -tc -b
dpkg-buildpackage -uc -us -b

# the following is to build a version of vici for debian, some is described in the vyos packages documentation but the following three lines generate needed files. Check if all are required
./configure --enable-python-eggs
cd src/libcharon/plugins/vici/python
make
python3 setup.py --command-packages=stdeb.command bdist_deb
cd $ROOTDIR/vyos-build/scripts/package-build
cp -rf strongswan/strongswan/src/libcharon/plugins/vici/python/deb_dist/python3-vici_5.7.2-1_all.deb python3-vici_5.7.2-1_all.deb

git clone https://github.com/psleng/vyos-1x -b current
# Fix to make console start
cp -rf $ROOTDIR/psleng/fixups/system_console.py $ROOTDIR/vyos-build/scripts/package-build/vyos-1x/src/conf_mode/system_console.py
# Temporary fix for DUID until a more complete solution is thought about
cp -rf $ROOTDIR/psleng/fixups/vyos-router $ROOTDIR/vyos-build/scripts/package-build/vyos-1x/src/init/vyos-router
# Temporarily disable smoketests failing the build for arm64
# cp -rf $ROOTDIR/psleng/fixups/Makefile $ROOTDIR/vyos-build/
cd vyos-1x
git remote set-url origin git@github.com:psleng/vyos-1x
dpkg-buildpackage -uc -us -tc -b

cd $ROOTDIR/vyos-build/scripts/package-build

git clone https://github.com/psleng/vyos-user-utils -b current
cd vyos-user-utils
git remote set-url origin git@github.com:psleng/vyos-user-utils
dpkg-buildpackage -uc -us -tc -b

cd $ROOTDIR/vyos-build/scripts/package-build

git clone https://github.com/psleng/vyatta-bash -b current
cd vyatta-bash
git remote set-url origin git@github.com:psleng/vyatta-bash
dpkg-buildpackage -uc -us -tc -b

cd $ROOTDIR/vyos-build


#cp ${ROOTDIR}/defaults.toml data/defaults.toml

# Build the image
#VYOS_BUILD_FLAVOR=data/generic-arm64.json
#./configure
#make iso
#./build-vyos-image iso --architecture arm64 --build-by "psleng@perle.com" --debug
./build-vyos-image iso --architecture arm64 --build-by "psleng@perle.com"
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

#echo "Copy new default configuration to the vyos image"
#cp -rf ${ROOTDIR}/config.boot.default ${ROOTDIR}/build/fs/usr/share/vyos/config.boot.default

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

# end time output
date >> vyos-build.out

