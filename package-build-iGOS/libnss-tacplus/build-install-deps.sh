#!/bin/bash

set -ex

sudo apt-get install -y autoconf-archive libaudit-dev
sudo dpkg -i ../../libtacplus-map/libtacplus-map1_*.deb
sudo dpkg -i ../../libtacplus-map/libtacplus-map-dev_*.deb
sudo dpkg -i ../../libpam-tacplus/libtac2_*.deb
sudo dpkg -i ../../libpam-tacplus/libtac-dev_*.deb
sudo dpkg -i ../../libpam-tacplus/libpam-tacplus_*.deb
sudo dpkg -i ../../libpam-tacplus/libpam-tacplus-dev_*.deb
