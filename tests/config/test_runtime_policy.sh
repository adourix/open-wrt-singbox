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

grep -R -nE 'echo .*proxy_url|printf .*proxy_url|logger .*proxy_url|echo .*uuid|logger .*uuid' \
    "$ROOT/core" >/dev/null 2>&1 && {
    echo "possible secret logging found" >&2
    exit 1
} || true

# The nft comment must be quoted so the colon is part of the comment token.
grep -F 'comment "singbox: block IPv6 bypass"' "$ROOT/core/network/firewall.sh" >/dev/null || {
    echo "IPv6 nft comment is not quoted" >&2
    exit 1
}

# The runtime HTTPS probe must use OpenWrt's tiny TLS-capable uclient-fetch.
grep -F 'uclient-fetch -q -T 8 -O /dev/null https://api.ipify.org' "$ROOT/core/service/manager.sh" >/dev/null || {
    echo "runtime connectivity probe is not using uclient-fetch" >&2
    exit 1
}

grep -F '+uclient-fetch' "$ROOT/openwrt/singbox-manager/Makefile" >/dev/null || {
    echo "uclient-fetch runtime dependency is missing" >&2
    exit 1
}

# Save & Apply must carry the current UI values instead of applying stale UCI state.
grep -F "method: 'apply'" "$ROOT/openwrt/luci-app-singbox/htdocs/luci-static/resources/view/singbox/overview.js" >/dev/null || {
    echo "LuCI apply RPC is missing" >&2
    exit 1
}
grep -F 'handleSaveApply: null' "$ROOT/openwrt/luci-app-singbox/htdocs/luci-static/resources/view/singbox/overview.js" >/dev/null || {
    echo "default LuCI footer is not disabled" >&2
    exit 1
}

# Source-of-truth mirror check
pairs="
core/protocol/detector.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/detector.sh
core/protocol/vmess/parser.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/vmess/parser.sh
core/protocol/vless/parser.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/protocol/vless/parser.sh
core/config/generator.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/generator.sh
core/config/validator.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/validator.sh
core/config/version.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/config/version.sh
core/network/firewall.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/network/firewall.sh
core/service/manager.sh|openwrt/singbox-manager/files/usr/lib/singbox-manager/service/manager.sh
"
printf '%s\n' "$pairs" | while IFS='|' read -r core packaged; do
    [ "$core" ] || continue
    cmp -s "$ROOT/$core" "$ROOT/$packaged" || {
        echo "source-of-truth mismatch: $core != $packaged" >&2
        exit 1
    }
done

printf '%s\n' "runtime policy tests: PASS"
