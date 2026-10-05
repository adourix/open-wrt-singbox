#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MANAGER="$ROOT/core/service/manager.sh"
MIRROR="$ROOT/openwrt/singbox-manager/files/usr/lib/singbox-manager/service/manager.sh"
PACKAGE="$ROOT/openwrt/singbox-manager/Makefile"

# Core and packaged manager must remain byte-for-byte identical.
cmp -s "$MANAGER" "$MIRROR"

# Start/restart must validate configuration and verify the real runtime.
grep -F 'config_valid ||' "$MANAGER" >/dev/null
grep -F 'if ! verify_runtime' "$MANAGER" >/dev/null
grep -F 'process_running()' "$MANAGER" >/dev/null
grep -F 'tun_exists()' "$MANAGER" >/dev/null
grep -F 'routing_exists()' "$MANAGER" >/dev/null

# A pending commit-confirm state must block Start/Restart and duplicate Apply.
grep -F 'Configuration confirmation is pending' "$MANAGER" >/dev/null
grep -F 'Another apply is awaiting confirmation' "$MANAGER" >/dev/null

# Apply must persist the new desired state only after a validated candidate and
# must save the complete previous desired state for rollback/reboot recovery.
grep -F 'install_validated_config' "$MANAGER" >/dev/null
grep -F 'write_pending_state' "$MANAGER" >/dev/null
grep -F 'persist_desired_state "$url" "$allow_insecure" "$auto_start" 1' "$MANAGER" >/dev/null

# Failed first-time activation must be able to remove a config when no backup exists.
grep -F 'restore_current_config()' "$MANAGER" >/dev/null
grep -F 'rm -f "$CONFIG" "$CANDIDATE"' "$MANAGER" >/dev/null

# Stop/recovery during a pending apply must restore the old config and UCI state,
# never leave the unconfirmed candidate active.
grep -F 'restore_previous_uci' "$MANAGER" >/dev/null
grep -F 'rollback_pending' "$MANAGER" >/dev/null
grep -F 'Unable to safely roll back pending configuration' "$MANAGER" >/dev/null

# Runtime verification must provide a useful failure reason and retry transient connectivity.
grep -F 'runtime_failure()' "$MANAGER" >/dev/null
grep -F 'connectivity test failed' "$MANAGER" >/dev/null
grep -F 'tries=0' "$MANAGER" >/dev/null

# Confirm must never report success when verification fails.
grep -F 'Current configuration failed runtime verification; rolling back' "$MANAGER" >/dev/null
grep -F 'Configuration confirmed' "$MANAGER" >/dev/null

# The rollback worker must not kill itself when it clears its PID file.
grep -F 'ROLLBACK_TIMER_CHILD=1 rollback_pending' "$MANAGER" >/dev/null
grep -F 'ROLLBACK_TIMER_CHILD' "$MANAGER" >/dev/null

# The manager is intentionally a standalone runtime package in the SDK: its
# dependencies must remain install-time metadata, not SDK build dependencies.
grep -F 'EXTRA_DEPENDS:=sing-box (>= 0) jq (>= 0) nftables (>= 0) uclient-fetch (>= 0) kmod-tun (>= 0) kmod-nfnetlink-queue (>= 0) kmod-nft-queue (>= 0) kmod-inet-diag (>= 0)' "$PACKAGE" >/dev/null
if grep -F 'DEPENDS:=+sing-box' "$PACKAGE" >/dev/null; then
    exit 1
fi

printf '%s\n' 'manager lifecycle contract tests: PASS'
