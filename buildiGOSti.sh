#!/bin/sh
#
# Build iGOS TI image
#

TI=ti-bdebstrap
if [ ! -d $TI ]; then
    echo "I: Cloning $TI"
    set -e
    git clone https://github.com/psleng/$TI.git
    set +e
fi

# Set up links to TI files and do some modifications
$TI/PSL-mklinks $(pwd) || { exit $?; }

exec sudo $TI/buildiGOSti2.sh "$@"
