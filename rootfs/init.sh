#!/bin/sh

set -eux

export PATH=/bin:/sbin:/usr/bin

# System
V2GW_INIT_ROOT_PASSWORD=${V2GW_INIT_ROOT_PASSWORD:-root}
V2GW_INIT_TZ=${V2GW_INIT_TZ:=Asia/Shanghai}
V2GW_INIT_HOSTNAME=${V2GW_INIT_HOSTNAME:-v2gw.local}
V2GW_INIT_APK_MIRROR_ADDR=${V2GW_INIT_APK_MIRROR_ADDR:-mirrors.tuna.tsinghua.edu.cn}
V2GW_INIT_WITH_SSH=${V2GW_INIT_WITH_SSH:-1}
# v2ray
V2GW_INIT_WITH_V2RAY=${V2GW_INIT_WITH_V2RAY:-1}
V2GW_INIT_V2RAY_VERSION=${V2GW_INIT_V2RAY_VERSION:-v5.7.0}
# xray
V2GW_INIT_WITH_XRAY=${V2GW_INIT_WITH_XRAY:-1}
V2GW_INIT_XRAY_VERSION=${V2GW_INIT_XRAY_VERSION:-v1.7.5}
# v2ray-exporeter
V2GW_INIT_WITH_V2RAY_EXPORTER=${V2GW_INIT_WITH_V2RAY_EXPORTER:-1}
V2GW_INIT_V2RAY_EXPORTER_VERSION=${V2GW_INIT_V2RAY_EXPORTER_VERSION:-v0.6.0}

readonly V2GW_V2RAY_LOCATION_ASSET=/usr/share/v2ray
readonly V2GW_V2RAY_LOCATION_CONFIG=/etc/v2ray

change_apk_mirror() {
    sed -i "s/dl-cdn.alpinelinux.org/${V2GW_INIT_APK_MIRROR_ADDR}/g" \
        /etc/apk/repositories
}

install_dependencies() {
    apk update && apk upgrade
    apk add --no-cache curl \
        iptables \
        openrc \
        tzdata \
        openssl \
        ca-certificates \
        unzip
    if [ 1 -eq ${V2GW_INIT_WITH_SSH} ]; then
        apk add --no-cache openssh
    fi
}

fix_tty() {
    sed -i 's/tty[2-6].*/#&/g' /etc/inittab
}

verify_dgst() {
    input_file="$1"
    dgst_file="$2"

    if [ $(openssl dgst -sha512 ${input_file} | sed 's/([^)]*)//g') != $(cat ${dgst_file} | grep '512' | head -n1) ]; then
        return 1
    fi
}

install_v2ray() {
    mkdir -p ${V2GW_V2RAY_LOCATION_ASSET} \
        ${V2GW_V2RAY_LOCATION_CONFIG} \
        /var/log/v2ray

    case $(uname -m) in
    x86_64)
        ARCH=64
        ;;
    *)
        echo "unknon platform: $(uname -m)" && retuen 1
        ;;
    esac

    case "${V2GW_INIT_V2RAY_VERSION}" in
    latest)
        binaries_url="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-${ARCH}.zip"
        dgst_url="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-${ARCH}.zip.dgst"
        ;;
    *)
        binaries_url="https://github.com/v2fly/v2ray-core/releases/download/${V2GW_INIT_V2RAY_VERSION}/v2ray-linux-${ARCH}.zip"
        dgst_url="https://github.com/v2fly/v2ray-core/releases/download/${V2GW_INIT_V2RAY_VERSION}/v2ray-linux-${ARCH}.zip.dgst"
        ;;
    esac

    curl -SLfo /tmp/v2ray.zip "${binaries_url}"
    curl -SLfo /tmp/v2ray.zip.dgst "${dgst_url}"

    if [ ! verify_dgst /tmp/v2ray.zip /tmp/v2ray.zip.dgst ]; then
        echo "Check have not passed yet." >&2 && return 1
    fi

    rm /tmp/v2ray.zip.dgst

    unzip -p /tmp/v2ray.zip v2ray >/usr/bin/v2ray
    chmod +x /usr/bin/v2ray
    # v4 only
    if unzip -l /tmp/v2ray.zip | grep -q v2ctl; then
        unzip -p /tmp/v2ray.zip v2ctl >/usr/bin/v2ctl
        chmod +x /usr/bin/v2ctl
    fi

    rm /tmp/v2ray.zip

    sed -i "s#V2_LOCATION_ASSET=".*"#V2_LOCATION_ASSET="${V2GW_V2RAY_LOCATION_ASSET}"#g" \
        /etc/init.d/v2ray
}

