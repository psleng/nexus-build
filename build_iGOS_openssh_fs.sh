#!/bin/bash
set -ex

# Check if the --repo parameter is provided
if [ "$#" -lt 2 ] || [ "$1" != "--repo" ]; then
    echo "Usage: $0 --repo <repository_url> [--clean]"
    exit 1
fi

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

REPPREFIX_URL="$2"
REPO_URL_TI_DEB="$REPPREFIX_URL/debian-repos"
REPO_NAME="vyos-build"
REPO_URL="$REPPREFIX_URL/$REPO_NAME"
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
        sudo rm -rf "$REPO_NAME"
        rm -f .filesystem.* # Also remove all intermediate targets
    else
        echo "Repository $REPO_NAME already exists. Skipping clone."
    fi
fi

# Clone the repository if it doesn't exist or was cleaned
if [ ! -d "$REPO_NAME" ]; then
    git clone -b psl-master --single-branch "$REPO_URL"
#    git clone -b vyos-build-jf --single-branch "$REPO_URL"
fi

# Install build_flavor
cp -f $ROOTDIR/updates/arm64fs.toml $ROOTDIR/vyos-build/data/build-flavors/

############## package-build-iGOS
# This will build openssh-10.4 in ./vyos-build/scripts/package-build-iGOS/
TSK=package-build-openSSH
BLT=.filesystem.$TSK.built
OPENSSH="openssh-10.4"
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: package-build.py $TSK BEGIN"
    ./package-build.py --dir package-build-iGOS --include $OPENSSH
    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP package-build.py $TSK ($BLT exists)"
fi


echo "=== I: $0: COMPLETED"
