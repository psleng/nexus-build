#!/bin/bash

set -x
set -e
ROOTDIR=$(pwd)

echo "ROOTDIR=${ROOTDIR}"

# start time output
date > kernel-build.out

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build-tik
rm -rf vyos-build
git clone -b current --single-branch https://github.com/psleng/vyos-build
cd vyos-build
git remote set-url origin git@github.com:psleng/vyos-build
cd ..
#KERNEL_BRANCH_NAME=v$(sed -n 's/^kernel_version = "\(.*\)"$/\1/p' vyos-build/data/defaults.toml)
KERNEL_BRANCH_NAME=v$(sed -n -e 's/^kernel_version = "\([^"]*\).*/\1/p' vyos-build/data/defaults.toml)
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
#KERNEL_REPO="https://git.ti.com/git/ti-linux-kernel/ti-linux-kernel.git"
#FW_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
#FW_REPO=https://git.ti.com/git/processor-firmware/ti-linux-firmware.git
#FW_BRANCH_NAME=ti-linux-firmware
#cd vyos-build/packages/linux-kernel/
cd vyos-build/scripts/package-build/linux-kernel

echo "Build kernel for ti (${KERNEL_BRANCH_NAME})"
git clone ${KERNEL_REPO} -b ${KERNEL_BRANCH_NAME} --single-branch --depth=1 linux
cp ${ROOTDIR}/patches/ti_evm_vyos_defconfig linux/arch/arm64/configs/vyos_defconfig
#patch -t -u arch/arm64/configs/vyos_defconfig < ${ROOTDIR}/patches/0001_bcm2711_defconfig.patch

# substitute ti-linux-kernel definitions
#rm -rf ${ROOTDIR}/vyos-build/packages/linux-kernel/linux/arch/arm64/boot/dts/ti
#cp -rf ${ROOTDIR}/ti ${ROOTDIR}/vyos-build/packages/linux-kernel/linux/arch/arm64/boot/dts/ti
rm -rf ${ROOTDIR}/vyos-build/scripts/package-build/linux-kernel/linux/arch/arm64/boot/dts/ti
cp -rf ${ROOTDIR}/ti ${ROOTDIR}/vyos-build/scripts/package-build/linux-kernel/linux/arch/arm64/boot/dts/ti

#cp ${ROOTDIR}/build-kernel-arm.sh build-kernel-arm.sh
#./build-kernel-arm.sh
./build-kernel.sh

#git clone ${FW_REPO} -b ${FW_BRANCH_NAME} linux-firmware
#  20240610 from Jenkins file
git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git -b 20240610
./build-linux-firmware.sh

# 1.13.0 from Jenkins file
git clone https://github.com/psleng/accel-ppp.git
cd accel-ppp
git remote set-url origin git@github.com:psleng/accel-ppp.git
git checkout 1.13.0
cd ..
./build-accel-ppp.sh

# v0.2.20231117 from Jenkins file
git clone --depth=1 https://github.com/psleng/ovpn-dco -b v0.2.20231117
cd ovpn-dco
git remote set-url origin git@github.com:psleng/ovpn-dco
cd ..
./build-openvpn-dco.sh

# 475af0a  from Jenkins file
git clone https://github.com/psleng/rtsp-linux.git nat-rtsp
cd nat-rtsp
git remote set-url origin git@github.com:psleng/rtsp-linux
git checkout 475af0a
cd ..
./build-nat-rtsp.sh

./build-jool.py

cd ${ROOTDIR}
rm -rf build
mkdir -p build
find vyos-build/packages/linux-kernel/ -type f | grep '\.deb$' | xargs -I {} cp {} build/
mv vyos-build vyos-build-tik

rm -rf debian-repos
git clone https://github.com/psleng/debian-repos
cd debian-repos
git remote set-url origin git@github.com:psleng/debian-repos
#rm -rf build
DEB_SUITE=bookworm ./run.sh ti-linux-firmware
cd ${ROOTDIR}
#find debian-repos/build/bookworm/ti-linux-firmware/ -type f | grep '\.deb$' | xargs -I {} cp {} build/
cp -rf debian-repos/build/bookworm/ti-linux-firmware/*64*.deb build/

# end time output
date >> kernel-build.out