install_xray() {
    mkdir -p ${V2GW_V2RAY_LOCATION_ASSET} \
        ${V2GW_V2RAY_LOCATION_CONFIG} \
        /var/log/xray

    case $(uname -m) in
    x86_64)
        ARCH=64
        ;;
    *)
        echo "unknon platform: $(uname -m)" && retuen 1
        ;;
    esac

    case "${V2GW_INIT_XRAY_VERSION}" in
    latest)
        binaries_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip"
        dgst_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip.dgst"
        ;;
    *)
        binaries_url="https://github.com/XTLS/Xray-core/releases/download/${V2GW_INIT_XRAY_VERSION}/Xray-linux-${ARCH}.zip"
        dgst_url="https://github.com/XTLS/Xray-core/releases/download/${V2GW_INIT_XRAY_VERSION}/Xray-linux-${ARCH}.zip.dgst"
        ;;
    esac

    curl -SLfo /tmp/xray.zip "${binaries_url}"
    curl -SLfo /tmp/xray.zip.dgst "${dgst_url}"

    if [ ! verify_dgst /tmp/xray.zip /tmp/xray.zip.dgst ]; then
        echo "Check have not passed yet." >&2 && return 1
    fi

    rm /tmp/xray.zip.dgst

    unzip -p /tmp/xray.zip xray >/usr/bin/xray
    chmod +x /usr/bin/xray

    rm /tmp/xray.zip

    sed -i "s#V2_LOCATION_ASSET=".*"#V2_LOCATION_ASSET="${V2GW_V2RAY_LOCATION_ASSET}"#g" \
        /etc/init.d/xray
}

install_v2ray_exporter() {
    case $(uname -m) in
    x86_64)
        ARCH=amd64
        ;;
    *)
        echo "unknon platform: $(uname -m)" && retuen 1
        ;;
    esac

    case "${V2GW_INIT_V2RAY_EXPORTER_VERSION}" in
    latest)
        binaries_url="https://github.com/wi1dcard/v2ray-exporter/releases/latest/download/v2ray-exporter_linux_${ARCH}"
        ;;
    *)
        binaries_url="https://github.com/wi1dcard/v2ray-exporter/releases/download/${V2GW_INIT_V2RAY_EXPORTER_VERSION}/v2ray-exporter_linux_${ARCH}"
        ;;
    esac

    curl -SLfo /usr/bin/v2ray-exporter "${binaries_url}"
    chmod +x /usr/bin/v2ray-exporter
}

main() {
    change_apk_mirror && install_dependencies
    
    # fix tty
    fix_tty
    # set root password
    echo -e "${V2GW_INIT_ROOT_PASSWORD}\n${V2GW_INIT_ROOT_PASSWORD}" | passwd root
    # set timezone
    ln -sf "/usr/share/zoneinfo/${V2GW_INIT_TZ}" "/etc/localtime"
    # set hostname
    echo "${V2GW_INIT_HOSTNAME}" >/etc/hostname

    # install v2ray
    if [ 1 -eq ${V2GW_INIT_WITH_V2RAY} ]; then
        install_v2ray
    fi

    # install xray
    if [ 1 -eq ${V2GW_INIT_WITH_XRAY} ]; then
        install_xray
    fi

    # install v2ray-exporter
    if [ 1 -eq ${V2GW_INIT_WITH_V2RAY_EXPORTER} ]; then
        install_v2ray_exporter
    fi

    /usr/bin/update-v2ray-geo-data

    # enable netword
    rc-update add networking default
    # enable sshd
    if [ 1 -eq ${V2GW_INIT_WITH_SSH} ]; then
        rc-update add sshd default
    fi
}

main $@
