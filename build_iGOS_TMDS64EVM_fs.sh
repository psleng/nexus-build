#!/bin/bash
# TODO only a few things need to run as root; these should be sudo's instead
test $(id -u) = 0 || { echo "$0: This must be run as root"; exit 1; }

set -x
set -e

# Check if the --repo parameter is provided
if [ "$#" -lt 2 ] || [ "$1" != "--repo" ]; then
    echo "Usage: $0 --repo <repository_url> [--clean]"
    exit 1
fi

REPPREFIX_URL="$2/"
REPO_URL_TI_DEB="$2/debian-repos"
REPO_NAME="vyos-build"
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
        rm -f .filesystem.* # Also remove all intermediate targets
    else
        echo "Repository $REPO_NAME already exists. Skipping clone."
    fi
fi

# Clone the repository if it doesn't exist or was cleaned
if [ ! -d "$REPO_NAME" ]; then
    git clone -b psl-master --single-branch "$REPO_URL"
fi

# Install package scripts directory
if [ ! -d "vyos-build/scripts/package-build-iGOS" ]; then
    cp -rf package-build-iGOS vyos-build/scripts/
    # Find all .toml files in the package-build-iGOS directory and replace the URL
    echo "=== I: $0: rewriting .toml files BEGIN"
    find vyos-build/scripts/package-build-iGOS -type f -name "*.toml" -exec sed -i "s|https://github.com/[^/]\+/|$REPPREFIX_URL|g" {} +
fi

# Install build_flavor
cp -f $ROOTDIR/updates/arm64fs.toml $ROOTDIR/vyos-build/data/build-flavors/

#frr build fix need to be fixed up later on it the build process
export EMAIL="psleng@perle.com"

############## package-build
# This will populate ./vyos-build/scripts/package-build/
TSK=package-build
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: package-build.py $TSK BEGIN"
    ./package-build.py --dir $TSK --include telegraf owamp frr strongswan openvpn-otp opennhrp aws-gwlbtun node_exporter podman
    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP package-build.py $TSK ($BLT exists)"
fi


############## package-build-iGOS
# This will populate ./vyos-build/scripts/package-build-iGOS/
TSK=package-build-iGOS
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: package-build.py $TSK BEGIN"
    ./package-build.py --dir $TSK --include vyos-1x vyatta-bash vyos-user-utils vyatta-biosdevname libvyosconfig \
    vyatta-cfg vyos-http-api-tools vyos-utils ipaddrcheck udp-broadcast-relay hvinfo vyatta-wanloadbalance
    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP package-build.py $TSK ($BLT exists)"
fi


############## ti-linux-firmware
# This will populate ./debian-repos/
TSK=ti-linux-firmware
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"
    # symlink everything to the build directory
    for a in $(find $ROOTDIR/vyos-build/scripts -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
        echo "Symlinking package: $a"
        ln -vrfs $a $ROOTDIR/vyos-build/packages/
    done
    
    # this setion needs some rework to clean up how this ti firmware is pulled.
    rm -rf debian-repos
    git clone -b psl-master $REPO_URL_TI_DEB
    cd debian-repos
    
    DEB_SUITE=bookworm ./run.sh ti-linux-firmware
    cd ${ROOTDIR}
    ln -vrfs debian-repos/build/bookworm/ti-linux-firmware/*64*.deb $ROOTDIR/vyos-build/packages/
    # end of section for rework
    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP $TSK ($BLT exists)"
fi
cd ${ROOTDIR}


############## build-vyos-image
# This will populate ./vyos-build/build/
TSK=build-vyos-image
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"
    cd $ROOTDIR/vyos-build
    sudo ./build-vyos-image arm64fs --architecture arm64 --build-by "psleng@perle.com"
    cd -
    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP $TSK ($BLT exists)"
fi
cd $ROOTDIR


############## ISO2image-build
# This will populate ./build/fs/
TSK=ISO2image-build
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"

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

    echo "=== I: $0: $TSK: Almost done; performing fs fixups"
    FS=$ROOTDIR/build/fs

    # Temporary fix for DUID in vyos-1x until a more complete solution is thought about
    cp -f $ROOTDIR/updates/vyos-router $FS/usr/libexec/vyos/init/
    # Temporary fix for console support until a more complete solution is thought about
    cp -f $ROOTDIR/updates/system_console.py $FS/usr/libexec/vyos/conf_mode/

    # replace console ttyS0 with ours at ttyS2
    sed -i 's/ttyS0/ttyS2/' $FS/usr/share/vyos/config.boot.default

    # journald fixups
    sed -i \
        -e 's/#Storage=persistent/Storage=volatile/' \
        -e 's/#RuntimeMaxUse=/RuntimeMaxUse=256K/' \
        -e 's/MaxLevelSyslog=debug/MaxLevelsyslog=info/' \
            $FS/etc/systemd/journald.conf

    # NXP driver additions to fs
    tar -C $FS -zxf $ROOTDIR/vyos-build/scripts/package-build/linux-kernel/build_iGOS_drivers/fs.tar.gz

    # Decompress the vmlinuz (symlink to the real thing) into Image
    gunzip < build/fs/boot/vmlinuz > build/fs/boot/Image

    umount -d build/tmp/

    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP $TSK ($BLT exists)"
fi


echo "=== I: $0: COMPLETED"
