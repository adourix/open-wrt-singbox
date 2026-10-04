#!/bin/sh
MANAGER_LIB=${MANAGER_LIB:-/usr/lib/singbox-manager}
CONFIG_DIR=${CONFIG_DIR:-/etc/singbox}
CONFIG=${CONFIG:-$CONFIG_DIR/config.json}
CANDIDATE=${CANDIDATE:-$CONFIG_DIR/config.json.new}
BACKUP=${BACKUP:-$CONFIG_DIR/config.json.bak}
PENDING=${PENDING:-$CONFIG_DIR/config.pending}
ROLLBACK_PID=${ROLLBACK_PID:-/var/run/singbox-manager-rollback.pid}
INIT=${INIT:-/etc/init.d/singbox}
SINGBOX_BIN=${SINGBOX_BIN:-sing-box}
FIREWALL=${FIREWALL:-$MANAGER_LIB/network/firewall.sh}
ROLLBACK_DELAY=${ROLLBACK_DELAY:-60}

load_core() {
    . "$MANAGER_LIB/protocol/detector.sh" || return 1
    . "$MANAGER_LIB/protocol/vmess/parser.sh" || return 1
    . "$MANAGER_LIB/protocol/vless/parser.sh" || return 1
    . "$MANAGER_LIB/config/generator.sh" || return 1
    . "$MANAGER_LIB/config/validator.sh" || return 1
    . "$MANAGER_LIB/config/version.sh" || return 1
}

load_version() {
    . "$MANAGER_LIB/config/version.sh" || return 1
}

get_proxy_url() {
    uci -q get singbox.main.proxy_url 2>/dev/null
}

set_enabled() {
    uci set singbox.main.enabled="$1" && uci commit singbox
}

sync_autostart() {
    case "$(uci -q get singbox.main.auto_start 2>/dev/null)" in
        1|yes|true) "$INIT" enable ;;
        *) "$INIT" disable ;;
    esac
}

config_valid() {
    [ -f "$CONFIG" ] && "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1
}

version_valid() {
    load_version || return 1
    check_singbox_version
}

tun_exists() {
    command -v ip >/dev/null 2>&1 &&
        ip link show singtun0 >/dev/null 2>&1
}

routing_exists() {
    command -v ip >/dev/null 2>&1 &&
        ip route show table all 2>/dev/null | grep -q '[[:space:]]dev singtun0\([[:space:]]\|$\)'
}

process_running() {
    "$INIT" running >/dev/null 2>&1
}

connectivity_test() {
    command -v wget >/dev/null 2>&1 || return 1
    wget -q -T 8 -O /dev/null https://api.ipify.org
}

validate() {
    if config_valid; then
        printf '%s\n' 'Configuration: valid'
    else
        printf '%s\n' 'Configuration: invalid'
        return 1
    fi
}

status() {
    process_running && printf '%s\n' 'Sing-box: running' ||
        printf '%s\n' 'Sing-box: stopped'
    config_valid && printf '%s\n' 'Config: valid' ||
        printf '%s\n' 'Config: invalid'
    tun_exists && printf '%s\n' 'TUN: singtun0' ||
        printf '%s\n' 'TUN: absent'
    routing_exists && printf '%s\n' 'Routing: OK' ||
        printf '%s\n' 'Routing: absent'
    [ -f "$PENDING" ] &&
        printf '%s\n' 'Apply: awaiting confirmation' ||
        printf '%s\n' 'Apply: confirmed'
}

health() {
    failed=0
    if version_valid; then
        printf '%s\n' 'sing-box version: OK'
    else
        printf '%s\n' 'sing-box version: UNSUPPORTED'
        failed=1
    fi
    if command -v "$SINGBOX_BIN" >/dev/null 2>&1; then
        printf '%s\n' 'sing-box:       OK'
    else
        printf '%s\n' 'sing-box:       MISSING'
        failed=1
    fi
    if config_valid; then
        printf '%s\n' 'configuration:  OK'
    else
        printf '%s\n' 'configuration:  ERROR'
        failed=1
    fi
    if process_running; then
        printf '%s\n' 'process:        OK'
    else
        printf '%s\n' 'process:        STOPPED'
        failed=1
    fi
    if tun_exists; then
        printf '%s\n' 'TUN:            OK'
    else
        printf '%s\n' 'TUN:            ERROR'
        failed=1
    fi
    if routing_exists; then
        printf '%s\n' 'routing:        OK'
    else
        printf '%s\n' 'routing:        ERROR'
        failed=1
    fi
    return "$failed"
}

cancel_rollback_timer() {
    if [ -f "$ROLLBACK_PID" ]; then
        pid=$(cat "$ROLLBACK_PID" 2>/dev/null)
        case "$pid" in
            *[!0-9]*|'') ;;
            *) kill "$pid" 2>/dev/null || true ;;
        esac
        rm -f "$ROLLBACK_PID"
    fi
}

