#!/bin/sh
# Package layout must match PROJECT.md section 61 and mirror core/ exactly.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PKG="$ROOT/openwrt/cowboy-bebop-manager"
LIB="$PKG/files/usr/lib/cowboy-bebop"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

for f in protocol/detector.sh protocol/vmess/parser.sh protocol/vless/parser.sh \
         config/generator.sh config/validator.sh config/version.sh \
         config/templates/1.13.21.json config/templates/1.12.json network/firewall.sh service/manager.sh; do
    [ -f "$LIB/$f" ] || fail "missing packaged $f"
    cmp -s "$ROOT/core/$f" "$LIB/$f" || fail "packaged $f differs from core/$f"
    grep -qF "./files/usr/lib/cowboy-bebop/$f \$(1)/usr/lib/cowboy-bebop/$f" "$PKG/Makefile" || fail "Makefile does not install $f"
done
[ -f "$PKG/files/etc/init.d/cowboy-bebop" ] || fail "init script"
[ -f "$PKG/files/etc/config/cowboy-bebop" ] || fail "uci config"
[ -f "$PKG/files/usr/bin/cowboy-bebop-manager" ] || fail "manager wrapper"
[ "$(find "$LIB/config/templates" -name '*.json' | wc -l)" -eq 2 ] || fail "exactly the 1.13.21 and 1.12 series templates ship"

# No old project-owned names anywhere in the packaged sources.
if grep -rnE 'singbox-manager|/etc/singbox|init\.d/singbox|/usr/lib/singbox' "$ROOT/openwrt" "$ROOT/core" >/dev/null; then
    fail "old project-owned names remain"
fi

# Exactly three project packages; the private theme is gone.
[ ! -d "$ROOT/openwrt/luci-theme-cowboy-bebop" ] || fail "private theme package still present"
for p in cowboy-bebop-manager luci-app-cowboy-bebop cowboy-bebop-branding; do
    [ -f "$ROOT/openwrt/$p/Makefile" ] || fail "missing package $p"
    # GNU make only accepts 'endef'.
    ! grep -qE '^endefine' "$ROOT/openwrt/$p/Makefile" || fail "$p Makefile uses endefine"
    [ "$(grep -c '^define ' "$ROOT/openwrt/$p/Makefile")" -eq "$(grep -c '^endef$' "$ROOT/openwrt/$p/Makefile")" ] || fail "$p define/endef mismatch"
done

# No reseller identity in anything the project ships.
if grep -rniE 'bass?em[^a-z]|bass?emlg' "$ROOT/openwrt" "$ROOT/core" |
    grep -v 'cowboy-bebop-identity' >/dev/null; then
    fail "reseller identity found in shipped files"
fi

printf '%s\n' 'package layout tests: PASS'
