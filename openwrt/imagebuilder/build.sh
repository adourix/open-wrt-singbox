#!/bin/sh
set -eu

: "${IMAGEBUILDER:?Set IMAGEBUILDER to an extracted OpenWrt 25.12.5 x86/64 ImageBuilder}"
: "${MANAGER_PKG:?Set MANAGER_PKG to the built cowboy-bebop-manager .apk}"
: "${LUCI_PKG:?Set LUCI_PKG to the built luci-app-cowboy-bebop .apk}"
: "${THEME_PKG:?Set THEME_PKG to the built luci-theme-cowboy-bebop .apk}"
: "${BRANDING_PKG:?Set BRANDING_PKG to the built cowboy-bebop-branding .apk}"

PROFILE="${PROFILE:-generic}"
PACKAGES="${PACKAGES:-sing-box jq nftables tailscale luci-base luci-mod-admin-full}"
MANAGER_NAME=$(basename "$MANAGER_PKG" .apk)
LUCI_NAME=$(basename "$LUCI_PKG" .apk)
THEME_NAME=$(basename "$THEME_PKG" .apk)
BRANDING_NAME=$(basename "$BRANDING_PKG" .apk)

mkdir -p "$IMAGEBUILDER/packages"
cp -f "$MANAGER_PKG" "$IMAGEBUILDER/packages/"
cp -f "$LUCI_PKG" "$IMAGEBUILDER/packages/"
cp -f "$THEME_PKG" "$IMAGEBUILDER/packages/"
cp -f "$BRANDING_PKG" "$IMAGEBUILDER/packages/"

exec make -C "$IMAGEBUILDER" image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES $MANAGER_NAME $LUCI_NAME $THEME_NAME $BRANDING_NAME" \
    FILES="$(CDPATH= cd -- "$(dirname -- "$0")/files" && pwd)"