rollback_pending() {
    load_core || return 1
    cancel_rollback_timer
    [ -f "$BACKUP" ] || return 1
    restore_backup "$CONFIG" "$BACKUP" || return 1
    rm -f "$PENDING"
    set_enabled 1 || return 1
    "$INIT" restart
}

schedule_rollback() {
    cancel_rollback_timer
    printf '%s\n' pending > "$PENDING" || return 1
    (
        sleep "$ROLLBACK_DELAY"
        [ -f "$PENDING" ] || exit 0
        rollback_pending >/dev/null 2>&1 || true
    ) >/dev/null 2>&1 &
    echo "$!" > "$ROLLBACK_PID"
}

start() {
    if [ -f "$PENDING" ] && [ -f "$BACKUP" ]; then
        rollback_pending || return 1
    fi
    set_enabled 1 || return 1
    sync_autostart || true
    "$INIT" start
}

stop() {
    set_enabled 0 || return 1
    "$INIT" stop
    cancel_rollback_timer
    rm -f "$PENDING"
}

restart() {
    set_enabled 1 || return 1
    sync_autostart || true
    "$INIT" restart
}

enable() {
    set_enabled 1 || return 1
    "$INIT" enable
}

disable() {
    set_enabled 0 || return 1
    "$INIT" disable
}

verify_runtime() {
    sleep 1
    process_running && tun_exists && routing_exists && connectivity_test
}

confirm() {
    [ -f "$PENDING" ] || return 0
    cancel_rollback_timer
    rm -f "$PENDING"
    printf '%s\n' 'Configuration confirmed'
}

apply() {
    url=$(get_proxy_url) || {
        printf '%s\n' 'Unable to read proxy URL' >&2
        return 1
    }
    [ -n "$url" ] || {
        printf '%s\n' 'Proxy URL is empty' >&2
        return 1
    }

    load_core || return 1
    version_valid || {
        printf '%s\n' 'Unsupported sing-box version' >&2
        return 1
    }

    protocol=$(detect_protocol "$url") || {
        printf '%s\n' 'Unsupported proxy protocol' >&2
        return 1
    }

    case "$protocol" in
        vmess) profile=$(vmess_parse "$url") ;;
        vless) profile=$(vless_parse "$url") ;;
        *)
            printf '%s\n' 'Unsupported proxy protocol' >&2
            return 1
            ;;
    esac

    [ -n "$profile" ] || return 1

    config=$(generate_config "$profile") || return 1
    umask 077
    mkdir -p "$CONFIG_DIR" || return 1
    printf '%s' "$config" > "$CANDIDATE" || return 1
    chmod 600 "$CANDIDATE" || {
        rm -f "$CANDIDATE"
        return 1
    }

    install_validated_config "$CANDIDATE" "$CONFIG" "$BACKUP" || return 1
    set_enabled 1 || return 1
    sync_autostart || true

    "$INIT" restart || {
        restore_backup "$CONFIG" "$BACKUP" >/dev/null 2>&1 || true
        set_enabled 0 >/dev/null 2>&1 || true
        "$INIT" restart >/dev/null 2>&1 || true
        return 1
    }

    if ! verify_runtime; then
        printf '%s\n' 'Runtime verification failed; restoring previous configuration' >&2
        restore_backup "$CONFIG" "$BACKUP" >/dev/null 2>&1 || true
        set_enabled 0 >/dev/null 2>&1 || true
        "$INIT" restart >/dev/null 2>&1 || true
        return 1
    fi

    schedule_rollback || return 1
    printf '%s\n' 'Configuration applied; confirmation required'
    return 0
}

recovery() {
    load_core || return 1
    cancel_rollback_timer
    "$INIT" stop >/dev/null 2>&1 || true
    [ -x "$FIREWALL" ] && "$FIREWALL" cleanup >/dev/null 2>&1 || true

    if [ -f "$BACKUP" ]; then
        restore_backup "$CONFIG" "$BACKUP" || return 1
        rm -f "$PENDING"
        set_enabled 1 || return 1
        sync_autostart || true
        "$INIT" restart
    else
        rm -f "$PENDING"
        set_enabled 0 || return 1
        "$INIT" stop
    fi
}

case "${1:-}" in
    status) status ;;
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    enable) enable ;;
    disable) disable ;;
    apply) apply ;;
    confirm) confirm ;;
    validate) validate ;;
    health) health ;;
    recovery) recovery ;;
    *)
        printf '%s\n' 'Usage: singbox-manager {status|start|stop|restart|enable|disable|apply|confirm|validate|health|recovery}' >&2
        exit 2
        ;;
esac
