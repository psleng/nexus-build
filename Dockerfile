# Copyright (C) 2018-2024 VyOS maintainers and contributors
#
# This program is free software; you can redistribute it and/or modify
# in order to easy exprort images built to "external" world
# it under the terms of the GNU General Public License version 2 or later as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Must be run with --privileged flag, recommended to run the container with a
# volume mapped in order to easy export images

# This Dockerfile is installable on both x86, x86-64, armhf and arm64 systems
ARG ARCH=
FROM ${ARCH}debian:bookworm

RUN grep "VERSION_ID" /etc/os-release || (echo 'VERSION_ID="12"' >> /etc/os-release)

# It is also possible to emulate an arm system inside docker,
# execution of this emulated system needs to be executed on an x86 or x86-64 host.

# To install using a non-native cpu instructionset use the `--build-arg ARCH=<ARCH>/`
# Supported architectures:
#     arm32v6/
#     arm32v7/
#     arm64v8/
# Example bo byukd natively:
#     docker build -t vyos-build:current .
# Example to build on armhf:
#     docker build -t vyos-build:current-armhf --build-arg ARCH=arm32v7/ .
# Example to build on arm64:
#     docker build -t vyos-build:current-arm64 --build-arg ARCH=arm64v8/ .

# On some versions of docker the emulation framework is not installed by default and
# you need to install qemu, qemu-user-static and register qemu inside docker manually using:
# `docker run --rm --privileged multiarch/qemu-user-static:register --reset`
LABEL authors="VyOS Maintainers <maintainers@vyos.io>" \
      org.opencontainers.image.authors="VyOS Maintainers <maintainers@vyos.io>" \
      org.opencontainers.image.url="https://github.com/vyos/vyos-build" \
      org.opencontainers.image.documentation="https://docs.vyos.io/en/latest/contributing/build-vyos.html" \
      org.opencontainers.image.source="https://github.com/vyos/vyos-build" \
      org.opencontainers.image.vendor="Sentrium S.L." \
      org.opencontainers.image.licenses="GNU" \
      org.opencontainers.image.title="vyos-build" \
      org.opencontainers.image.description="Container to build VyOS ISO" \
      org.opencontainers.image.base.name="docker.io/debian/debian:bookworm"
ENV DEBIAN_FRONTEND=noninteractive

RUN /bin/echo -e 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";' > /etc/apt/apt.conf.d/01norecommends

RUN apt-get update && apt-get install -y \
      dialog \
      apt-utils \
      locales

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
ENV LANG=en_US.utf8

ENV OCAML_VERSION=4.14.2

# Base packaged needed to build packages and their package dependencies
RUN apt-get update && apt-get install -y \
      bash \
      bash-completion \
      vim \
      vim-autopep8 \
      nano \
      git \
      curl \
      sudo \
      mc \
      pbuilder \
      devscripts \
      equivs \
      lsb-release \
      libtool \
      libapt-pkg-dev \
      flake8 \
      pkg-config \
      debhelper \
      gosu \
      po4a \
      openssh-client \
      jq \
      socat

# Packages needed for vyos-build
RUN apt-get update && apt-get install -y \
      build-essential \
      python3-pystache \
      squashfs-tools \
      genisoimage \
      fakechroot \
      pipx \
      python3-git \
      python3-pip \
      python3-flake8 \
      python3-autopep8 \
      python3-tomli \
      yq \
      debootstrap \
      live-build \
      gdisk \
      dosfstools

# Packages for TPM test
RUN apt-get update && apt-get install -y swtpm

# Syslinux and Grub2 is only supported on x86 and x64 systems
RUN if dpkg-architecture -ii386 || dpkg-architecture -iamd64; then \
      apt-get update && apt-get install -y \
        syslinux \
        grub2; \
    fi

# Building libvyosconf requires a full configured OPAM/OCaml setup
RUN apt-get update && apt-get install -y \
      debhelper \
      libffi-dev \
      libpcre3-dev \
      unzip

# Update certificate store to not crash ocaml package install
# Apply fix for https in curl running on armhf
RUN dpkg-reconfigure ca-certificates; \
    if dpkg-architecture -iarmhf; then \
      echo "cacert=/etc/ssl/certs/ca-certificates.crt" >> ~/.curlrc; \
    fi

