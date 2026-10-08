#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MANAGER="$ROOT/core/service/manager.sh"
MIRROR="$ROOT/openwrt/cowboy-bebop-manager/files/usr/lib/singbox-manager/service/manager.sh"
PACKAGE="$ROOT/openwrt/cowboy-bebop-manager/Makefile"

# Core and packaged managers must preserve the same critical runtime contract.
for file in "$MANAGER" "$MIRROR"; do
    grep -F 'config_valid ||' "$file" >/dev/null
    grep -F 'if ! verify_runtime' "$file" >/dev/null
    grep -F 'process_running()' "$file" >/dev/null
    grep -F 'tun_exists()' "$file" >/dev/null
    grep -F 'routing_exists()' "$file" >/dev/null
    grep -F 'ip link show tun0' "$file" >/dev/null
    grep -F 'dev tun0' "$file" >/dev/null
    grep -F 'Configuration confirmation is pending' "$file" >/dev/null
    grep -F 'Another apply is awaiting confirmation' "$file" >/dev/null
    grep -F 'install_validated_config' "$file" >/dev/null
    grep -F 'write_pending_state' "$file" >/dev/null
    grep -F 'restore_current_config()' "$file" >/dev/null
    grep -F 'rm -f "$CONFIG" "$CANDIDATE"' "$file" >/dev/null
    grep -F 'restore_previous_uci' "$file" >/dev/null
    grep -F 'rollback_pending' "$file" >/dev/null
    grep -F 'Unable to safely roll back pending configuration' "$file" >/dev/null
    grep -F 'runtime_failure()' "$file" >/dev/null
    grep -F 'connectivity test failed' "$file" >/dev/null
    grep -F 'Current configuration failed runtime verification; rolling back' "$file" >/dev/null
    grep -F 'Configuration confirmed' "$file" >/dev/null
    grep -F 'ROLLBACK_TIMER_CHILD=1 rollback_pending' "$file" >/dev/null
    grep -F 'ROLLBACK_TIMER_CHILD' "$file" >/dev/null
done

grep -F 'DEPENDS:=+sing-box-tiny +jq +nftables +uclient-fetch +kmod-tun +kmod-nfnetlink-queue +kmod-nft-queue +kmod-inet-diag' "$PACKAGE" >/dev/null
if grep -F 'EXTRA_DEPENDS:=' "$PACKAGE" >/dev/null; then
    exit 1
fi

printf '%s\n' 'manager lifecycle contract tests: PASS'
