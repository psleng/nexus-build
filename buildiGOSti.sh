#!/bin/sh
#
# Build iGOS TI image
#

TI=ti-bdebstrap
# Resolve workspace root robustly for both host and container runs.
# In docker builds, /vyos is the mounted workspace and is persistent.
ROOTDIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if [ -d /vyos ] && [ -w /vyos ]; then
    ROOTDIR=/vyos
fi

# Prefer workspace-local ti-bdebstrap because /vyos is the persistent mount
# shared across docker invocations in this pipeline. Fall back to ~/ti-bdebstrap
# for host-side workflows.
TI_HOME="${ROOTDIR}/ti-bdebstrap"
if [ ! -d "$TI_HOME" ] && [ -d "$HOME/ti-bdebstrap" ]; then
    TI_HOME="$HOME/ti-bdebstrap"
fi

# If workspace-local ti-bdebstrap is a stale/external symlink, replace it so
# artifacts are written into the persistent workspace path.
if [ "$TI_HOME" = "${ROOTDIR}/ti-bdebstrap" ] && [ -L "$TI_HOME" ]; then
    TI_LINK_TARGET=$(readlink -f "$TI_HOME" 2>/dev/null || true)
    case "$TI_LINK_TARGET" in
        ${ROOTDIR}/*)
            ;;
        *)
            echo "I: Replacing external ti-bdebstrap symlink at $TI_HOME"
            rm -f "$TI_HOME"
            ;;
    esac
fi

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
if [ -f "$ROOTDIR/.defs.mk" ]; then
    ln -sfn "$ROOTDIR/.defs.mk" "$TI_HOME/.defs.mk"
fi

# Set up links to TI files and do some modifications
"$TI_HOME"/PSL-mklinks $(pwd) || { exit $?; }

#exec sudo "$TI_HOME"/buildiGOSti2.sh "$@"
exec sudo KEEP_BSP_SOURCES=1 NEXUS_ROOT="$ROOTDIR" TI_BDEBSTRAP_HOME="$TI_HOME" "$TI_HOME"/buildiGOSti2.sh "$@"
