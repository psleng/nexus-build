#!/bin/sh

### /lib/live/boot/* functionality

# === Corresponds to lib/live/boot/9990-vyos.sh
# create the /config mount point to /opt/vyatta/etc/config and set uid/group root:vyattacfg
	chown root:vyattacfg /config
	mount --bind /opt/vyatta/etc/config /config
#	chown root:vyattacfg /config


### /lib/live/config/* functionality
# None of these should be needed if updates/run-live-config
# is run during the build.

# === Corresponds to lib/live/config/1090-ssl-cert
# check if snakeoil private and public keys exist, and create if either is absent
#
	if [ ! -e /etc/ssl/certs/ssl-cert-snakeoil.pem ] || [ ! -e /etc/ssl/private/ssl-cert-snakeoil.key ]
	then
		make-ssl-cert generate-default-snakeoil --force-overwrite
	fi

	# Creating state file
	touch /var/lib/live/config/ssl-cert

