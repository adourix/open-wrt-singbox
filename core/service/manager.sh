#!/bin/sh
MANAGER_LIB=${MANAGER_LIB:-/usr/lib/singbox-manager}
CONFIG_DIR=${CONFIG_DIR:-/etc/singbox}
CONFIG=${CONFIG:-$CONFIG_DIR/config.json}
CANDIDATE=${CANDIDATE:-$CONFIG_DIR/config.json.new}
BACKUP=${BACKUP:-$CONFIG_DIR/config.json.bak}
INIT=${INIT:-/etc/init.d/singbox}
SINGBOX_BIN=${SINGBOX_BIN:-sing-box}

load_core() {
    . "$MANAGER_LIB/protocol/detector.sh" || return 1
    . "$MANAGER_LIB/protocol/vmess/parser.sh" || return 1
    . "$MANAGER_LIB/protocol/vless/parser.sh" || return 1
    . "$MANAGER_LIB/config/generator.sh" || return 1
    . "$MANAGER_LIB/config/validator.sh" || return 1
}
get_proxy_url() { uci -q get singbox.main.proxy_url 2>/dev/null; }
set_enabled() { uci set singbox.main.enabled="$1" && uci commit singbox; }

validate() {
    [ -f "$CONFIG" ] || { printf "%s\n" "Configuration: missing"; return 1; }
    "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1 && printf "%s\n" "Configuration: valid" || { printf "%s\n" "Configuration: invalid"; return 1; }
}

status() {
    "$INIT" running >/dev/null 2>&1 && printf "%s\n" "Sing-box: running" || printf "%s\n" "Sing-box: stopped"
    if [ -f "$CONFIG" ] && "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1; then printf "%s\n" "Config: valid"; elif [ -f "$CONFIG" ]; then printf "%s\n" "Config: invalid"; else printf "%s\n" "Config: missing"; fi
}

health() {
    failed=0
    command -v "$SINGBOX_BIN" >/dev/null 2>&1 && printf "%s\n" "sing-box: OK" || { printf "%s\n" "sing-box: MISSING"; failed=1; }
    [ -f "$CONFIG" ] && "$SINGBOX_BIN" check -c "$CONFIG" >/dev/null 2>&1 && printf "%s\n" "configuration: OK" || { printf "%s\n" "configuration: ERROR"; failed=1; }
    "$INIT" running >/dev/null 2>&1 && printf "%s\n" "process: OK" || { printf "%s\n" "process: STOPPED"; failed=1; }
    command -v ip >/dev/null 2>&1 && ip link show singtun0 >/dev/null 2>&1 && printf "%s\n" "TUN: OK" || { printf "%s\n" "TUN: NOT_FOUND"; failed=1; }
    return "$failed"
}

start() { set_enabled 1 || return 1; "$INIT" start; }
stop() { set_enabled 0 || return 1; "$INIT" stop; }
restart() { set_enabled 1 || return 1; "$INIT" restart; }
enable() { "$INIT" enable; }
disable() { "$INIT" disable; }

apply() {
    url=$(get_proxy_url) || { printf "%s\n" "Unable to read proxy URL" >&2; return 1; }
    [ -n "$url" ] || { printf "%s\n" "Proxy URL is empty" >&2; return 1; }
    load_core || return 1
    protocol=$(detect_protocol "$url") || { printf "%s\n" "Unsupported proxy protocol" >&2; return 1; }
    case "$protocol" in vmess) profile=$(vmess_parse "$url");; vless) profile=$(vless_parse "$url");; *) return 1;; esac
    [ -n "$profile" ] || return 1
    config=$(generate_config "$profile") || return 1
    umask 077
    mkdir -p "$CONFIG_DIR" || return 1
    printf "%s" "$config" > "$CANDIDATE" || return 1
    chmod 600 "$CANDIDATE" || return 1
    install_validated_config "$CANDIDATE" "$CONFIG" "$BACKUP" || { rm -f "$CANDIDATE"; return 1; }
    set_enabled 1 || return 1
    "$INIT" restart || { restore_backup "$CONFIG" "$BACKUP" >/dev/null 2>&1; set_enabled 0 >/dev/null 2>&1 || true; "$INIT" restart >/dev/null 2>&1 || true; return 1; }
}

recovery() { load_core || return 1; restore_backup "$CONFIG" "$BACKUP" || return 1; set_enabled 1 || return 1; "$INIT" restart; }

case "${1:-}" in
    status) status ;; start) start ;; stop) stop ;; restart) restart ;; enable) enable ;; disable) disable ;;
    apply) apply ;; validate) validate ;; health) health ;; recovery) recovery ;;
    *) printf "%s\n" "Usage: singbox-manager {status|start|stop|restart|enable|disable|apply|validate|health|recovery}" >&2; exit 2 ;;
esac
