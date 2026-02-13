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

# Any other extra args
COV=/usr/local/cov-analysis
if [ -d $COV ]; then
    echo 'Coverity enabled'
    EXTRA_ARGS="-v $COV:$COV"
    EXTRA_PATH=":$COV/bin"
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

#
# Run the container image.
#
# - disable_ipv6 to prevent trying downloads that way since it rarely works.
# - Add /opt/go/bin so we get the correct version of go when noninteractive.
# - hostname vyos-build to prevent confusion.
#
docker run --rm $DFLAGS \
  --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -e PATH=/opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin$EXTRA_PATH \
  -h vyos-build \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK \
  -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
  $GITMNT $SSHMNT $EXTRA_ARGS -w /vyos \
  vyos/vyos-build:$TAG "$@"
