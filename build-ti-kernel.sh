#!/bin/bash

set -x
set -e
ROOTDIR=$(pwd)

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build-tik
rm -rf vyos-build
git clone -b current --single-branch https://github.com/psleng/vyos-build
#git clone -b sagitta --single-branch https://github.com/johnlfeeney/vyos-build

#KERNEL_BRANCH_NAME=v$(sed -n 's/^kernel_version = "\(.*\)"$/\1/p' vyos-build/data/defaults.toml)
KERNEL_BRANCH_NAME=v$(sed -n -e 's/^kernel_version = "\([^"]*\).*/\1/p' vyos-build/data/defaults.toml)
#KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_REPO="https://git.ti.com/git/ti-linux-kernel/ti-linux-kernel.git"
FW_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git

cd vyos-build/packages/linux-kernel/

echo "Build kernel for ti (${KERNEL_BRANCH_NAME})"
git clone ${KERNEL_REPO} -b ${KERNEL_BRANCH_NAME} --single-branch --depth=1 linux
cp ${ROOTDIR}/patches/ti_evm_vyos_defconfig arch/arm64/configs/vyos_defconfig
#patch -t -u arch/arm64/configs/vyos_defconfig < ${ROOTDIR}/patches/0001_bcm2711_defconfig.patch
./build-kernel.sh
git clone ${FW_REPO}
./build-linux-firmware.sh
git clone https://github.com/accel-ppp/accel-ppp.git
./build-accel-ppp.sh
git clone --depth=1 https://github.com/OpenVPN/ovpn-dco -b v0.2.20230426
./build-openvpn-dco.sh

cd ${ROOTDIR}
rm -rf build
mkdir -p build
find vyos-build/packages/linux-kernel/ -type f | grep '\.deb$' | xargs -I {} cp {} build/
mv vyos-build vyos-build-tik
