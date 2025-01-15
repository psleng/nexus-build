#!/bin/bash
set -ex

# Check if the --repo parameter is provided
if [ "$#" -lt 2 ] || [ "$1" != "--repo" ]; then
    echo "Usage: $0 --repo <repository_url> [--clean]"
    exit 1
fi

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

REPPREFIX_URL="$2/"
REPO_URL_TI_DEB="$2/debian-repos"
REPO_NAME="vyos-build"
REPO_URL="$2/$REPO_NAME"
ROOTDIR=$(pwd)

. $ROOTDIR/.defs.mk

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
    ./package-build.py --dir $TSK --include \
        ethtool telegraf owamp net-snmp frr frr_exporter strongswan \
        openvpn-otp opennhrp aws-gwlbtun node_exporter blackbox_exporter \
        podman ddclient dropbear hostap kea keepalived netfilter pam_tacplus \
        pmacct radvd isc-dhcp ndppd hsflowd pyhumps
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
    ./package-build.py --dir $TSK --include \
        vyos-1x vyatta-bash vyos-user-utils vyatta-biosdevname \
        libvyosconfig vyatta-cfg vyos-http-api-tools vyos-utils \
        ipaddrcheck udp-broadcast-relay hvinfo vyatta-wanloadbalance \
        libmnl libpam-radius-auth initramfs-tools igmpproxy libnss-mapuser \
        libtacplus-map libpam-tacplus libnss-tacplus

    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP package-build.py $TSK ($BLT exists)"
fi

############## package-symlink-debs
# This will populate ./vyos-build/packages/ with .deb files
TSK=package-symlink-debs
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"

    # Symlink everything to the vyos-build/packages directory
    for a in $(find $ROOTDIR/vyos-build/scripts -type f -name "*.deb")
    do
        case "$a" in
        *libsnmp-dev_*64.deb)  # Needed for frr (despite -dev_ pattern)
            ;;
        *-dev_*|*-dbg_*|*-doc_*|*-dbgsym_*)  # Unwanted general patterns
            continue
            ;;
        */accel-ppp.deb)  # Duplicates
            continue
            ;;
        */hsflowd.deb|*/sflowovsd.deb)  # Not actually .deb
            continue
            ;;
        esac

        echo "Symlinking package: $a"
        ln -vrfs $a $ROOTDIR/vyos-build/packages/
    done
else
    echo "=== I: $0: SKIP $TSK ($BLT exists)"
fi

