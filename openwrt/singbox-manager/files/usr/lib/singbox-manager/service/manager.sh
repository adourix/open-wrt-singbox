#!/bin/sh
# shellcheck disable=SC1091
MANAGER_LIB=${MANAGER_LIB:-/usr/lib/singbox-manager}
CONFIG_DIR=${CONFIG_DIR:-/etc/singbox}
CONFIG=${CONFIG:-$CONFIG_DIR/config.json}
CANDIDATE=${CANDIDATE:-$CONFIG_DIR/config.json.new}
BACKUP=${BACKUP:-$CONFIG_DIR/config.json.bak}
PENDING=${PENDING:-$CONFIG_DIR/config.pending}
PENDING_STATE=${PENDING_STATE:-$CONFIG_DIR/state.pending.json}
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
get_proxy_url() {
    if [ "${SINGBOX_PROXY_URL+x}" = x ]; then printf '%s' "$SINGBOX_PROXY_URL"; else uci -q get singbox.main.proxy_url 2>/dev/null; fi
}
get_allow_insecure() {
    if [ "${SINGBOX_ALLOW_INSECURE+x}" = x ]; then
        case "$SINGBOX_ALLOW_INSECURE" in 1|yes|true) printf '%s\n' 1 ;; *) printf '%s\n' 0 ;; esac
        return 0
    fi
    case "$(uci -q get singbox.main.allow_insecure 2>/dev/null)" in 1|yes|true) printf '%s\n' 1 ;; *) printf '%s\n' 0 ;; esac
}
get_auto_start() {
    if [ "${SINGBOX_AUTO_START+x}" = x ]; then printf '%s\n' "$SINGBOX_AUTO_START"; else uci -q get singbox.main.auto_start 2>/dev/null; fi
}
set_enabled() { uci set singbox.main.enabled="$1" && uci commit singbox; }
sync_autostart() {
    case "$(get_auto_start)" in 1|yes|true) "$INIT" enable ;; *) "$INIT" disable ;; esac
}
persist_desired_state() {
    uci set singbox.main.proxy_url="$1" || return 1
    uci set singbox.main.allow_insecure="$2" || return 1
    uci set singbox.main.auto_start="$3" || return 1
    uci commit singbox || return 1
    chmod 600 /etc/config/singbox 2>/dev/null || true
}
write_pending_state() {
    umask 077
    jq -cn --arg proxy_url "$1" --arg allow_insecure "$2" --arg auto_start "$3" --arg enabled "$4" \
        '{proxy_url:$proxy_url,allow_insecure:$allow_insecure,auto_start:$auto_start,enabled:$enabled}' > "$PENDING_STATE" || return 1
    chmod 600 "$PENDING_STATE" || return 1
}
restore_pending_uci() {
    [ -f "$PENDING_STATE" ] || return 1
    old_proxy_url=$(jq -er '.proxy_url | strings' "$PENDING_STATE") || return 1
    old_allow_insecure=$(jq -er '.allow_insecure | strings' "$PENDING_STATE") || return 1
    old_auto_start=$(jq -er '.auto_start | strings' "$PENDING_STATE") || return 1
    old_enabled=$(jq -er '.enabled | strings' "$PENDING_STATE") || return 1
    uci set singbox.main.proxy_url="$old_proxy_url" || return 1
    uci set singbox.main.allow_insecure="$old_allow_insecure" || return 1
    uci set singbox.main.auto_start="$old_auto_start" || return 1
    uci set singbox.main.enabled="$old_enabled" || return 1
    uci commit singbox || return 1
    chmod 600 /etc/config/singbox 2>/dev/null || true
    printf '%s\n' "$old_enabled|$old_auto_start"
}
config_valid() { [ -f "$CONFIG" ] && "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1; }
version_valid() { load_core && check_singbox_version; }
tun_exists() { command -v ip >/dev/null 2>&1 && ip link show singtun0 >/dev/null 2>&1; }
routing_exists() { command -v ip >/dev/null 2>&1 && ip route show table all 2>/dev/null | grep -q '[[:space:]]dev singtun0\([[:space:]]\|$\)'; }
process_running() { "$INIT" running >/dev/null 2>&1; }
connectivity_test() { command -v uclient-fetch >/dev/null 2>&1 || return 1; uclient-fetch -q -T 8 -O /dev/null https://api.ipify.org >/dev/null 2>&1; }
restore_current_config() {
    if [ -f "$BACKUP" ]; then
        restore_backup "$CONFIG" "$BACKUP"
    else
        rm -f "$CONFIG" "$CANDIDATE"
    fi
}

validate() { config_valid && printf '%s\n' 'Configuration: valid' && return 0; printf '%s\n' 'Configuration: invalid'; return 1; }
status() {
    if process_running; then printf '%s\n' 'State: RUNNING'; else
        if [ "$(uci -q get singbox.main.enabled 2>/dev/null)" = "1" ]; then printf '%s\n' 'State: ERROR'; else printf '%s\n' 'State: STOPPED'; fi
    fi
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
restore_previous_state() {
    previous_proxy_url=$1; previous_allow_insecure=$2; previous_auto_start=$3; previous_enabled=$4
    uci set singbox.main.proxy_url="$previous_proxy_url" || return 1
    uci set singbox.main.allow_insecure="$previous_allow_insecure" || return 1
    uci set singbox.main.auto_start="$previous_auto_start" || return 1
    uci set singbox.main.enabled="$previous_enabled" || return 1
    uci commit singbox || return 1
    chmod 600 /etc/config/singbox 2>/dev/null || true
    case "$previous_auto_start" in 1|yes|true) "$INIT" enable ;; *) "$INIT" disable ;; esac
    if [ "$previous_enabled" = "1" ]; then "$INIT" restart || return 1; verify_runtime; return $?; fi
    "$INIT" stop
}
rollback_pending() {
    load_core || return 1
    cancel_rollback_timer
    restore_current_config || return 1
    if [ -f "$PENDING_STATE" ]; then
        old_state=$(restore_pending_uci) || return 1
        old_enabled=${old_state%%|*}; old_auto_start=${old_state#*|}
        case "$old_auto_start" in 1|yes|true) "$INIT" enable ;; *) "$INIT" disable ;; esac
        if [ "$old_enabled" = "1" ]; then
            "$INIT" restart || return 1
            verify_runtime || { set_enabled 0 >/dev/null 2>&1 || true; "$INIT" stop >/dev/null 2>&1 || true; return 1; }
        else
            "$INIT" stop || return 1
        fi
    else
        set_enabled 0 || return 1
        "$INIT" stop || return 1
    fi
    rm -f "$PENDING" "$PENDING_STATE"
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
    config_valid || { printf '%s\n' 'Configuration is invalid or missing' >&2; return 1; }
    previous_enabled=$(uci -q get singbox.main.enabled 2>/dev/null || true)
    [ "$previous_enabled" = "1" ] || previous_enabled=0
    set_enabled 1 || return 1
    sync_autostart || true
    if ! "$INIT" start; then
        set_enabled "$previous_enabled" >/dev/null 2>&1 || true
        return 1
    fi
    if ! verify_runtime; then
        printf '%s\n' 'Runtime verification failed' >&2
        "$INIT" stop >/dev/null 2>&1 || true
        set_enabled "$previous_enabled" >/dev/null 2>&1 || true
        return 1
    fi
}
stop() {
    if [ -f "$PENDING" ] || [ -f "$PENDING_STATE" ]; then
        cancel_rollback_timer
        restore_current_config || return 1
        restore_pending_uci >/dev/null 2>&1 || true
        set_enabled 0 || return 1
        "$INIT" stop || return 1
        rm -f "$PENDING" "$PENDING_STATE"
        return 0
    fi
    set_enabled 0 || return 1
    "$INIT" stop || return 1
}
restart() {
    set_enabled 1 || return 1
    sync_autostart || true
    "$INIT" restart
}
manager_enable() { set_enabled 1 || return 1; "$INIT" enable; }
manager_disable() { set_enabled 0 || return 1; "$INIT" disable; }
verify_runtime() { sleep 1; process_running && tun_exists && routing_exists && connectivity_test; }
confirm() {
    [ -f "$PENDING" ] || return 0
    if ! verify_runtime; then
        printf '%s\n' 'Current configuration failed runtime verification; rolling back' >&2
        rollback_pending >/dev/null 2>&1 || true
        return 1
    fi
    cancel_rollback_timer
    rm -f "$PENDING" "$PENDING_STATE"
    printf '%s\n' 'Configuration confirmed'
}
apply() {
    [ ! -f "$PENDING" ] && [ ! -f "$PENDING_STATE" ] || { printf '%s\n' 'Another apply is awaiting confirmation' >&2; return 1; }
    url=$(get_proxy_url) || { printf '%s\n' 'Unable to read proxy URL' >&2; return 1; }
    [ -n "$url" ] || { printf '%s\n' 'Proxy URL is empty' >&2; return 1; }
    allow_insecure=$(get_allow_insecure); auto_start=$(get_auto_start)
    load_core || return 1
    check_singbox_version || { printf '%s\n' 'Unsupported sing-box version' >&2; return 1; }
    previous_proxy_url=$(uci -q get singbox.main.proxy_url 2>/dev/null || true)
    previous_allow_insecure=$(uci -q get singbox.main.allow_insecure 2>/dev/null || true)
    previous_auto_start=$(uci -q get singbox.main.auto_start 2>/dev/null || true)
    previous_enabled=$(uci -q get singbox.main.enabled 2>/dev/null || true)
    protocol=$(detect_protocol "$url") || { printf '%s\n' 'Unsupported proxy protocol' >&2; return 1; }
    case "$protocol" in vmess) profile=$(vmess_parse "$url") || return 1 ;; vless) profile=$(VLESS_ALLOW_INSECURE="$allow_insecure" vless_parse "$url") || return 1 ;; *) printf '%s\n' 'Unsupported proxy protocol' >&2; return 1 ;; esac
    config=$(generate_config "$profile") || return 1
    umask 077; mkdir -p "$CONFIG_DIR" || return 1; rm -f "$CANDIDATE"
    printf '%s' "$config" > "$CANDIDATE" || return 1
    chmod 600 "$CANDIDATE" || { rm -f "$CANDIDATE"; return 1; }
    install_validated_config "$CANDIDATE" "$CONFIG" "$BACKUP" || { rm -f "$CANDIDATE"; return 1; }
    set_enabled 1 || return 1; sync_autostart || true
    if ! "$INIT" restart; then
        printf '%s\n' 'Service restart failed; restoring previous configuration' >&2
        restore_current_config >/dev/null 2>&1 || true
        restore_previous_state "$previous_proxy_url" "$previous_allow_insecure" "$previous_auto_start" "$previous_enabled" >/dev/null 2>&1 || true
        return 1
    fi
    if ! verify_runtime; then
        printf '%s\n' 'Runtime verification failed; restoring previous configuration' >&2
        restore_current_config >/dev/null 2>&1 || true
        if ! restore_previous_state "$previous_proxy_url" "$previous_allow_insecure" "$previous_auto_start" "$previous_enabled" >/dev/null 2>&1; then
            set_enabled 0 >/dev/null 2>&1 || true; "$INIT" stop >/dev/null 2>&1 || true
        fi
        return 1
    fi
    if ! write_pending_state "$previous_proxy_url" "$previous_allow_insecure" "$previous_auto_start" "$previous_enabled"; then
        printf '%s\n' 'Unable to create rollback state; restoring previous configuration' >&2
        restore_current_config >/dev/null 2>&1 || true
        restore_previous_state "$previous_proxy_url" "$previous_allow_insecure" "$previous_auto_start" "$previous_enabled" >/dev/null 2>&1 || true
        return 1
    fi
    if ! schedule_rollback; then
        printf '%s\n' 'Unable to schedule rollback; restoring previous configuration' >&2
        restore_current_config >/dev/null 2>&1 || true
        restore_previous_state "$previous_proxy_url" "$previous_allow_insecure" "$previous_auto_start" "$previous_enabled" >/dev/null 2>&1 || true
        rm -f "$PENDING" "$PENDING_STATE"
        return 1
    fi
    if ! persist_desired_state "$url" "$allow_insecure" "$auto_start"; then
        printf '%s\n' 'Unable to persist configuration; restoring previous configuration' >&2
        restore_current_config >/dev/null 2>&1 || true
        restore_previous_state "$previous_proxy_url" "$previous_allow_insecure" "$previous_auto_start" "$previous_enabled" >/dev/null 2>&1 || true
        cancel_rollback_timer; rm -f "$PENDING" "$PENDING_STATE"
        return 1
    fi
    printf '%s\n' 'Configuration applied; confirmation required'
}
recovery() {
    load_core || return 1; cancel_rollback_timer
    "$INIT" stop >/dev/null 2>&1 || true
    [ ! -x "$FIREWALL" ] || "$FIREWALL" cleanup >/dev/null 2>&1 || true
    if [ -f "$BACKUP" ]; then
        restore_backup "$CONFIG" "$BACKUP" || return 1
        if [ -f "$PENDING_STATE" ]; then
            old_state=$(restore_pending_uci) || return 1
            old_enabled=${old_state%%|*}; old_auto_start=${old_state#*|}
            case "$old_auto_start" in 1|yes|true) "$INIT" enable ;; *) "$INIT" disable ;; esac
            if [ "$old_enabled" = "1" ]; then "$INIT" restart || return 1; else "$INIT" stop || return 1; fi
        else
            set_enabled 0 || return 1; "$INIT" stop
        fi
        rm -f "$PENDING" "$PENDING_STATE"
    else
        rm -f "$PENDING" "$PENDING_STATE"; set_enabled 0 || return 1; "$INIT" stop
    fi
}
case "${1:-}" in
    status) status ;; start) start ;; stop) stop ;; restart) restart ;; enable) manager_enable ;; disable) manager_disable ;; apply) apply ;; confirm) confirm ;; validate) validate ;; health) health ;; recovery) recovery ;;
    *) printf '%s\n' 'Usage: singbox-manager {status|start|stop|restart|enable|disable|apply|confirm|validate|health|recovery}' >&2; exit 2 ;;
esac
