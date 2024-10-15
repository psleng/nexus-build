#!/bin/bash

set -x
set -e

# Initialize repository URL variable
REPO_URL=""

# Parse input parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) REPO_URL="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if REPO_URL is empty
if [ -z "$REPO_URL" ]; then
    echo "Error: --repo parameter is required."
    exit 1
fi

ROOTDIR=$(pwd)

rm -rf drivers
mkdir drivers

# should do this as Deb later
echo "Build/Install NXP 88Q9098/88W9098"

cd drivers
git clone ${REPO_URL}/mwifiex.git -b lf-6.6.3_1.0.0

cd mwifiex
git clone ${REPO_URL}/imx-firmware.git lf-6.6.3_1.0.0

cd mxm_wifiex/wlan_src
make -C $ROOTDIR/vyos-build/scripts/package-build/linux-kernel/linux M=$PWD

cd $ROOTDIR
mkdir -p $ROOTDIR/build/fs/lib/modules/nxp
cp -rf drivers/mwifiex/mxm_wifiex/wlan_src/*.ko $ROOTDIR/build/fs/lib/modules/nxp/
cp -rfp wifi.sh $ROOTDIR/build/fs/lib/modules/nxp/wifi.sh

mkdir -p $ROOTDIR/build/fs/lib/firmware/nxp
cp -rf drivers/mwifiex/lf-6.6.3_1.0.0/nxp/FwImage_9098_PCIE/*.bin $ROOTDIR/build/fs/lib/firmware/nxp/
cp -rf drivers/mwifiex/lf-6.6.3_1.0.0/nxp/wifi_mod_para.conf $ROOTDIR/build/fs/lib/firmware/nxp/wifi_mod_para.conf
cp -rf 99-default.link $ROOTDIR/build/fs/etc/systemd/network/99-default.link
cp -rf 60-Perle-pcie-card-nxp9098.rules $ROOTDIR/build/fs/etc/udev/rules.d/60-Perle-pcie-card-nxp9098.rules

#cd $ROOTDIR/drivers
#wget https://files.waveshare.com/upload/4/46/Simcom_wwan.zip
#unzip Simcom_wwan.zip
#cd simcom_wwan
#make -C $ROOTDIR/vyos-build/scripts/package-build/linux-kernel/linux M=$PWD
#mkdir -p $ROOTDIR/build/fs/lib/firmware/Simcom

cp -rf 60-Perle-usb-modem.rules $ROOTDIR/build/fs/etc/udev/rules.d/60-Perle-usb-modem.rules.rules