############## ti-linux-firmware
# This will populate ./debian-repos/ and augment vyos-build/packages/
TSK=ti-linux-firmware
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"

    if [ "$BUILDTARG" != "ti-evm" ]; then
        echo "=== I: $0: SKIP $TSK (target $BUILDTARG != ti-evm)"
    else
        # this section needs some rework to clean up how this ti firmware is pulled.
        sudo rm -rf debian-repos
        git clone -b psl-master $REPO_URL_TI_DEB
        cd debian-repos

        # Determine the Debian distro to use
        DEB_SUITE=$(python3 -c "import toml; print(toml.load('$ROOTDIR/vyos-build/data/defaults.toml').get('debian_distribution', ''))")
        if test -z "$DEB_SUITE"; then
            echo "=== E: $0: Cannot determine debian_distribution"
            exit 1
        fi

        sudo DEB_SUITE=$DEB_SUITE ./run.sh ti-linux-firmware
        cd ${ROOTDIR}
        ln -vrfs debian-repos/build/$DEB_SUITE/ti-linux-firmware/*64*.deb $ROOTDIR/vyos-build/packages/
        # end of section for rework
    fi
    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP $TSK ($BLT exists)"
fi
cd ${ROOTDIR}


############## build-vyos-image
# This will populate ./vyos-build/build/
# The psleng.github.io git repo must be populated for this to work.
TSK=build-vyos-image
BLT=.filesystem.$TSK.built
if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"
    cd $ROOTDIR/vyos-build

    # PSL related keys needed within the chroot within the build container.
    # They get copied from here into the chroot.
    LB_ARCH=data/live-build-config/archives
    cp -f ../updates/psleng.key $LB_ARCH/psleng.key.chroot
    cp -f $LB_ARCH/vyos-dev.pref.chroot $LB_ARCH/psleng.pref.chroot

    if [ "$BUILDTARG" = "x86_64" ]; then
        BUILDFLAVOUR=generic
    else
        BUILDFLAVOUR=${ARCH}fs
    fi
    export VYOS1X_REPO_URL=https://github.com/psleng/vyos-1x
    export VYOS1X_REPO_BRANCH=psl-master
    sudo --preserve-env=VYOS1X_REPO_URL,VYOS1X_REPO_BRANCH \
		./build-vyos-image $BUILDFLAVOUR --architecture $ARCH --build-by "psleng@perle.com"
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
# TODO: for non-ti, skip this entire section for now.
# TODO: We do still want some of these fixups in the source .iso
if [ "$BUILDTARG" != "ti-evm" ]; then
    echo "=== I: $0: Skipping $TSK because $BUILDTARG != ti-evm"
    touch $BLT
fi

if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"

    # Check ISO file
    LIVE_IMAGE_ISO=vyos-build/build/live-image-$ARCH.hybrid.iso

    if [ ! -e ${LIVE_IMAGE_ISO} ]; then
      echo "=== E: $0: File ${LIVE_IMAGE_ISO} does not exist."
      exit 1
    fi

    ISOLOOP=$(sudo losetup --show -f ${LIVE_IMAGE_ISO})
    echo "Mounting iso on loopback: ${ISOLOOP}"

    sudo rm -rf build
    sudo mkdir -p build/tmp/

    sudo mount -o ro ${ISOLOOP} build/tmp/

    sudo unsquashfs -d build/fs build/tmp/live/filesystem.squashfs

    #rm -rf build/fs/boot/grub
    sudo mkdir build/fs/boot/dtb

    sudo cp -R build/fs/usr/lib/linux-image*/ti build/fs/boot/dtb

    echo "=== I: $0: $TSK: Almost done; performing fs fixups"
    FS=$ROOTDIR/build/fs

    # replace console ttyS0 with ours at ttyS3 and add one more device ttyS2
    sudo sed -i 's/ttyS0/ttyS3/' $FS/usr/share/vyos/config.boot.default
    sudo sed -i '/console.*$/a \        device ttyS2 {\n\t    speed \"115200\"\n\t}' $FS/usr/share/vyos/config.boot.default

    # start modem manager service early
    sudo ln -s /lib/systemd/system/ModemManager.service $FS/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service
    sudo ln -s /lib/systemd/system/ModemManager.service $FS/etc/systemd/system/multi-user.target.wants/ModemManager.service

    # journald fixups
    sudo sed -i \
        -e 's/#Storage=persistent/Storage=volatile/' \
        -e 's/#RuntimeMaxUse=/RuntimeMaxUse=256K/' \
        -e 's/MaxLevelSyslog=debug/MaxLevelSyslog=info/' \
            $FS/etc/systemd/journald.conf

    # Generate a default locale (stops warnings from perl)
    if [ ! -f $FS/usr/lib/locale/locale-archive ]; then
        echo "en_US.UTF-8 UTF-8" | sudo tee -a $FS/etc/locale.gen > /dev/null
        sudo chroot $FS locale-gen
    fi

    # Decompress the vmlinuz (symlink to the real thing) into Image
    gunzip < $FS/boot/vmlinuz | sudo sh -c "cat > $FS/boot/Image"

    sudo umount -d build/tmp/
    sudo rm -rf build/tmp/

    touch "$BLT" # build success
else
    echo "=== I: $0: SKIP $TSK ($BLT exists)"
fi


echo "=== I: $0: COMPLETED"
