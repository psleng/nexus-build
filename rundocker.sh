#!/bin/sh
if test $# = 0; then
    # No args so run interactive shell by default.
    # Else, run supplied command(s) noninteractively.
    set -- /bin/bash -i
    DFLAGS='-it'
fi

docker run --rm $DFLAGS --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -h vyos-build \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  -v "$HOME/.gitconfig":/etc/gitconfig -w /vyos \
  vyos/vyos-build:current-arm64v8 "$@"