# Installing OCAML needed to compile libvyosconfig
RUN curl https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh \
      --output /tmp/opam_install.sh --retry 10 --retry-delay 5 && \
    sed -i 's/read BINDIR/BINDIR=""/' /tmp/opam_install.sh && sh /tmp/opam_install.sh && \
    opam init --root=/opt/opam --comp=${OCAML_VERSION} --disable-sandboxing --no-setup

RUN eval $(opam env --root=/opt/opam --set-root) && \
    opam pin add pcre https://github.com/mmottl/pcre-ocaml.git#0c4ca03a -y

RUN eval $(opam env --root=/opt/opam --set-root) && opam install -y \
      re \
      num \
      ctypes \
      ctypes-foreign \
      ctypes-build \
      containers \
      fileutils \
      xml-light

# Build VyConf which is required to build libvyosconfig
RUN eval $(opam env --root=/opt/opam --set-root) && \
    opam pin add vyos1x-config https://github.com/vyos/vyos1x-config.git#d7260e772e39bc6a3a2d76d629567e03bbad16b5 -y

# Packages needed for libvyosconfig
RUN apt-get update && apt-get install -y \
      quilt \
      libpcre3-dev \
      libffi-dev

# Build libvyosconfig
RUN eval $(opam env --root=/opt/opam --set-root) && \
    git clone https://github.com/vyos/libvyosconfig.git /tmp/libvyosconfig && \
    cd /tmp/libvyosconfig && git checkout 3a021a0964882cdd1873de6cf2bb3b4acb9043e0 && \
    dpkg-buildpackage -uc -us -tc -b && \
    dpkg -i /tmp/libvyosconfig0_*_$(dpkg-architecture -qDEB_HOST_ARCH).deb

# Packages needed for open-vmdk
RUN apt-get update && apt-get install -y \
      zlib1g-dev

# Install open-vmdk
RUN wget -O /tmp/open-vmdk-master.zip https://github.com/vmware/open-vmdk/archive/master.zip && \
    unzip -d /tmp/ /tmp/open-vmdk-master.zip && \
    cd /tmp/open-vmdk-master/ && make && make install

# Packages need for build live-build
RUN apt-get update && apt-get install -y \
      cpio

COPY patches/live-build/0001-save-package-info.patch /tmp/0001-save-package-info.patch

RUN git clone https://salsa.debian.org/live-team/live-build.git /tmp/live-build && \
    cd /tmp/live-build && git checkout debian/1%20240810 && \
    patch -p1 < /tmp/0001-save-package-info.patch && \
    dch -n "Applying fix for save package info" && \
    dpkg-buildpackage -us -uc && \
    dpkg -i ../live-build*.deb
#
# live-build: building in docker fails with mounting /proc | /sys
#
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=919659
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=921815
# https://salsa.debian.org/installer-team/debootstrap/merge_requests/26
#
RUN wget https://salsa.debian.org/klausenbusk-guest/debootstrap/commit/a9a603b17cadbf52cb98cde0843dc9f23a08b0da.patch \
      -O /tmp/a9a603b17cadbf52cb98cde0843dc9f23a08b0da.patch && \
    git clone https://salsa.debian.org/installer-team/debootstrap /tmp/debootstrap && \
    cd /tmp/debootstrap && git checkout 1.0.114 && \
    patch -p1 < /tmp/a9a603b17cadbf52cb98cde0843dc9f23a08b0da.patch && \
    dch -n "Applying fix for docker image compile" && \
    dpkg-buildpackage -us -uc && \
    sudo dpkg -i ../debootstrap*.deb

# Packages needed for Linux Kernel
# gnupg2 is required by Jenkins for the TAR verification
# cmake required by accel-ppp
RUN apt-get update && apt-get install -y \
      cmake \
      gnupg2 \
      rsync \
      libelf-dev \
      libncurses5-dev \
      flex \
      bison \
      bc \
      kmod \
      cpio \
      python-is-python3 \
      dwarves \
      nasm \
      rdfind

