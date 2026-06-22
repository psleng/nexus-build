#!/bin/bash
#
# Build docker image for VyOS building
#

ROOTDIR=$(pwd)
ARCH=$(arch)

IMGNAME=vyos/vyos-build
. $ROOTDIR/.defs.mk
if [ "$BUILDTARG" != "x86_64" ]; then
    IMGNAME=$IMGNAME:current-arm64
    if [ $ARCH != 'aarch64' ]; then
        # Different name for non-ARM.  This will hopefully go away.
        IMGNAME=${IMGNAME}v8
    fi
fi

if [ ! -d vyos-build ]; then
    echo "I: Cloning vyos-build"
    git clone -b vyos-build-jf --single-branch https://github.com/psleng/vyos-build
fi

if docker image inspect $IMGNAME > /dev/null 2>&1; then
    # Docker image exists, but is it up to date?
    P=$(basename $0)
    if $ROOTDIR/bin/checkDockerImageUptodate.py $IMGNAME \
            Dockerfile-$ARCH vyos-build/docker/entrypoint.sh
    then
        echo "$P: $IMGNAME exists and is up to date; skipping rebuild."
        echo "$P: To force a rebuild type:"
        echo "    docker image rm $IMGNAME"
        exit 0
    else
        echo "$P: $IMGNAME exists but is obsolete; rebuilding."
        docker image rm $IMGNAME
        docker system prune -f
    fi
fi

cd vyos-build

DF=${ROOTDIR}/Dockerfile-$ARCH
if [ ! -f $DF ]; then
    echo "E: Need a $DF for this machine" >&2
    exit 1
fi
echo "I: ARCH=$ARCH so using $DF"
rm -f docker/Dockerfile
cp -p $DF docker/Dockerfile

# copy the psleng.github.io public key to container area for use in Dockerfile
cp ${ROOTDIR}/updates/psleng.key docker/psleng.key

resetqemu() {
    if [ $ARCH != aarch64 -a "$BUILDTARG" != "x86_64" ]; then
        # When qemu is involved, resetting seems to be needed sometimes.
        echo "I: Resetting qemu"
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
    fi
}

resetqemu
if [ "$BUILDTARG" != "x86_64" ]; then
    DARGS='--build-arg ARCH=arm64v8/ --platform linux/arm64'
fi

docker build --dns=1.1.1.1 --dns=8.8.8.8 -t $IMGNAME docker $DARGS --no-cache
st=$?
resetqemu
exit $st
