#!/bin/sh
# Supported sing-box versions.
#   1.13.21  pinned release (OpenWrt 25.12 feed), full feature set
#   1.12.x   OpenWrt 24.10 feed (sing-box-tiny); same generated config, but no
#            public-key certificate pin (certificate_public_key_sha256 is 1.13+)
# A version is accepted only when a template marker exists for it: either
# "<version>.json" or "<major>.<minor>.json" for a whole patch series.
SINGBOX_TEMPLATE_DIR=${SINGBOX_TEMPLATE_DIR:-/usr/lib/cowboy-bebop/config/templates}

singbox_version() {
    "$SINGBOX_BIN" version 2>/dev/null | sed -n '1s/^.*version[[:space:]]*//p' | awk '{print $1}'
}

singbox_series() {
    printf '%s\n' "$1" | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\)\.[0-9][0-9]*$/\1/p'
}

check_singbox_version() {
    actual=$(singbox_version)
    [ -n "$actual" ] || return 1
    series=$(singbox_series "$actual")
    [ -n "$series" ] || return 1          # must be a full x.y.z version
    [ -f "$SINGBOX_TEMPLATE_DIR/$actual.json" ] || [ -f "$SINGBOX_TEMPLATE_DIR/$series.json" ]
}

# certificate_public_key_sha256 exists from sing-box 1.13.0.
singbox_supports_pubkey_pin() {
    case "$(singbox_series "$(singbox_version)")" in
        1.[0-9]|1.1[0-2]|0.*|'') return 1 ;;
        *) return 0 ;;
    esac
}
