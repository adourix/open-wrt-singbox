#!/bin/sh
# Project-owned nftables safety policy.
# sing-box 1.13 auto_redirect owns interception rules in fw4.
TABLE_FAMILY=inet
TABLE_NAME=singbox
CHAIN_NAME=forward

firewall_apply() {
    command -v nft >/dev/null 2>&1 || return 1

    nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1 ||
        nft add table "$TABLE_FAMILY" "$TABLE_NAME" || return 1

    nft list chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" >/dev/null 2>&1 ||
        nft add chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" \
            '{ type filter hook forward priority -5; policy accept; }' || {
                nft delete table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1 || true
                return 1
            }

    nft flush chain "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" || return 1

    nft add rule "$TABLE_FAMILY" "$TABLE_NAME" "$CHAIN_NAME" \
        iifname "br-lan" meta nfproto ipv6 drop \
        comment "singbox: block IPv6 bypass" || {
            nft delete table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1 || true
            return 1
        }
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
        *) printf '%s\n' 'Usage: firewall.sh {apply|cleanup}' >&2; exit 2 ;;
    esac
fi
