#!/bin/sh
if test $# = 0; then
    # No args so run interactive shell by default.
    # Else, run supplied command(s) noninteractively.
    set -- /bin/bash -i
    DFLAGS='-it'
fi

GITCONFIG=$HOME/.gitconfig
if [ -f $GITCONFIG ]; then
    GITMNT="-v $GITCONFIG:/etc/gitconfig"
else
    echo "$0: WARNING: \"$GITCONFIG\" does not exist." >&2
    echo "$0: Copy your personal ~/.gitconfig to that location" >&2
    GITMNT=''
fi

docker run --rm $DFLAGS --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -h vyos-build \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  $GITMNT -w /vyos \
  vyos/vyos-build:current-arm64v8 "$@"
