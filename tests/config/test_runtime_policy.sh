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
    "$ROOT/core/network/firewall.sh" \
    "$ROOT/openwrt/cowboy-bebop-manager/files/usr/lib/cowboy-bebop/config/generator.sh" \
    "$ROOT/openwrt/cowboy-bebop-manager/files/etc/init.d/singbox"; do
    sh -n "$file"
done
sh -n "$ROOT/openwrt/luci-app-cowboy-bebop/root/usr/libexec/rpcd/luci.cowboy_bebop"

grep -F 'uclient-fetch' "$ROOT/core/service/manager.sh" >/dev/null
grep -F 'VLESS_ALLOW_INSECURE' "$ROOT/core/service/manager.sh" >/dev/null
grep -F 'PENDING_STATE' "$ROOT/core/service/manager.sh" >/dev/null
grep -F 'restore_previous_uci' "$ROOT/core/service/manager.sh" >/dev/null
! grep -F 'wget ' "$ROOT/core/service/manager.sh" >/dev/null

grep -F 'auto_redirect:true' "$ROOT/core/config/generator.sh" >/dev/null
grep -F 'ip_is_private:true' "$ROOT/core/config/generator.sh" >/dev/null
grep -F 'hijack-dns' "$ROOT/core/config/generator.sh" >/dev/null
grep -F 'domain_resolver' "$ROOT/core/config/generator.sh" >/dev/null

if grep -R -nE 'echo .*proxy_url|printf .*proxy_url|logger .*proxy_url|echo .*uuid|logger .*uuid' "$ROOT/core" >/dev/null 2>&1; then
    echo "possible secret logging found" >&2
    exit 1
fi

cmp -s "$ROOT/core/config/generator.sh" "$ROOT/openwrt/cowboy-bebop-manager/files/usr/lib/cowboy-bebop/config/generator.sh"

printf '%s\n' "runtime policy tests: PASS"
