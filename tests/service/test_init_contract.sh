#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
INIT="$ROOT/openwrt/singbox-manager/files/etc/init.d/singbox"

# Boot recovery must never leave an unconfirmed first-time config active when
# there is no valid known-good backup.
grep -F 'pending configuration has no valid backup; disabling sing-box safely' "$INIT" >/dev/null
grep -F 'rm -f "$CONFIG" /etc/singbox/config.json.new' "$INIT" >/dev/null
grep -F 'uci set singbox.main.enabled=0' "$INIT" >/dev/null
grep -F 'uci set singbox.main.auto_start=1' "$INIT" >/dev/null
grep -F 'uci set singbox.main.allow_insecure=1' "$INIT" >/dev/null

# With a valid backup, the previous desired state must be restored while the
# fixed autostart/TLS policy remains enabled.
grep -F '"$PROG" check -c "$BACKUP"' "$INIT" >/dev/null
grep -F 'old_enabled=$(jq -er' "$INIT" >/dev/null
grep -F 'old_auto_start=$(jq -er' "$INIT" >/dev/null
grep -F 'uci set singbox.main.auto_start=1' "$INIT" >/dev/null

# Startup failures must be diagnosable through logd and firewall setup must be
# cleaned up when it fails before procd starts sing-box.
grep -F "log_error 'sing-box configuration check failed'" "$INIT" >/dev/null
grep -F "log_error 'sing-box firewall setup failed'" "$INIT" >/dev/null
grep -F '"$FIREWALL" cleanup' "$INIT" >/dev/null

# Normal stop must remove project-owned firewall state.
grep -F 'firewall cleanup failed' "$INIT" >/dev/null

printf '%s\n' 'init recovery contract tests: PASS'
