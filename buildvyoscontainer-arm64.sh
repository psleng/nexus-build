#!/bin/bash

#set -x
#set -e

IMGNAME=vyos/vyos-build:current-arm64
if docker image inspect $IMGNAME > /dev/null 2>&1; then
    P=$(basename $0)
    echo "$P: $IMGNAME exists; not building again."
    echo "$P: To force a rebuild type:"
    echo "    docker image rm $IMGNAME"
    exit 0
fi

ROOTDIR=$(pwd)

rm -rf vyos-build-container

mkdir -p ${ROOTDIR}/vyos-build-container

cd vyos-build-container

git clone -b psl-master --single-branch https://github.com/psleng/vyos-build

cd vyos-build

cp ${ROOTDIR}/DockerfileArm64 docker/Dockerfile

# copy the psleng.github.io public key to container area for use in Dockerfile
cp ${ROOTDIR}/updates/psleng.key docker/psleng.key

#docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
docker build -t $IMGNAME docker --build-arg ARCH=arm64v8/ --platform linux/arm64 --no-cache
#docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
