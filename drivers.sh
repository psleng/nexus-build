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
date > drivers-build.out

rm -rf drivers
mkdir drivers

# should do this as Deb later
echo "Build/Install NXP 88Q9098/88W9098"

cd drivers
git clone https://github.com/psleng/mwifiex.git -b lf-6.6.3_1.0.0

cd mwifiex
git remote set-url origin git@github.com:psleng/mwifiex

git clone https://github.com/psleng/imx-firmware.git lf-6.6.3_1.0.0

cd mxm_wifiex/wlan_src
git remote set-url origin git@github.com:psleng/imx-firmware

make -C $ROOTDIR/vyos-build-tik/packages/linux-kernel/linux M=$PWD

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
#make -C $ROOTDIR/vyos-build-tik/packages/linux-kernel/linux M=$PWD
#mkdir -p $ROOTDIR/build/fs/lib/firmware/Simcom

cp -rf 60-Perle-usb-modem.rules $ROOTDIR/build/fs/etc/udev/rules.d/60-Perle-usb-modem.rules.rules

#  end time output
date >> drivers-build.out

