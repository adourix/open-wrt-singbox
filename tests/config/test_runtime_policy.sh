#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

for file in     "$ROOT/core/protocol/detector.sh"     "$ROOT/core/protocol/vmess/parser.sh"     "$ROOT/core/protocol/vless/parser.sh"     "$ROOT/core/config/generator.sh"     "$ROOT/core/config/validator.sh"     "$ROOT/core/service/manager.sh"     "$ROOT/core/network/firewall.sh"; do
    sh -n "$file"
done

grep -R -nE 'echo .*proxy_url|printf .*proxy_url|logger .*proxy_url|echo .*uuid|logger .*uuid'     "$ROOT/core" >/dev/null 2>&1 && {
    echo "possible secret logging found" >&2
    exit 1
} || true

echo "runtime policy tests: PASS"

# Source-of-truth mirror check
pairs="\ncore/protocol/detector.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/detector.sh\ncore/protocol/vmess/parser.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/vmess/parser.sh\ncore/protocol/vless/parser.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/vless/parser.sh\ncore/config/generator.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/generator.sh\ncore/config/validator.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/validator.sh\ncore/config/version.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/version.sh\ncore/network/firewall.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/network/firewall.sh\ncore/service/manager.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/service/manager.sh\n"
printf '%s\n' "$pairs" | while IFS='|' read -r core packaged; do [ "$core" ] || continue; cmp -s "$ROOT/$core" "$ROOT/$packaged" || { echo "source-of-truth mismatch: $core != $packaged" >&2; exit 1; }; done
