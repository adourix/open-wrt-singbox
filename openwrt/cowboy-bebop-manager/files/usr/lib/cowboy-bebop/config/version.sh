#!/bin/sh
SINGBOX_SUPPORTED_VERSION=${SINGBOX_SUPPORTED_VERSION:-1.13.21}
SINGBOX_TEMPLATE_DIR=${SINGBOX_TEMPLATE_DIR:-/usr/lib/cowboy-bebop/config/templates}

singbox_version() {
    "$SINGBOX_BIN" version 2>/dev/null | sed -n '1s/^.*version[[:space:]]*//p' | awk '{print $1}'
}

check_singbox_version() {
    actual=$(singbox_version)
    [ -n "$actual" ] || return 1
    [ "$actual" = "$SINGBOX_SUPPORTED_VERSION" ] || return 1
    [ -f "$SINGBOX_TEMPLATE_DIR/$actual.json" ]
}
