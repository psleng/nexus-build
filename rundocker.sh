#!/bin/sh
ARCH=$(arch)

if test $# = 0; then
    # No args so run interactive shell by default.
    set -- /bin/bash -i
    DFLAGS='-it'
else
    # Else run supplied command(s).
    if tty -s; then
        # stdin is valid so make it interactive.
        DFLAGS='-it'
    fi
fi

GITCONFIG=$HOME/.gitconfig
if [ -f $GITCONFIG ]; then
    GITMNT="-v $GITCONFIG:/etc/gitconfig"
else
    echo "$0: WARNING: \"$GITCONFIG\" does not exist." >&2
    echo "$0: Copy your personal ~/.gitconfig to that location" >&2
    GITMNT=''
fi

TAG=current-arm64
if [ $ARCH != 'aarch64' ]; then
    # Different tag for non-ARM.  This will hopefully go away.
    TAG=${TAG}v8
fi

docker run --rm $DFLAGS --platform linux/arm64 \
  --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -h vyos-build \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  $GITMNT -w /vyos \
  vyos/vyos-build:$TAG "$@"
