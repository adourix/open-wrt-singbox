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
CONNECTIVITY_TIMEOUT=${CONNECTIVITY_TIMEOUT:-3}
CONNECTIVITY_TRIES=${CONNECTIVITY_TRIES:-2}

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
    if [ "${SINGBOX_AUTO_START+x}" = x ]; then
        case "$SINGBOX_AUTO_START" in 1|yes|true) printf '%s\n' 1 ;; *) printf '%s\n' 0 ;; esac
    else
        case "$(uci -q get singbox.main.auto_start 2>/dev/null)" in 1|yes|true) printf '%s\n' 1 ;; *) printf '%s\n' 0 ;; esac
    fi
}
set_enabled() { uci set singbox.main.enabled="$1" && uci commit singbox; chmod 600 /etc/config/singbox 2>/dev/null || true; }
sync_autostart() { case "$(get_auto_start)" in 1) "$INIT" enable ;; *) "$INIT" disable ;; esac; }
persist_desired_state() {
    uci set singbox.main.proxy_url="$1" || return 1
    uci set singbox.main.allow_insecure="$2" || return 1
    uci set singbox.main.auto_start="$3" || return 1
    uci set singbox.main.enabled="$4" || return 1
    uci commit singbox || return 1
    chmod 600 /etc/config/singbox 2>/dev/null || true
}
capture_previous_state() {
    PREVIOUS_PROXY_URL=$(uci -q get singbox.main.proxy_url 2>/dev/null || true)
    PREVIOUS_ALLOW_INSECURE=$(uci -q get singbox.main.allow_insecure 2>/dev/null || true)
    PREVIOUS_AUTO_START=$(uci -q get singbox.main.auto_start 2>/dev/null || true)
    PREVIOUS_ENABLED=$(uci -q get singbox.main.enabled 2>/dev/null || true)
    [ "$PREVIOUS_ENABLED" = "1" ] || PREVIOUS_ENABLED=0
    case "$PREVIOUS_AUTO_START" in 1|yes|true) PREVIOUS_AUTO_START=1 ;; *) PREVIOUS_AUTO_START=0 ;; esac
}
write_pending_state() {
    umask 077
    jq -cn --arg proxy_url "$1" --arg allow_insecure "$2" --arg auto_start "$3" --arg enabled "$4" \
        '{proxy_url:$proxy_url,allow_insecure:$allow_insecure,auto_start:$auto_start,enabled:$enabled}' > "$PENDING_STATE" || return 1
    chmod 600 "$PENDING_STATE"
}
read_pending_state() {
    [ -f "$PENDING_STATE" ] || return 1
    PENDING_PROXY_URL=$(jq -er '.proxy_url | strings' "$PENDING_STATE") || return 1
    PENDING_ALLOW_INSECURE=$(jq -er '.allow_insecure | strings' "$PENDING_STATE") || return 1
    PENDING_AUTO_START=$(jq -er '.auto_start | strings' "$PENDING_STATE") || return 1
    PENDING_ENABLED=$(jq -er '.enabled | strings' "$PENDING_STATE") || return 1
}
restore_previous_uci() {
    read_pending_state || return 1
    persist_desired_state "$PENDING_PROXY_URL" "$PENDING_ALLOW_INSECURE" "$PENDING_AUTO_START" "$PENDING_ENABLED"
}
config_valid() { [ -f "$CONFIG" ] && "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1; }
version_valid() { load_core && check_singbox_version; }
tun_exists() { command -v ip >/dev/null 2>&1 && ip link show tun0 >/dev/null 2>&1; }
routing_exists() { command -v ip >/dev/null 2>&1 && ip route show table all 2>/dev/null | grep -q '[[:space:]]dev tun0\([[:space:]]\|$\)'; }
process_running() { command -v pidof >/dev/null 2>&1 && pidof "$SINGBOX_BIN" >/dev/null 2>&1; }
connectivity_test() {
    command -v uclient-fetch >/dev/null 2>&1 || return 1
    timeout=$CONNECTIVITY_TIMEOUT
    tries=$CONNECTIVITY_TRIES
    case "$timeout" in ''|*[!0-9]*) timeout=3 ;; esac
    case "$tries" in ''|*[!0-9]*|0) tries=2 ;; esac
    while [ "$tries" -gt 0 ]; do
        if uclient-fetch -q -T "$timeout" -O /dev/null https://api.ipify.org >/dev/null 2>&1; then return 0; fi
        tries=$((tries - 1))
        [ "$tries" -gt 0 ] && sleep 1
    done
    return 1
}
runtime_failure() {
    if ! process_running; then printf '%s\n' 'process is not running' >&2; return 1; fi
    if ! tun_exists; then printf '%s\n' 'TUN interface tun0 is missing' >&2; return 1; fi
    if ! routing_exists; then printf '%s\n' 'tun0 routing is missing' >&2; return 1; fi
    if ! connectivity_test; then printf '%s\n' 'connectivity test failed' >&2; return 1; fi
    return 0
}
verify_runtime() { sleep 1; runtime_failure; }
restore_current_config() {
    if [ -f "$BACKUP" ]; then
        if restore_backup "$CONFIG" "$BACKUP"; then return 0; fi
        logger -t singbox "configured backup is invalid; removing active configuration"
    fi
    rm -f "$CONFIG" "$CANDIDATE"
    return 0
}
stop_runtime() { "$INIT" stop >/dev/null 2>&1 || true; [ ! -x "$FIREWALL" ] || "$FIREWALL" cleanup >/dev/null 2>&1 || true; }
restore_and_recover() {
    stop_runtime
    restore_current_config || return 1
    if ! restore_previous_uci; then
        set_enabled 0 >/dev/null 2>&1 || true; "$INIT" disable >/dev/null 2>&1 || true
        rm -f "$PENDING" "$PENDING_STATE"; return 1
    fi
    if [ "$PENDING_ENABLED" = "1" ]; then
        "$INIT" enable >/dev/null 2>&1 || true
        if "$INIT" start >/dev/null 2>&1 && verify_runtime; then :; else
            logger -t singbox "previous sing-box state could not be restored; disabling safely"
            set_enabled 0 >/dev/null 2>&1 || true; "$INIT" disable >/dev/null 2>&1 || true; stop_runtime
            rm -f "$PENDING" "$PENDING_STATE"; return 1
        fi
    else
        set_enabled 0 >/dev/null 2>&1 || true; "$INIT" disable >/dev/null 2>&1 || true; stop_runtime
    fi
    rm -f "$PENDING" "$PENDING_STATE"
    return 0
}
cancel_rollback_timer() {
    [ -f "$ROLLBACK_PID" ] || return 0
    pid=$(cat "$ROLLBACK_PID" 2>/dev/null)
    case "$pid" in ''|*[!0-9]*) ;; *) [ "${ROLLBACK_TIMER_CHILD:-0}" = "1" ] || kill "$pid" 2>/dev/null || true ;; esac
    rm -f "$ROLLBACK_PID"
}
schedule_rollback() {
    cancel_rollback_timer
    printf '%s\n' pending > "$PENDING" || return 1
    ( sleep "$ROLLBACK_DELAY"; [ -f "$PENDING" ] || exit 0; ROLLBACK_TIMER_CHILD=1 rollback_pending >/dev/null 2>&1 || true ) >/dev/null 2>&1 &
    echo "$!" > "$ROLLBACK_PID"
    chmod 600 "$ROLLBACK_PID" 2>/dev/null || true
}
rollback_pending() { load_core || return 1; cancel_rollback_timer; restore_and_recover; }
validate() { if config_valid; then printf '%s\n' 'Configuration: valid'; return 0; fi; printf '%s\n' 'Configuration: invalid'; return 1; }
status() {
    if process_running; then printf '%s\n' 'State: RUNNING'; elif [ "$(uci -q get singbox.main.enabled 2>/dev/null)" = "1" ]; then printf '%s\n' 'State: ERROR'; else printf '%s\n' 'State: STOPPED'; fi
    if config_valid; then printf '%s\n' 'Config: valid'; else printf '%s\n' 'Config: invalid'; fi
    if tun_exists; then printf '%s\n' 'TUN: tun0'; else printf '%s\n' 'TUN: absent'; fi
    if routing_exists; then printf '%s\n' 'Routing: OK'; else printf '%s\n' 'Routing: absent'; fi
    if [ -f "$PENDING" ] || [ -f "$PENDING_STATE" ]; then printf '%s\n' 'Apply: awaiting confirmation'; else printf '%s\n' 'Apply: confirmed'; fi
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
start() {
    [ ! -f "$PENDING" ] && [ ! -f "$PENDING_STATE" ] || { printf '%s\n' 'Configuration confirmation is pending' >&2; return 1; }
    config_valid || { printf '%s\n' 'Configuration is invalid or missing' >&2; return 1; }
    if process_running && tun_exists && routing_exists; then return 0; fi
    previous_enabled=$(uci -q get singbox.main.enabled 2>/dev/null || true); [ "$previous_enabled" = "1" ] || previous_enabled=0
    set_enabled 1 || return 1; sync_autostart || { set_enabled "$previous_enabled" >/dev/null 2>&1 || true; return 1; }
    if ! "$INIT" start >/dev/null 2>&1; then set_enabled "$previous_enabled" >/dev/null 2>&1 || true; return 1; fi
    if ! verify_runtime; then printf '%s\n' 'Runtime verification failed' >&2; stop_runtime; set_enabled "$previous_enabled" >/dev/null 2>&1 || true; return 1; fi
}
stop() {
    if [ -f "$PENDING" ] || [ -f "$PENDING_STATE" ]; then
        rollback_pending || { printf '%s\n' 'Unable to safely roll back pending configuration' >&2; return 1; }
        set_enabled 0 || return 1; "$INIT" disable >/dev/null 2>&1 || true; stop_runtime; return 0
    fi
    set_enabled 0 || return 1; "$INIT" disable >/dev/null 2>&1 || true; stop_runtime
}
restart() {
    [ ! -f "$PENDING" ] && [ ! -f "$PENDING_STATE" ] || { printf '%s\n' 'Configuration confirmation is pending' >&2; return 1; }
    config_valid || { printf '%s\n' 'Configuration is invalid or missing' >&2; return 1; }
    set_enabled 1 || return 1
    if ! "$INIT" restart >/dev/null 2>&1 || ! verify_runtime; then printf '%s\n' 'Runtime verification failed' >&2; stop_runtime; set_enabled 0 >/dev/null 2>&1 || true; return 1; fi
}
manager_enable() { set_enabled 1 || return 1; "$INIT" enable; }
manager_disable() { set_enabled 0 || return 1; "$INIT" disable; }
confirm() {
    [ -f "$PENDING" ] || { printf '%s\n' 'No configuration is awaiting confirmation' >&2; return 1; }
    if ! verify_runtime; then
        printf '%s\n' 'Current configuration failed runtime verification; rolling back' >&2
        rollback_pending || { printf '%s\n' 'Rollback failed; sing-box was disabled for safety' >&2; set_enabled 0 >/dev/null 2>&1 || true; stop_runtime; }
        return 1
    fi
    cancel_rollback_timer; rm -f "$PENDING" "$PENDING_STATE"; printf '%s\n' 'Configuration confirmed'
}
apply() {
    [ ! -f "$PENDING" ] && [ ! -f "$PENDING_STATE" ] || { printf '%s\n' 'Another apply is awaiting confirmation' >&2; return 1; }
    url=$(get_proxy_url) || { printf '%s\n' 'Unable to read proxy URL' >&2; return 1; }; [ -n "$url" ] || { printf '%s\n' 'Proxy URL is empty' >&2; return 1; }
    allow_insecure=$(get_allow_insecure); auto_start=$(get_auto_start)
    load_core || return 1; check_singbox_version || { printf '%s\n' 'Unsupported sing-box version' >&2; return 1; }; capture_previous_state
    protocol=$(detect_protocol "$url") || { printf '%s\n' 'Unsupported proxy protocol' >&2; return 1; }
    case "$protocol" in vmess) profile=$(vmess_parse "$url") || return 1 ;; vless) profile=$(VLESS_ALLOW_INSECURE="$allow_insecure" vless_parse "$url") || return 1 ;; *) printf '%s\n' 'Unsupported proxy protocol' >&2; return 1 ;; esac
    config=$(generate_config "$profile") || return 1
    umask 077; mkdir -p "$CONFIG_DIR" || return 1; rm -f "$CANDIDATE"; printf '%s' "$config" > "$CANDIDATE" || return 1; chmod 600 "$CANDIDATE" || { rm -f "$CANDIDATE"; return 1; }
    install_validated_config "$CANDIDATE" "$CONFIG" "$BACKUP" || { rm -f "$CANDIDATE"; return 1; }
    if ! write_pending_state "$PREVIOUS_PROXY_URL" "$PREVIOUS_ALLOW_INSECURE" "$PREVIOUS_AUTO_START" "$PREVIOUS_ENABLED"; then restore_current_config >/dev/null 2>&1 || true; return 1; fi
    if ! persist_desired_state "$url" "$allow_insecure" "$auto_start" 1 || ! sync_autostart; then printf '%s\n' 'Unable to persist desired state; rolling back' >&2; rollback_pending >/dev/null 2>&1 || true; return 1; fi
    if ! "$INIT" restart >/dev/null 2>&1; then printf '%s\n' 'Service restart failed; rolling back' >&2; rollback_pending >/dev/null 2>&1 || true; return 1; fi
    if ! verify_runtime; then printf '%s\n' 'Runtime verification failed; rolling back' >&2; rollback_pending >/dev/null 2>&1 || true; return 1; fi
    schedule_rollback || { printf '%s\n' 'Unable to start confirmation timer; rolling back' >&2; rollback_pending >/dev/null 2>&1 || true; return 1; }
    printf '%s\n' 'Configuration applied. Confirm it before the safety timer expires.'
}
recovery() {
    if [ -f "$PENDING" ] || [ -f "$PENDING_STATE" ]; then rollback_pending; return $?; fi
    set_enabled 0 || return 1; "$INIT" disable >/dev/null 2>&1 || true; stop_runtime; rm -f "$CANDIDATE"
}
case "${1:-}" in
    status) status ;; validate) validate ;; health) health ;; start) start ;; stop) stop ;; restart) restart ;; enable) manager_enable ;; disable) manager_disable ;; apply) apply ;; confirm) confirm ;; recovery) recovery ;;
    *) printf '%s\n' 'Usage: singbox-manager {status|validate|health|start|stop|restart|enable|disable|apply|confirm|recovery}' >&2; exit 2 ;;
esac
