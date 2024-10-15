#!/bin/bash

#set -x
#set -e

ROOTDIR=$(pwd)

rm -rf vyos-build-container

mkdir -p ${ROOTDIR}/vyos-build-container

cd vyos-build-container

git clone -b current --single-branch https://github.com/johnlfeeney/vyos-build

cd vyos-build

cp ${ROOTDIR}/Dockerfile docker/Dockerfile

docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
docker build -t vyos/vyos-build:current-arm64v8 docker --build-arg ARCH=arm64v8/ --platform linux/arm64v8 --no-cache
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
