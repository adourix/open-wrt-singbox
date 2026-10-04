#!/bin/sh
# Dedicated nftables table owned by singbox-manager.
# This is intentionally minimal until the TUN behavior is verified on OpenWrt.

TABLE_FAMILY=inet
TABLE_NAME=singbox

firewall_apply() {
    command -v nft >/dev/null 2>&1 || return 1
    nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1 || nft add table "$TABLE_FAMILY" "$TABLE_NAME" || return 1
    return 0
}

firewall_cleanup() {
    command -v nft >/dev/null 2>&1 || return 0
    nft delete table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1 || true
    return 0
}

if [ "${0##*/}" = "firewall.sh" ] && [ "$#" -gt 0 ]; then
    case "$1" in
        apply) firewall_apply ;;
        cleanup) firewall_cleanup ;;
        *) printf "%s\n" "Usage: firewall.sh {apply|cleanup}" >&2; exit 2 ;;
    esac
fi
