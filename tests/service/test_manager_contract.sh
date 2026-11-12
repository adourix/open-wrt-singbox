#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MANAGER="$ROOT/core/service/manager.sh"
MIRROR="$ROOT/openwrt/cowboy-bebop-manager/files/usr/lib/cowboy-bebop/service/manager.sh"
PACKAGE="$ROOT/openwrt/cowboy-bebop-manager/Makefile"

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
    grep -F 'connectivity verification warning' "$file" >/dev/null
    grep -F 'ensure_backup()' "$file" >/dev/null
    grep -F 'promote_current_backup()' "$file" >/dev/null
    grep -F 'Current configuration failed runtime verification; rolling back' "$file" >/dev/null
    grep -F 'Configuration confirmed' "$file" >/dev/null
    grep -F 'ROLLBACK_TIMER_CHILD=1 rollback_pending' "$file" >/dev/null
    grep -F 'ROLLBACK_TIMER_CHILD' "$file" >/dev/null
done

grep -F 'DEPENDS:=+sing-box-tiny +jq +nftables +uclient-fetch +kmod-tun +kmod-nfnetlink-queue +kmod-nft-queue +kmod-inet-diag' "$PACKAGE" >/dev/null
if grep -F 'EXTRA_DEPENDS:=' "$PACKAGE" >/dev/null; then
    exit 1
fi

grep -F 'PKG_RELEASE:=23' "$PACKAGE" >/dev/null
grep -F './files/usr/lib/cowboy-bebop/config/generator.sh' "$PACKAGE" >/dev/null

# CLI contract (PROJECT.md 26, 46, 65.2, 65.7).
grep -F "MANAGER_RELEASE=$(sed -n 's/^PKG_RELEASE:=//p' "$PACKAGE")" "$MANAGER" >/dev/null
for cmd in status start stop restart enable disable apply validate health recovery confirm version; do
    grep -E "(^|[ ;])$cmd\\) " "$MANAGER" >/dev/null || { echo "missing command $cmd" >&2; exit 1; }
done
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT
printf '#!/bin/sh\nexit 1\n' > "$TMPD/uci"; chmod +x "$TMPD/uci"
# Machine-readable output is valid JSON and never branded, piped output is plain.
PATH="$TMPD:$PATH" CONFIG_DIR="$TMPD/cfg" sh "$MANAGER" status --json |
    jq -e '.state=="STOPPED" and (.config_valid|type)=="boolean" and (.tun|type)=="boolean" and (.pending|type)=="boolean"' >/dev/null
[ "$(PATH="$TMPD:$PATH" CONFIG_DIR="$TMPD/cfg" sh "$MANAGER" status | head -n 1)" = "State: STOPPED" ]
[ "$(PATH="$TMPD:$PATH" sh "$MANAGER" version --plain | head -n 1)" = "cowboy-bebop-manager: r$(sed -n 's/^PKG_RELEASE:=//p' "$PACKAGE")" ]

printf '%s\n' 'manager lifecycle contract tests: PASS'
