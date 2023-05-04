#!/bin/bash

set -eux

ALPINE_VERSION_CHANNEL=${ALPINE_VERSION_CHANNEL:-v3.17}
ALPINE_VERSION=${ALPINE_VERSION:-3.17.3}
ALPINE_ARCH=${ALPINE_ARCH:-x86_64}

WORKDIR=/tmp/v2gw-build

rm -rf ${WORKDIR}
mkdir -p "${WORKDIR}/rootfs"

curl -SLfo "${WORKDIR}/rootfs.tgz" \
    "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION_CHANNEL}/releases/${ALPINE_ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ALPINE_ARCH}.tar.gz"
tar xvf "${WORKDIR}/rootfs.tgz" -C "${WORKDIR}/rootfs"
cp /etc/resolv.conf "${WORKDIR}/rootfs/etc"
cp -r ./rootfs/* "${WORKDIR}/rootfs"
pushd "${WORKDIR}/rootfs"
chroot ./ /init.sh
popd
mkdir -p dist
tar Jcvf "dist/v2gw-alpine-rootfs-${ALPINE_VERSION_CHANNEL}-${ALPINE_VERSION}-${ALPINE_ARCH}.tar.xz" \
    -C "${WORKDIR}/rootfs" ./
