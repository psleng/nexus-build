#!/bin/bash

set -x
set -e
ROOTDIR=$(pwd)

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build-tik
rm -rf vyos-build
git clone -b current --single-branch https://github.com/johnlfeeney/vyos-build
#git clone -b sagitta --single-branch https://github.com/johnlfeeney/vyos-build

#KERNEL_BRANCH_NAME=v$(sed -n 's/^kernel_version = "\(.*\)"$/\1/p' vyos-build/data/defaults.toml)
KERNEL_BRANCH_NAME=v$(sed -n -e 's/^kernel_version = "\([^"]*\).*/\1/p' vyos-build/data/defaults.toml)
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
#KERNEL_REPO="https://git.ti.com/git/ti-linux-kernel/ti-linux-kernel.git"
FW_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
#FW_REPO=https://git.ti.com/git/processor-firmware/ti-linux-firmware.git
FW_BRANCH_NAME=ti-linux-firmware
cd vyos-build/packages/linux-kernel/

echo "Build kernel for ti (${KERNEL_BRANCH_NAME})"
git clone ${KERNEL_REPO} -b ${KERNEL_BRANCH_NAME} --single-branch --depth=1 linux
cp ${ROOTDIR}/patches/ti_evm_vyos_defconfig arch/arm64/configs/vyos_defconfig
#patch -t -u arch/arm64/configs/vyos_defconfig < ${ROOTDIR}/patches/0001_bcm2711_defconfig.patch

#cp ${ROOTDIR}/build-kernel-arm.sh build-kernel-arm.sh
#./build-kernel-arm.sh
./build-kernel.sh 

#git clone ${FW_REPO} -b ${FW_BRANCH_NAME} linux-firmware
#./build-linux-firmware.sh

git clone https://github.com/accel-ppp/accel-ppp.git
./build-accel-ppp.sh

# v0.2.20231117 from Jenkins file
git clone --depth=1 https://github.com/OpenVPN/ovpn-dco -b v0.2.20231117
./build-openvpn-dco.sh

./build-jool.py

cd ${ROOTDIR}
rm -rf build
mkdir -p build
find vyos-build/packages/linux-kernel/ -type f | grep '\.deb$' | xargs -I {} cp {} build/
mv vyos-build vyos-build-tik

rm -rf debian-repos
git clone https://github.com/johnlfeeney/debian-repos
cd debian-repos
#rm -rf build
DEB_SUITE=bookworm ./run.sh ti-linux-firmware
cd ${ROOTDIR}
#find debian-repos/build/bookworm/ti-linux-firmware/ -type f | grep '\.deb$' | xargs -I {} cp {} build/
cp -rf debian-repos/build/bookworm/ti-linux-firmware/*64*.deb build/
