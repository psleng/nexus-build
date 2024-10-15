#!/bin/sh
docker run --rm -it --privileged \
    --name vyos-build \
    -h vyos-build \
    --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
    -v $(pwd):/vyos \
    -v /dev:/dev \
    -v /etc/fstab:/etc/fstab \
    -v "$HOME/.gitconfig":/etc/gitconfig \
    -w /vyos \
    vyos/vyos-build:current-arm64v8 bash
