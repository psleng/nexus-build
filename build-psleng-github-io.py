#!/bin/bash

set -x
set -e

# Check if the --repo parameter is provided
if [ "$#" -lt 2 ] || [ "$1" != "--repo" ]; then
    echo "Usage: $0 --repo <repository_url> [--clean]"
    exit 1
fi

REPPREFIX_URL="$2/"
REPO_NAME="psleng.github.io"
REPO_URL="$2/$REPO_NAME"
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

# Clone the repository if it doesn't exist or was cleaned, and remove the existing repo binaries for adding new ones
if [ ! -d "$REPO_NAME" ]; then
    git clone -b main --single-branch "$REPO_URL"
    rm -rf $REPO_NAME/db; rm -rf $REPO_NAME/dists; rm -rf $REPO_NAME/pool
fi

# not needed because another script already moved to vyos-build/packages: copy everything to the package directory
#for a in $(find $ROOTDIR/vyos-build/scripts -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
#    sudo cp -f $a $ROOTDIR/vyos-build/packages/
#done

# copy everything to the package directory
for b in $(find $ROOTDIR/vyos-build/packages -type f -name "*.deb"); do
    echo "Adding package: $b to apt repo $REPO_NAME"
    reprepro -b $REPO_NAME includedeb bookworm $b
done

