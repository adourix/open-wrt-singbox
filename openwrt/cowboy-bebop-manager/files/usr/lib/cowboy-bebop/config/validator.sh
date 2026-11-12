#!/bin/sh
# Validate a candidate sing-box configuration without activating it.

SINGBOX_CONFIG_DIR=${SINGBOX_CONFIG_DIR:-/etc/cowboy-bebop}
SINGBOX_CONFIG=${SINGBOX_CONFIG:-$SINGBOX_CONFIG_DIR/config.json}
SINGBOX_CANDIDATE=${SINGBOX_CANDIDATE:-$SINGBOX_CONFIG_DIR/config.json.new}
SINGBOX_BACKUP=${SINGBOX_BACKUP:-$SINGBOX_CONFIG_DIR/config.json.bak}
SINGBOX_BIN=${SINGBOX_BIN:-sing-box}

validate_config() {
    config=$1
    [ -n "$config" ] || config=$SINGBOX_CANDIDATE
    [ -f "$config" ] || { printf "%s\n" "Configuration file not found" >&2; return 1; }
    "$SINGBOX_BIN" check -c "$config" >/dev/null 2>&1
}

install_validated_config() {
    candidate=${1:-$SINGBOX_CANDIDATE}
    target=${2:-$SINGBOX_CONFIG}
    backup=${3:-$SINGBOX_BACKUP}
    [ -f "$candidate" ] || return 1
    validate_config "$candidate" || { rm -f "$candidate"; return 1; }
    umask 077
    dir=${target%/*}
    [ "$dir" = "$target" ] && dir=.
    mkdir -p "$dir" || return 1
    if [ -f "$target" ]; then
        cp -f "$target" "$backup" || { rm -f "$candidate"; return 1; }
        chmod 600 "$backup" 2>/dev/null || true
    fi
    chmod 600 "$candidate" || { rm -f "$candidate"; return 1; }
    mv -f "$candidate" "$target" || return 1
    chmod 600 "$target" 2>/dev/null || true
}

restore_backup() {
    target=${1:-$SINGBOX_CONFIG}
    backup=${2:-$SINGBOX_BACKUP}
    [ -f "$backup" ] || return 1
    validate_config "$backup" || return 1
    cp -f "$backup" "$target" || return 1
    chmod 600 "$target" 2>/dev/null || true
}

cleanup_candidate() { rm -f "${1:-$SINGBOX_CANDIDATE}"; }

if [ "${0##*/}" = "validator.sh" ] && [ "$#" -gt 0 ]; then
    case "$1" in
        validate) validate_config "${2:-$SINGBOX_CANDIDATE}" ;;
        install) install_validated_config "${2:-$SINGBOX_CANDIDATE}" "${3:-$SINGBOX_CONFIG}" "${4:-$SINGBOX_BACKUP}" ;;
        restore) restore_backup "${2:-$SINGBOX_CONFIG}" "${3:-$SINGBOX_BACKUP}" ;;
        cleanup) cleanup_candidate "${2:-$SINGBOX_CANDIDATE}" ;;
        *) printf "%s\n" "Usage: validator.sh {validate|install|restore|cleanup} ..." >&2; exit 2 ;;
    esac
fi
