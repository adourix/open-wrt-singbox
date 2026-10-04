#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

for file in \
    "$ROOT/core/protocol/detector.sh" \
    "$ROOT/core/protocol/vmess/parser.sh" \
    "$ROOT/core/protocol/vless/parser.sh" \
    "$ROOT/core/config/generator.sh" \
    "$ROOT/core/config/validator.sh" \
    "$ROOT/core/service/manager.sh" \
    "$ROOT/core/network/firewall.sh"; do
    sh -n "$file"
done
sh -n "$ROOT/openwrt/singbox-manager/files/etc/init.d/singbox"
sh -n "$ROOT/openwrt/luci-app-singbox/root/usr/libexec/rpcd/luci.singbox"

grep -F 'uclient-fetch' "$ROOT/core/service/manager.sh" >/dev/null
grep -F 'VLESS_ALLOW_INSECURE' "$ROOT/core/service/manager.sh" >/dev/null
grep -F 'PENDING_STATE' "$ROOT/core/service/manager.sh" >/dev/null
grep -F 'restore_pending_uci' "$ROOT/core/service/manager.sh" >/dev/null
! grep -F 'wget ' "$ROOT/core/service/manager.sh" >/dev/null

if grep -R -nE 'echo .*proxy_url|printf .*proxy_url|logger .*proxy_url|echo .*uuid|logger .*uuid' "$ROOT/core" >/dev/null 2>&1; then
    echo "possible secret logging found" >&2
    exit 1
fi

for pair in \
    "core/protocol/detector.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/detector.sh" \
    "core/protocol/vmess/parser.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/vmess/parser.sh" \
    "core/protocol/vless/parser.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/vless/parser.sh" \
    "core/config/generator.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/generator.sh" \
    "core/config/validator.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/validator.sh" \
    "core/config/version.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/version.sh" \
    "core/network/firewall.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/network/firewall.sh" \
    "core/service/manager.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/service/manager.sh"; do
    core_file=${pair%%|*}
    packaged_file=${pair#*|}
    cmp -s "$ROOT/$core_file" "$ROOT/$packaged_file" || {
        echo "source-of-truth mismatch: $core_file != $packaged_file" >&2
        exit 1
    }
done

printf '%s\n' "runtime policy tests: PASS"
