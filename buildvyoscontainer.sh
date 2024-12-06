#!/bin/bash
#
# Build docker image for VyOS building
#

ROOTDIR=$(pwd)
ARCH=$(arch)

IMGNAME=vyos/vyos-build:current-arm64
if [ $ARCH != 'aarch64' ]; then
    # Different name for non-ARM.  This will hopefully go away.
    IMGNAME=${IMGNAME}v8
fi

if docker image inspect $IMGNAME > /dev/null 2>&1; then
    P=$(basename $0)
    echo "$P: $IMGNAME exists; not building again."
    echo "$P: To force a rebuild type:"
    echo "    docker image rm $IMGNAME"
    exit 0
fi

if [ ! -d vyos-build ]; then
    echo "I: Cloning vyos-build"
    git clone -b psl-master --single-branch https://github.com/psleng/vyos-build
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
    if [ $ARCH != aarch64 ]; then
        # When qemu is involved, resetting seems to be needed sometimes.
        echo "I: Resetting qemu"
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
    fi
}

resetqemu
docker build -t $IMGNAME docker --build-arg ARCH=arm64v8/ --platform linux/arm64 --no-cache
st=$?
resetqemu
exit $st