# Packages needed for Intel QAT out-of-tree drivers
# FPM is used when generation Debian pckages for e.g. Intel QAT drivers
RUN apt-get update && apt-get install -y \
      pciutils \
      yasm \
      ruby \
      libudev-dev \
      ruby-dev \
      rubygems \
      build-essential
RUN gem install --no-document fpm

# Packages needed for vyos-1x
RUN pip install --break-system-packages \
      git+https://github.com/aristanetworks/j2lint.git@341b5d5db86 \
      pyhumps==3.8.0; \
    apt-get update && apt-get install -y \
      dh-python \
      fakeroot \
      iproute2 \
      libzmq3-dev \
      procps \
      python3 \
      python3-setuptools \
      python3-inotify \
      python3-xmltodict \
      python3-lxml \
      python3-nose \
      python3-netifaces \
      python3-jinja2 \
      python3-jmespath \
      python3-psutil \
      python3-stdeb \
      python3-all \
      python3-coverage \
      python3-hurry.filesize \
      python3-netaddr \
      python3-paramiko \
      python3-passlib \
      python3-tabulate \
      python3-zmq \
      pylint \
      quilt \
      whois

# Go required for validators and vyos-xe-guest-utilities
RUN GO_VERSION_INSTALL="1.21.3" ; \
    wget -O /tmp/go${GO_VERSION_INSTALL}.linux-amd64.tar.gz https://go.dev/dl/go${GO_VERSION_INSTALL}.linux-$(dpkg-architecture -qDEB_HOST_ARCH).tar.gz ; \
    tar -C /opt -xzf /tmp/go*.tar.gz && \
    rm /tmp/go*.tar.gz
RUN echo "export PATH=/opt/go/bin:$PATH" >> /etc/bash.bashrc


# Packages needed for opennhrp
RUN apt-get update && apt-get install -y \
      libc-ares-dev \
      libev-dev

# Packages needed for Qemu test-suite
# This is for now only supported on i386 and amd64 platforms
RUN if dpkg-architecture -ii386 || dpkg-architecture -iamd64; then \
      apt-get update && apt-get install -y \
        python3-pexpect \
        ovmf \
        qemu-system-x86 \
        qemu-utils \
        qemu-kvm; \
    fi

# Packages needed for building vmware and GCE images
# This is only supported on i386 and amd64 platforms
RUN if dpkg-architecture -ii386 || dpkg-architecture -iamd64; then \
     apt-get update && apt-get install -y \
      kpartx \
      parted \
      udev \
      grub-pc \
      grub2-common; \
    fi

# Packages needed for vyos-cloud-init
RUN apt-get update && apt-get install -y \
      python3-configobj \
      python3-httpretty \
      python3-jsonpatch \
      python3-mock \
      python3-oauthlib \
      python3-pep8 \
      python3-pyflakes \
      python3-serial \
      python3-unittest2 \
      python3-yaml \
      python3-jsonschema \
      python3-contextlib2 \
      python3-pytest-cov \
      cloud-utils

# Install utillities for building grub and u-boot images
RUN if dpkg-architecture -iarm64; then \
    apt-get update && apt-get install -y \
      dosfstools \
      u-boot-tools \
      grub-efi-$(dpkg-architecture -qDEB_HOST_ARCH); \
    elif dpkg-architecture -iarmhf; then \
    apt-get update && apt-get install -y \
      dosfstools \
      u-boot-tools \
      grub-efi-arm; \
    fi

# Packages needed for openvpn-otp
RUN apt-get update && apt-get install -y \
      debhelper \
      libssl-dev \
      openvpn

