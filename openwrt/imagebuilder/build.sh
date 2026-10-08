#!/bin/sh
set -eu

: "${IMAGEBUILDER:?Set IMAGEBUILDER to an extracted OpenWrt 25.12.5 x86/64 ImageBuilder}"
: "${MANAGER_PKG:?Set MANAGER_PKG to the built cowboy-bebop-manager .apk}"
: "${LUCI_PKG:?Set LUCI_PKG to the built luci-app-cowboy-bebop .apk}"

PROFILE="${PROFILE:-generic}"
PACKAGES="${PACKAGES:-sing-box jq nftables tailscale luci-base luci-mod-admin-full}"
MANAGER_NAME=$(basename "$MANAGER_PKG" | cut -d_ -f1)
LUCI_NAME=$(basename "$LUCI_PKG" | cut -d_ -f1)

mkdir -p "$IMAGEBUILDER/packages"
cp -f "$MANAGER_PKG" "$IMAGEBUILDER/packages/"
cp -f "$LUCI_PKG" "$IMAGEBUILDER/packages/"

exec make -C "$IMAGEBUILDER" image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES $MANAGER_NAME $LUCI_NAME" \
    FILES="$(CDPATH= cd -- "$(dirname -- "$0")/files" && pwd)"
