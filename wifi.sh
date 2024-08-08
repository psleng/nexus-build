#!/bin/sh

sudo modprobe cfg80211
sudo insmod /lib/modules/nxp/mlan.ko
sudo insmod /lib/modules/nxp/moal.ko mod_para=/nxp/wifi_mod_para.conf [drvdbg=0x7]
sudo sudo iw phy mwiphy1 set name phy1
sudo sudo iw phy mwiphy0 set name phy0
