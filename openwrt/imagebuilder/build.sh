#!/bin/sh
set -eu

: "${IMAGEBUILDER:?Set IMAGEBUILDER to an extracted OpenWrt 25.12.5 ImageBuilder}"
: "${MANAGER_PKG:?Set MANAGER_PKG to the built cowboy-bebop-manager .apk}"
: "${LUCI_PKG:?Set LUCI_PKG to the built luci-app-cowboy-bebop .apk}"
: "${BRANDING_PKG:?Set BRANDING_PKG to the built cowboy-bebop-branding .apk}"

PROFILE="${PROFILE:-generic}"
# sing-box-tiny is pulled in by cowboy-bebop-manager; do not add the full
# sing-box package, it conflicts with sing-box-tiny.
# openssl-util is optional: with it, Xray certificate pins (pcs) are enforced
# as sing-box public-key pins instead of falling back to the insecure policy.
PACKAGES="${PACKAGES:-jq nftables tailscale luci-base luci-mod-admin-full luci-theme-bootstrap openssl-util}"
MANAGER_NAME=$(basename "$MANAGER_PKG" .apk)
LUCI_NAME=$(basename "$LUCI_PKG" .apk)
BRANDING_NAME=$(basename "$BRANDING_PKG" .apk)

mkdir -p "$IMAGEBUILDER/packages"
cp -f "$MANAGER_PKG" "$IMAGEBUILDER/packages/"
cp -f "$LUCI_PKG" "$IMAGEBUILDER/packages/"
cp -f "$BRANDING_PKG" "$IMAGEBUILDER/packages/"

exec make -C "$IMAGEBUILDER" image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES $MANAGER_NAME $LUCI_NAME $BRANDING_NAME" \
    FILES="$(CDPATH= cd -- "$(dirname -- "$0")/files" && pwd)"
