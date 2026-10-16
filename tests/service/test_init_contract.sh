#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
INIT="$ROOT/openwrt/cowboy-bebop-manager/files/etc/init.d/singbox"

grep -F 'pending configuration has no valid backup; disabling Cowboy Bebop safely' "$INIT" >/dev/null
grep -F 'rm -f "$CONFIG" "$CANDIDATE"' "$INIT" >/dev/null
grep -F 'uci set cowboy-bebop.main.enabled=0' "$INIT" >/dev/null
grep -F 'uci set cowboy-bebop.main.auto_start=0' "$INIT" >/dev/null

grep -F '"$PROG" check -c "$BACKUP"' "$INIT" >/dev/null
grep -F 'old_enabled=$(jq -er' "$INIT" >/dev/null
grep -F 'old_auto_start=$(jq -er' "$INIT" >/dev/null
grep -F 'uci set cowboy-bebop.main.allow_insecure="$old_allow_insecure"' "$INIT" >/dev/null

grep -F "log_error 'sing-box configuration check failed'" "$INIT" >/dev/null
grep -F "log_error 'Cowboy Bebop firewall setup failed'" "$INIT" >/dev/null
grep -F '"$FIREWALL" cleanup' "$INIT" >/dev/null
grep -F 'firewall cleanup failed' "$INIT" >/dev/null
grep -F 'procd_set_param respawn' "$INIT" >/dev/null
grep -F 'procd_set_param command "$PROG" run -c "$CONFIG"' "$INIT" >/dev/null

printf '%s\n' 'init recovery contract tests: PASS'
