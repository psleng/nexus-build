#!/bin/bash

set -x
set -e

# Check if the --repo parameter is provided
if [ "$#" -lt 2 ] || [ "$1" != "--repo" ]; then
    echo "Usage: $0 --repo <repository_url> [--clean]"
    exit 1
fi

REPPREFIX_URL="$2/"
REPO_URL="$2/vyos-build"
REPO_NAME="vyos-build"
ROOTDIR=$(pwd)

# Check if the --clean parameter is provided
CLEAN=false
if [ "$#" -eq 3 ] && [ "$3" == "--clean" ]; then
    CLEAN=true
fi

# Delete the repository if it already exists and --clean is specified
if [ -d "$REPO_NAME" ]; then
    if [ "$CLEAN" = true ]; then
        echo "Cleaning up existing repository $REPO_NAME."
        rm -rf "$REPO_NAME"
    else
        echo "Repository $REPO_NAME already exists. Skipping clone."
    fi
fi

# Clone the repository if it doesn't exist or was cleaned
if [ ! -d "$REPO_NAME" ]; then
    git clone -b current --single-branch "$REPO_URL"
fi


# Copy all custom packages
cp -rf ${ROOTDIR}/patches/ti_evm_vyos_defconfig ${ROOTDIR}/${REPO_NAME}/scripts/package-build/linux-kernel/arch/arm64/configs/vyos_defconfig
cp -rf ${ROOTDIR}/build-kernel.sh ${ROOTDIR}/${REPO_NAME}/scripts/package-build/linux-kernel/build-kernel.sh

# Make Kernel and associated packages
./package-build.py --dir package-build --include linux-kernel


