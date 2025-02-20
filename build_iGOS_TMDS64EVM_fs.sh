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
SRCDIR=package-build-iGOS
DSTDIR=vyos-build/scripts/
if [ ! -d $DSTDIR/$SRCDIR ]; then
    echo "=== I: $0: Copying $ROOTDIR/$SRCDIR into $DSTDIR"
    cp -rf $SRCDIR $DSTDIR
    echo "These files were copied from $ROOTDIR/$SRCDIR" > $DSTDIR/$SRCDIR/README-PSL
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
        openvpn-otp aws-gwlbtun node_exporter blackbox_exporter \
        podman ddclient dropbear hostap kea keepalived netfilter \
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
        tacacs live-boot

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
    touch "$BLT" # build success
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
        if [ "$BUILDTYPE" = "bookworm-am64xx-evm" ]; then
            ln -vrfs debian-repos/build/$DEB_SUITE/ti-linux-firmware/*64*.deb $ROOTDIR/vyos-build/packages/
        elif [ "$BUILDTYPE" = "bookworm-j7200-evm" ]; then
            ln -vrfs debian-repos/build/$DEB_SUITE/ti-linux-firmware/*j7200*.deb $ROOTDIR/vyos-build/packages/
        else
            echo "=== E: $0: Undefined BUILDTARG:BUILDTYPE ($BUILDTARG:$BUILDTYPE)"
            exit 1
        fi
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


############## ti-evm-fs-build
# This will populate ./build/fs/
TSK=ti-evm-fs-build
BLT=.filesystem.$TSK.built
if [ "$BUILDTARG" != "ti-evm" ]; then
    # Not TI.
    echo "=== I: $0: Skipping $TSK because $BUILDTARG != ti-evm"
    touch $BLT
fi

if [ ! -f "$BLT" ]; then
    echo "=== I: $0: $TSK BEGIN"

    # NOTE: for any non-architecture specific mods, do them here:
    #
    #   vyos-build/data/live-build-config/hooks/live/99-PSL-customize.chroot
    #
    # Changes made there will end up in the .iso

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
    FS=$ROOTDIR/build/fs
    sudo unsquashfs -d $FS build/tmp/live/filesystem.squashfs

    #rm -rf $FS/boot/grub
    sudo mkdir $FS/boot/dtb
    sudo cp -R $FS/usr/lib/linux-image*/ti $FS/boot/dtb

    echo "=== I: $0: $TSK: Almost done; performing fs fixups"

    # replace console ttyS0 with ours at ttyS3 and add one more device ttyS2
    # sudo sed -i 's/ttyS0/ttyS3/' $FS/usr/share/vyos/config.boot.default
    # sudo sed -i '/console.*$/a \        device ttyS2 {\n\t    speed \"115200\"\n\t}' $FS/usr/share/vyos/config.boot.default

    # copy the perle-init once service that mounts /config to /opt/vyatta.etc.config and installs the snakeoil cert if missing
    sudo cp updates/perle-init.service $FS/lib/systemd/system
    sudo ln -s /lib/systemd/system/perle-init.service $FS/etc/systemd/system/multi-user.target.wants/perle-init.service
    sudo cp updates/perle-init.sh $FS/usr/bin

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