# Packages needed for OWAMP/TWAMP (service sla)
RUN git clone -b 4.4.6 https://github.com/perfsonar/i2util.git /tmp/i2util && \
      cd /tmp/i2util && \
      dpkg-buildpackage -uc -us -tc -b && \
      dpkg -i /tmp/*i2util*_$(dpkg-architecture -qDEB_HOST_ARCH).deb

# Creating image for embedded systems needs this utilities to prepare a image file
RUN apt-get update && apt-get install -y \
      parted \
      udev \
      zip

# Packages needed for Accel-PPP
# XXX: please note that this must be installed after nftable dependencies - otherwise
# APT will remove liblua5.3-dev which breaks the Accel-PPP build
# With bookworm, updated to libssl3 (Note: https://github.com/accel-ppp/accel-ppp/issues/68)
RUN apt-get update && apt-get install -y \
      liblua5.3-dev \
      libssl3 \
      libssl-dev \
      libpcre3-dev

# debmake: a native Debian tool for preparing sources for packaging
RUN apt-get update && apt-get install -y \
      debmake \
      python3-debian

# Packages for jool
RUN apt-get update && apt-get install -y \
      libnl-genl-3-dev \
      libxtables-dev
# Packages needed for OWAMP - JF
RUN apt-get update && apt-get install -y \
	dh-apparmor \
	dh-exec \
	libcap-dev

# Packages needed for Strongswan - JF
RUN apt-get update && apt-get install -y \
	bison \
	bzip2 \
	debhelper-compat \
	dh-apparmor \
	dpkg-dev  \
	flex \
	gperf \
	libiptc-dev \
	libcap-dev \
	libcurl3-dev \
	libgcrypt20-dev \
	libgmp3-dev \
	libkrb5-dev \
	libldap2-dev \
	libnm-dev \
	libpam0g-dev \
	libsqlite3-dev \
	libssl-dev \
	libtool \
	libtss2-dev \
	libxml2-dev \
	pkg-config \
	po-debconf \
	systemd \
	tzdata \
	libcurl4-openssl-dev \
	libgmp3-dev \
	libldap2-dev \
	libpam0g-dev \
	libsqlite3-dev \
	libsystemd-dev \
	systemd

# Packages needed for failed make of Vyos - JF
RUN apt-get update && apt-get install -y \
	kpartx
	
# Packages needed for frr - JF
# And for building libyan2-dev https://docs.frrouting.org/projects/dev-guide/en/latest/building-frr-for-debian12.html#install-required-packages -JF
RUN apt-get update && apt-get install -y \
	chrpath \
	gawk \
	install-info \
	libcap-dev \
	libjson-c-dev \
	librtr-dev \
	libpam-dev \libprotobuf-c-dev \
	libpython3-dev:native \
	python3-sphinx:native \
	libsnmp-dev \
	protobuf-c-compiler \
	python3-dev:native \
	texinfo \
	lua5.3 \
	autoconf \
	automake \
	make \
	libreadline-dev \
	gdb \
	libgrpc-dev \
	libpcre2-dev \
	libgrpc++-dev \
	libsqlite3-dev \
	libzmq5 \
	libzmq3-dev

	
# Clone the libyang2 repository
#RUN git clone https://github.com/CESNET/libyang.git /libyang
# Build and install libyang2
#WORKDIR /libyang
#RUN git checkout v2.1.148
#RUN pipx run apkg build -i && find pkg/pkgs -type f -name *.deb -exec mv -t .. {} +

# Clean up
#RUN apt-get clean && \
#    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*	
# And end of for building libyang2-dev	
	
# Environment variables needed - JF
ENV DEBEMAIL="psleng@perle.com"
ENV EMAIL="psleng@perle.com.com"

# Packages needed for nftables
RUN apt-get update && apt-get install -y \
      asciidoc-base

# Allow password-less 'sudo' for all users in group 'sudo'
RUN sed "s/^%sudo.*/%sudo\tALL=(ALL) NOPASSWD:ALL/g" -i /etc/sudoers && \
    echo "vyos_bld\tALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chmod a+s /usr/sbin/useradd /usr/sbin/groupadd

# Ensure sure all users have access to our OCAM and Go installation
RUN echo "$(opam env --root=/opt/opam --set-root)" >> /etc/skel/.bashrc && \
    echo "export PATH=/opt/go/bin:\$PATH" >> /etc/skel/.bashrc


# Rise upper limit for UID when working in an Active Direcotry integrated
# environment. This solves the warning: vyos_bld's uid 1632000007 outside of the
# UID_MIN 1000 and UID_MAX 60000 range.
RUN sed -i 's/UID_MAX\t\t\t60000/UID_MAX\t\t\t2000000000/g' /etc/login.defs

# Cleanup
RUN rm -rf /tmp/*

# Disable mouse in vim
RUN printf "set mouse=\nset ttymouse=\n" > /etc/vim/vimrc.local

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
