#!/bin/sh
# Run interactive shell by default, else supplied commands
test $# = 0 && set -- /bin/bash -i

docker run --rm -it --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -h vyos-build \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  -v "$HOME/.gitconfig":/etc/gitconfig -w /vyos \
  vyos/vyos-build:current-arm64v8 "$@"
