#!/bin/sh
# opkg packages built without the SDK (openwrt/ipk/build-ipk.sh).
# With OPKG_BIN set to a real opkg binary, also installs them end to end,
# including the case of a firmware whose kmods are missing from the feed.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

sh "$ROOT/openwrt/ipk/build-ipk.sh" "$TMP/out" >/dev/null
for p in cowboy-bebop-manager luci-app-cowboy-bebop cowboy-bebop-branding; do
    rel=$(sed -n 's/^PKG_RELEASE:=//p' "$ROOT/openwrt/$p/Makefile")
    ipk="$TMP/out/${p}_1-r${rel}_all.ipk"
    [ -f "$ipk" ] || fail "missing $ipk"
    [ "$(tar -tzf "$ipk" | tr '\n' ' ')" = "./debian-binary ./data.tar.gz ./control.tar.gz " ] || fail "$p ipk layout"
    ctl=$(tar -xzOf "$ipk" ./control.tar.gz | tar -xzOf - ./control)
    printf '%s\n' "$ctl" | grep -qx "Package: $p" || fail "$p name"
    printf '%s\n' "$ctl" | grep -qx "Version: 1-r$rel" || fail "$p version"
    printf '%s\n' "$ctl" | grep -qx 'Architecture: all' || fail "$p arch"
    # opkg would refuse kmods/sing-box on mismatched firmware: never hard deps.
    ! printf '%s\n' "$ctl" | grep -E '^Depends:.*(kmod-|sing-box)' >/dev/null || fail "$p hard-depends on kmod/sing-box"
    tar -xzOf "$ipk" ./control.tar.gz | tar -tzf - | grep -qx './postinst' || fail "$p postinst"
done
m="$TMP/out/cowboy-bebop-manager_1-r$(sed -n 's/^PKG_RELEASE:=//p' "$ROOT/openwrt/cowboy-bebop-manager/Makefile")_all.ipk"
tar -xzOf "$m" ./control.tar.gz | tar -xzOf - ./conffiles | grep -qx '/etc/config/cowboy-bebop' || fail "conffiles"
tar -xzOf "$m" ./data.tar.gz | tar -tvzf - | grep -E '^-rw------- .* \./etc/config/cowboy-bebop$' >/dev/null || fail "uci config must be 0600"
tar -xzOf "$m" ./data.tar.gz | tar -tzf - | grep -qx './usr/lib/cowboy-bebop/config/templates/1.12.json' || fail "1.12 template"
tar -xzOf "$m" ./control.tar.gz | tar -xzOf - ./control | grep -qx 'Depends: jq, nftables, uclient-fetch' || fail "manager depends"

[ -n "${OPKG_BIN:-}" ] || { echo "ipk build tests: PASS (no OPKG_BIN, install test skipped)"; exit 0; }

# ---- end to end with real opkg -------------------------------------------
O="$TMP/root"; F="$TMP/feed"
mkdir -p "$O/usr/lib/opkg/info" "$O/etc/opkg" "$O/var/lock" "$O/var/opkg-lists" "$F" "$TMP/bin"
cat > "$O/etc/opkg.conf" <<CONF
dest root /
lists_dir ext /var/opkg-lists
arch all 1
arch noarch 1
arch arm_cortex-a7_neon-vfpv4 10
src/gz openwrt_packages file://$F
CONF
printf 'src/gz openwrt_core https://example.invalid/targets/x/packages\n' > "$O/etc/opkg/distfeeds.conf"
: > "$O/etc/opkg/customfeeds.conf"
for p in libc jq nftables uclient-fetch luci-base rpcd ca-bundle; do
    printf 'Package: %s\nVersion: 1\nStatus: install user installed\nArchitecture: all\nInstalled-Time: 1\n\n' "$p" >> "$O/usr/lib/opkg/status"
    : > "$O/usr/lib/opkg/info/$p.list"
done
# sing-box-tiny declared exactly like the OpenWrt 24.10 feed (kmods unresolvable here).
S="$TMP/sb"; mkdir -p "$S/control" "$S/data/usr/bin"
printf '#!/bin/sh\necho "sing-box version 1.12.22"\n' > "$S/data/usr/bin/sing-box"; chmod 755 "$S/data/usr/bin/sing-box"
printf 'Package: sing-box-tiny\nVersion: 1.12.22-r1\nDepends: libc, ca-bundle, kmod-inet-diag, kmod-tun\nProvides: sing-box\nConflicts: sing-box\nArchitecture: arm_cortex-a7_neon-vfpv4\nDescription: test\n' > "$S/control/control"
printf '2.0\n' > "$S/debian-binary"
(cd "$S/control" && tar -czf ../control.tar.gz ./); (cd "$S/data" && tar -czf ../data.tar.gz ./)
f=sing-box-tiny_1.12.22-r1_arm_cortex-a7_neon-vfpv4.ipk
(cd "$S" && tar -czf "$F/$f" ./debian-binary ./data.tar.gz ./control.tar.gz)
{ grep -v '^Description' "$S/control/control"; printf 'Filename: %s\nSize: %s\nDescription: test\n\n' "$f" "$(wc -c < "$F/$f" | tr -d ' ')"; } > "$F/Packages"
gzip -k "$F/Packages"
printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/wget"; chmod +x "$TMP/bin/wget"

B="$TMP/bundle"; mkdir -p "$B/ipk"; cp "$TMP/out"/*.ipk "$B/ipk/"; cp "$ROOT/openwrt/ipk/install-opkg.sh" "$B/install.sh"
OPKG="$OPKG_BIN -o $O -f $O/etc/opkg.conf"
PATH="$TMP/bin:$PATH" INSTALL_ROOT="$O" OPKG="$OPKG" sh "$B/install.sh" >"$TMP/log" 2>&1 || { cat "$TMP/log" >&2; fail "installer"; }
for p in sing-box-tiny cowboy-bebop-compat-kmods cowboy-bebop-manager luci-app-cowboy-bebop cowboy-bebop-branding; do
    $OPKG list-installed 2>/dev/null | grep -q "^$p " || fail "$p not installed"
done
[ -x "$O/usr/bin/cowboy-bebop-manager" ] || fail "manager binary"
[ -f "$O/www/luci-static/resources/view/cowboy-bebop/overview.js" ] || fail "LuCI view"
# Second run is a clean no-op upgrade.
PATH="$TMP/bin:$PATH" INSTALL_ROOT="$O" OPKG="$OPKG" sh "$B/install.sh" >"$TMP/log" 2>&1 || { cat "$TMP/log" >&2; fail "second run"; }
echo "ipk build tests: PASS (with real opkg install)"
