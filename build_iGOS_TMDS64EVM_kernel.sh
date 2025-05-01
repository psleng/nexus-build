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
    git clone --single-branch "$REPO_URL"
fi

cp -rf ${ROOTDIR}/0005* ${ROOTDIR}/${REPO_NAME}/scripts/package-build/linux-kernel/patches/kernel
rm -f ${ROOTDIR}/${REPO_NAME}/scripts/package-build/linux-kernel/platform/ti-evm/bookworm-am64xx-evm/patches/kernel/*

# Make Kernel and associated packages
./package-build.py --dir package-build --include linux-kernel
