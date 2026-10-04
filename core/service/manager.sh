#!/bin/sh
# shellcheck disable=SC1091
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
get_proxy_url() { uci -q get singbox.main.proxy_url 2>/dev/null; }
get_bool_option() {
    value=$(uci -q get "singbox.main.$1" 2>/dev/null || true)
    case "$value" in
        1|yes|true) printf '1\n' ;;
        *) printf '0\n' ;;
    esac
}
set_enabled() { uci set singbox.main.enabled="$1" && uci commit singbox; }
sync_autostart() {
    case "$(get_bool_option auto_start)" in
        1) "$INIT" enable ;;
        *) "$INIT" disable ;;
    esac
}
config_valid() { [ -f "$CONFIG" ] && "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1; }
version_valid() { load_core && check_singbox_version; }
tun_exists() { command -v ip >/dev/null 2>&1 && ip link show singtun0 >/dev/null 2>&1; }
routing_exists() {
    command -v ip >/dev/null 2>&1 &&
        ip route show table all 2>/dev/null | grep -q '[[:space:]]dev singtun0\([[:space:]]\|$\)'
}
process_running() { "$INIT" running >/dev/null 2>&1; }
connectivity_test() {
    command -v uclient-fetch >/dev/null 2>&1 || return 1
    uclient-fetch -q -T 8 -O /dev/null https://api.ipify.org >/dev/null 2>&1
}
validate() {
    config_valid && printf '%s\n' 'Configuration: valid' && return 0
    printf '%s\n' 'Configuration: invalid'; return 1
}
status() {
    if process_running; then printf '%s\n' 'Sing-box: running'; else printf '%s\n' 'Sing-box: stopped'; fi
    if config_valid; then printf '%s\n' 'Config: valid'; else printf '%s\n' 'Config: invalid'; fi
    if tun_exists; then printf '%s\n' 'TUN: singtun0'; else printf '%s\n' 'TUN: absent'; fi
    if routing_exists; then printf '%s\n' 'Routing: OK'; else printf '%s\n' 'Routing: absent'; fi
    if [ -f "$PENDING" ]; then printf '%s\n' 'Apply: awaiting confirmation'; else printf '%s\n' 'Apply: confirmed'; fi
}
health() {
    failed=0
    if version_valid; then printf '%s\n' 'sing-box version: OK'; else printf '%s\n' 'sing-box version: UNSUPPORTED'; failed=1; fi
    if command -v "$SINGBOX_BIN" >/dev/null 2>&1; then printf '%s\n' 'sing-box:       OK'; else printf '%s\n' 'sing-box:       MISSING'; failed=1; fi
    if config_valid; then printf '%s\n' 'configuration:  OK'; else printf '%s\n' 'configuration:  ERROR'; failed=1; fi
    if process_running; then printf '%s\n' 'process:        OK'; else printf '%s\n' 'process:        STOPPED'; failed=1; fi
    if tun_exists; then printf '%s\n' 'TUN:            OK'; else printf '%s\n' 'TUN:            ERROR'; failed=1; fi
    if routing_exists; then printf '%s\n' 'routing:        OK'; else printf '%s\n' 'routing:        ERROR'; failed=1; fi
    return "$failed"
}
cancel_rollback_timer() {
    [ -f "$ROLLBACK_PID" ] || return 0
    pid=$(cat "$ROLLBACK_PID" 2>/dev/null)
    case "$pid" in *[!0-9]*|'') ;; *) kill "$pid" 2>/dev/null || true ;; esac
    rm -f "$ROLLBACK_PID"
}
read_pending_state() {
    PENDING_ENABLED=0
    PENDING_AUTOSTART=0
    PENDING_HAD_CONFIG=0
    PENDING_PROXY_URL=
    PENDING_ALLOW_INSECURE=0
    [ -f "$PENDING" ] || return 1
    while IFS='=' read -r key value; do
        case "$key" in
            enabled) case "$value" in 0|1) PENDING_ENABLED=$value ;; esac ;;
            auto_start) case "$value" in 0|1) PENDING_AUTOSTART=$value ;; esac ;;
            had_config) case "$value" in 0|1) PENDING_HAD_CONFIG=$value ;; esac ;;
            proxy_url) PENDING_PROXY_URL=$value ;;
            allow_insecure) case "$value" in 0|1) PENDING_ALLOW_INSECURE=$value ;; esac ;;
        esac
    done < "$PENDING"
}
restore_pending_state() {
    read_pending_state || return 1
    if [ "$PENDING_HAD_CONFIG" -eq 1 ]; then
        [ -f "$BACKUP" ] || return 1
        restore_backup "$CONFIG" "$BACKUP" || return 1
    else
        rm -f "$CONFIG"
    fi
    set_enabled "$PENDING_ENABLED" || return 1
    uci set singbox.main.auto_start="$PENDING_AUTOSTART" || return 1
    uci set singbox.main.proxy_url="$PENDING_PROXY_URL" || return 1
    uci set singbox.main.allow_insecure="$PENDING_ALLOW_INSECURE" || return 1
    uci commit singbox || return 1
    sync_autostart || true
    rm -f "$PENDING" "$BACKUP"
}
rollback_pending() {
    load_core || return 1
    cancel_rollback_timer
    restore_pending_state || return 1
    "$INIT" restart
}
schedule_rollback() {
    cancel_rollback_timer
    printf '%s\n' \
        "enabled=$PREVIOUS_ENABLED" \
        "auto_start=$PREVIOUS_AUTOSTART" \
        "had_config=$PREVIOUS_HAD_CONFIG" \
        "proxy_url=$PREVIOUS_PROXY_URL" \
        "allow_insecure=$PREVIOUS_ALLOW_INSECURE" > "$PENDING" || return 1
    chmod 600 "$PENDING" 2>/dev/null || true
    (
        sleep "$ROLLBACK_DELAY"
        [ -f "$PENDING" ] || exit 0
        rollback_pending >/dev/null 2>&1 || true
    ) >/dev/null 2>&1 &
    echo "$!" > "$ROLLBACK_PID"
}
start() {
    set_enabled 1 || return 1
    sync_autostart || true
    "$INIT" start
}
stop() {
    if [ -f "$PENDING" ]; then
        restore_pending_state || return 1
    fi
    set_enabled 0 || return 1
    "$INIT" stop
    cancel_rollback_timer
}
restart() {
    set_enabled 1 || return 1
    sync_autostart || true
    "$INIT" restart
}
manager_enable() {
    set_enabled 1 || return 1
    "$INIT" enable
}
manager_disable() {
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
    rm -f "$PENDING" "$BACKUP"
    printf '%s\n' 'Configuration confirmed'
}
apply() {
    url=$(get_proxy_url) || { printf '%s\n' 'Unable to read proxy URL' >&2; return 1; }
    [ -n "$url" ] || { printf '%s\n' 'Proxy URL is empty' >&2; return 1; }
    load_core || return 1
    check_singbox_version || { printf '%s\n' 'Unsupported sing-box version' >&2; return 1; }
    protocol=$(detect_protocol "$url") || { printf '%s\n' 'Unsupported proxy protocol' >&2; return 1; }
    case "$protocol" in
        vmess) profile=$(vmess_parse "$url") || return 1 ;;
        vless)
            if [ "$(get_bool_option allow_insecure)" -eq 1 ]; then
                profile=$(VLESS_ALLOW_INSECURE=1 vless_parse "$url") || return 1
            else
                profile=$(vless_parse "$url") || return 1
            fi
            ;;
        *) printf '%s\n' 'Unsupported proxy protocol' >&2; return 1 ;;
    esac
    config=$(generate_config "$profile") || return 1
    umask 077
    mkdir -p "$CONFIG_DIR" || return 1

    PREVIOUS_PROXY_URL=$(get_proxy_url)
    PREVIOUS_ENABLED=$(get_bool_option enabled)
    PREVIOUS_AUTOSTART=$(get_bool_option auto_start)
    PREVIOUS_ALLOW_INSECURE=$(get_bool_option allow_insecure)
    if [ -f "$CONFIG" ]; then
        PREVIOUS_HAD_CONFIG=1
    else
        PREVIOUS_HAD_CONFIG=0
    fi

    printf '%s' "$config" > "$CANDIDATE" || return 1
    chmod 600 "$CANDIDATE" || { rm -f "$CANDIDATE"; return 1; }
    install_validated_config "$CANDIDATE" "$CONFIG" "$BACKUP" || return 1

    set_enabled 1 || return 1
    sync_autostart || true
    if ! "$INIT" restart; then
        if [ "$PREVIOUS_HAD_CONFIG" -eq 1 ]; then
            restore_backup "$CONFIG" "$BACKUP" >/dev/null 2>&1 || true
        else
            rm -f "$CONFIG"
        fi
        set_enabled "$PREVIOUS_ENABLED" >/dev/null 2>&1 || true
        uci set singbox.main.auto_start="$PREVIOUS_AUTOSTART" >/dev/null 2>&1 || true
        uci set singbox.main.proxy_url="$PREVIOUS_PROXY_URL" >/dev/null 2>&1 || true
        uci set singbox.main.allow_insecure="$PREVIOUS_ALLOW_INSECURE" >/dev/null 2>&1 || true
        uci commit singbox >/dev/null 2>&1 || true
        sync_autostart || true
        "$INIT" restart >/dev/null 2>&1 || true
        return 1
    fi

    if ! verify_runtime; then
        printf '%s\n' 'Runtime verification failed; restoring previous configuration' >&2
        if [ "$PREVIOUS_HAD_CONFIG" -eq 1 ]; then
            restore_backup "$CONFIG" "$BACKUP" >/dev/null 2>&1 || true
        else
            rm -f "$CONFIG"
        fi
        set_enabled "$PREVIOUS_ENABLED" >/dev/null 2>&1 || true
        uci set singbox.main.auto_start="$PREVIOUS_AUTOSTART" >/dev/null 2>&1 || true
        uci set singbox.main.proxy_url="$PREVIOUS_PROXY_URL" >/dev/null 2>&1 || true
        uci set singbox.main.allow_insecure="$PREVIOUS_ALLOW_INSECURE" >/dev/null 2>&1 || true
        uci commit singbox >/dev/null 2>&1 || true
        sync_autostart || true
        "$INIT" restart >/dev/null 2>&1 || true
        return 1
    fi

    if ! schedule_rollback; then
        printf '%s\n' 'Unable to start rollback timer; restoring previous configuration' >&2
        if [ "$PREVIOUS_HAD_CONFIG" -eq 1 ]; then
            restore_backup "$CONFIG" "$BACKUP" >/dev/null 2>&1 || true
        else
            rm -f "$CONFIG"
        fi
        set_enabled "$PREVIOUS_ENABLED" >/dev/null 2>&1 || true
        uci set singbox.main.auto_start="$PREVIOUS_AUTOSTART" >/dev/null 2>&1 || true
        uci set singbox.main.proxy_url="$PREVIOUS_PROXY_URL" >/dev/null 2>&1 || true
        uci set singbox.main.allow_insecure="$PREVIOUS_ALLOW_INSECURE" >/dev/null 2>&1 || true
        uci commit singbox >/dev/null 2>&1 || true
        sync_autostart || true
        "$INIT" restart >/dev/null 2>&1 || true
        return 1
    fi
    printf '%s\n' 'Configuration applied; confirmation required'
}
recovery() {
    load_core || return 1
    cancel_rollback_timer
    "$INIT" stop >/dev/null 2>&1 || true
    [ ! -x "$FIREWALL" ] || "$FIREWALL" cleanup >/dev/null 2>&1 || true
    if [ -f "$PENDING" ]; then
        restore_pending_state || return 1
        "$INIT" restart
    elif [ -f "$BACKUP" ]; then
        restore_backup "$CONFIG" "$BACKUP" || return 1
        rm -f "$BACKUP"
        set_enabled 1 || return 1
        sync_autostart || true
        "$INIT" restart
    else
        rm -f "$CONFIG"
        set_enabled 0 || return 1
        sync_autostart || true
        "$INIT" stop
    fi
}
case "${1:-}" in
    status) status ;;
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    enable) manager_enable ;;
    disable) manager_disable ;;
    apply) apply ;;
    confirm) confirm ;;
    validate) validate ;;
    health) health ;;
    recovery) recovery ;;
    *) printf '%s\n' 'Usage: singbox-manager {status|start|stop|restart|enable|disable|apply|confirm|validate|health|recovery}' >&2; exit 2 ;;
esac
