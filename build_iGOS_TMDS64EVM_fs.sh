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

# Install package scripts
cp -rf package-build-iGOS vyos-build/scripts/package-build-iGOS

# Find all .toml files in the package-build-iGOS directory and replace the URL
find vyos-build/scripts/package-build-iGOS -type f -name "*.toml" -exec sed -i "s|https://github.com/[^/]\+/|$REPPREFIX_URL|g" {} +

# Install build_flavor
cp -rf $ROOTDIR/updates/arm64fs.toml $ROOTDIR/vyos-build/data/build-flavors/arm64fs.toml


#frr build fix need to be fixed up later on it the build process
export EMAIL="johnlfeeney@gmail.com"

./package-build.py --dir package-build --include telegraf owamp frr strongswan openvpn-otp opennhrp aws-gwlbtun node_exporter

./package-build.py --dir package-build-iGOS --include vyos-1x vyatta-bash vyos-user-utils vyatta-biosdevname libvyosconfig \
vyatta-cfg vyos-http-api-tools vyos-utils ipaddrcheck udp-broadcast-relay hvinfo vyatta-wanloadbalance podman


# copy everything to the build directory
for a in $(find $ROOTDIR/vyos-build/scripts -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
    echo "Copying package: $a"
    cp -f $a $ROOTDIR/vyos-build/packages/
done

# this setion needs some rework to clean up how this ti firmware is pulled.
rm -rf debian-repos
git clone https://github.com/johnlfeeney/debian-repos
cd debian-repos

DEB_SUITE=bookworm ./run.sh ti-linux-firmware
cd ${ROOTDIR}
#find debian-repos/build/bookworm/ti-linux-firmware/ -type f | grep '\.deb$' | xargs -I {} cp {} build/
cp -rf debian-repos/build/bookworm/ti-linux-firmware/*64*.deb $ROOTDIR/vyos-build/packages/
# end of section for rework

cd $ROOTDIR/vyos-build

./build-vyos-image arm64fs --architecture arm64 --build-by "jfeeney@perle.com"

cd $ROOTDIR

# Check ISO file
LIVE_IMAGE_ISO=vyos-build/build/live-image-arm64.hybrid.iso

if [ ! -e ${LIVE_IMAGE_ISO} ]; then
  echo "File ${LIVE_IMAGE_ISO} not exists."
  exit -1
fi

ISOLOOP=$(losetup --show -f ${LIVE_IMAGE_ISO})
echo "Mounting iso on loopback: ${ISOLOOP}"

rm -rf build
mkdir build
mkdir build/tmp/

mount -o ro ${ISOLOOP} build/tmp/

unsquashfs -d build/fs build/tmp/live/filesystem.squashfs

#rm -rf build/fs/boot/grub
mkdir build/fs/boot/dtb

cp -R build/fs/usr/lib/linux-image*/ti build/fs/boot/dtb

# Temporary fix for DUID in vyos-1x until a more complete solution is thought about
cp -Rf $ROOTDIR/updates/vyos-router $ROOTDIR/build/fs/usr/libexec/vyos/init/vyos-router
# Temporary fix for console support until a more complete solution is thought about
cp -Rf $ROOTDIR/updates/system_console.py /$ROOTDIR/build/fs/usr/libexec/vyos/conf_mode/system_console.py

cat build/fs/boot/vmlinuz* | gunzip -d > build/fs/boot/Image

umount -d build/tmp/

