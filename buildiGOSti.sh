#!/bin/sh
#
# Build iGOS TI image
#

TI=ti-bdebstrap
if [ ! -d $TI ]; then
    echo "I: Cloning $TI"
    # Get the latest.  The older x86/qemu code was mostly based on the tag
    # '10.00.07-release' (and 'psl-x86-qemu-20241202')
    git clone -b nxp-imx8dxl https://github.com/psleng/$TI.git
    if [ $? != 0 ]; then
        echo "E: Cloning failed!"
        exit 1
    fi
fi

# Set up links to TI files and do some modifications
$TI/PSL-mklinks $(pwd) || { exit $?; }

exec sudo $TI/buildiGOSti2.sh "$@"
