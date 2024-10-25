#!/bin/bash

set -x
set -e

ROOTDIR=$(pwd)

# replace console ttyS0 with ours at ttyS2
sed -i 's/ttyS0/ttyS2/g' $ROOTDIR/build/fs/usr/share/vyos/config.boot.default

# journald fixups
sed -i 's/#Storage=persistent/Storage=volatile/g' $ROOTDIR/build/fs/etc/systemd/journald.conf
sed -i 's/#RuntimeMaxUse=/RuntimeMaxUse=256K/g' $ROOTDIR/build/fs/etc/systemd/journald.conf
sed -i 's/MaxLevelSyslog=debug/MaxLevelsyslog=info/g' $ROOTDIR/build/fs/etc/systemd/journald.conf


