#!/bin/sh
set -eu

: "${IMAGEBUILDER:?Set IMAGEBUILDER to an extracted OpenWrt 25.12.5 x86/64 ImageBuilder}"
: "${MANAGER_IPK:?Set MANAGER_IPK to the built singbox-manager package}"
: "${LUCI_IPK:?Set LUCI_IPK to the built luci-app-singbox package}"

PROFILE="${PROFILE:-generic}"
PACKAGES="${PACKAGES:-sing-box jq nftables tailscale luci-base luci-mod-admin-full}"

exec make -C "$IMAGEBUILDER" image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES $MANAGER_IPK $LUCI_IPK" \
    FILES="$(CDPATH= cd -- "$(dirname -- "$0")/files" && pwd)"
