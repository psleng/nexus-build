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

# Make invoking user's .gitconfig available
GITCONFIG=$HOME/.gitconfig
if [ -f $GITCONFIG ]; then
    GITMNT="-v $GITCONFIG:/etc/gitconfig"
else
    echo "$0: WARNING: \"$GITCONFIG\" does not exist." >&2
    GITMNT=''
fi

# Make invoking user's .ssh/ available
SSH=$HOME/.ssh
if [ -d $SSH ]; then
    SSHMNT="-v $SSH:/etc/.ssh"
else
    echo "$0: WARNING: \"$SSH\" does not exist." >&2
    SSHMNT=''
fi

. ./.defs.mk
if [ "$BUILDTARG" = "x86_64" ]; then
    TAG=latest
else
    TAG=current-arm64
    DFLAGS="$DFLAGS --platform linux/arm64"
    if [ $ARCH != 'aarch64' ]; then
        # Different tag for non-ARM.  This will hopefully go away.
        TAG=${TAG}v8
    fi
fi

docker run --rm $DFLAGS \
  --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -e PATH=/opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -h vyos-build \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  $GITMNT $SSHMNT -w /vyos \
  vyos/vyos-build:$TAG "$@"
