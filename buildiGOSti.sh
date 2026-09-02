#!/bin/sh
#
# Build iGOS TI image
#

TI=ti-bdebstrap
TI_HOME="${HOME}/ti-bdebstrap"

# Canonical location for TI build artifacts/repo is ~/ti-bdebstrap
if [ ! -d "$TI_HOME" ]; then
    echo "I: Cloning $TI_HOME"
    # Get the latest.  The older x86/qemu code was mostly based on the tag
    # '10.00.07-release' (and 'psl-x86-qemu-20241202')
    #git clone https://github.com/psleng/$TI.git
    git clone -b ti-bdebstrap-jf --single-branch https://github.com/psleng/$TI.git "$TI_HOME"
    if [ $? != 0 ]; then
        echo "E: Cloning failed!"
        exit 1
    fi
fi

# Keep backward-compatible local path when possible.
if [ ! -e "$TI" ]; then
    ln -s "$TI_HOME" "$TI"
fi

# Ensure ti-bdebstrap uses the active build selection from this nexus-build tree.
if [ -f .defs.mk ]; then
    ln -sfn "$(pwd)/.defs.mk" "$TI_HOME/.defs.mk"
fi

# Set up links to TI files and do some modifications
"$TI_HOME"/PSL-mklinks $(pwd) || { exit $?; }

#exec sudo "$TI_HOME"/buildiGOSti2.sh "$@"
exec sudo KEEP_BSP_SOURCES=1 "$TI_HOME"/buildiGOSti2.sh "$@"
