#!/bin/bash

DATECODE=$(date +%Y%m%d%H%M%S00)
ROOTDIR=$(pwd)

. $ROOTDIR/.defs.mk

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# The nexus ISO re-squash has been RETIRED. Historically this script loop-mounted
# the vyos-build ISO, discarded its squashfs, re-squashed a SEPARATE (older) flat
# rootfs with xz, re-copied DTBs and patched sha256sum.txt to produce a stage_iso
# tree that was then turned into the final igos-live-*.iso.
#
# The vyos-build ISO is now the authoritative, up-to-date image and already
# contains everything needed (squashfs, kernel, initrd, DTBs, u-boot, grub). So
# this script no longer builds anything: it simply exposes the vyos-build ISO at
# the location downstream consumers and users expect, as a symlink.

ISOPATH_BUILD=$ROOTDIR/iso-images/$BUILDTYPE
LIVE_IMAGE_ISO=$ROOTDIR/vyos-build/build/live-image-$ARCH.hybrid.iso
# Relative target so the link resolves both on the host and inside the build
# container (both root the tree at the nexus-build directory).
LIVE_IMAGE_ISO_REL=../../vyos-build/build/live-image-$ARCH.hybrid.iso

# Check the vyos-build ISO exists
if [ ! -e "$LIVE_IMAGE_ISO" ]; then
  echo "=== E: $0: File $LIVE_IMAGE_ISO does not exist."
  exit 1
fi

# Set up the output directory downstream consumers / users expect, and drop the
# now-obsolete stage_iso tree left by previous (re-squash) builds.
sudo mkdir -p "$ISOPATH_BUILD"
sudo rm -rf "$ISOPATH_BUILD/stage_iso"

# Expose the vyos-build ISO at the expected location as a symlink.
LINK="$ISOPATH_BUILD/igos-live-${DATECODE}-arm64.iso"
sudo ln -sfn "$LIVE_IMAGE_ISO_REL" "$LINK"

echo "=== I: $0: linked $LINK -> $LIVE_IMAGE_ISO_REL"
echo "=== I: $0: COMPLETED"

