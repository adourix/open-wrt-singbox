#!/bin/sh
set -eu

: "${IMAGEBUILDER:?Set IMAGEBUILDER to an extracted OpenWrt 25.12.5 x86/64 ImageBuilder}"
: "${MANAGER_PKG:?Set MANAGER_PKG to the built singbox-manager .apk}"
: "${LUCI_PKG:?Set LUCI_PKG to the built luci-app-singbox .apk}"

PROFILE="${PROFILE:-generic}"
PACKAGES="${PACKAGES:-sing-box jq nftables tailscale luci-base luci-mod-admin-full}"

mkdir -p "$IMAGEBUILDER/packages"
cp -f "$MANAGER_PKG" "$IMAGEBUILDER/packages/"
cp -f "$LUCI_PKG" "$IMAGEBUILDER/packages/"

exec make -C "$IMAGEBUILDER" image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES $(basename "$MANAGER_PKG" | sed 's/-[0-9].*//' ) $(basename "$LUCI_PKG" | sed 's/-[0-9].*//' )" \
    FILES="$(CDPATH= cd -- "$(dirname -- "$0")/files" && pwd)"
