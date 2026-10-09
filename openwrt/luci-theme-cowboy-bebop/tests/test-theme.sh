#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "TEST FAIL: $*" >&2; exit 1; }
pass() { echo "TEST PASS: $*"; }

[ -f "$ROOT/Makefile" ] || fail "theme Makefile is missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/cascade.css" ] || fail "cascade.css is missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/mobile.css" ] || fail "mobile.css is missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/logo.svg" ] || fail "logo.svg is missing"
[ -f "$ROOT/htdocs/luci-static/resources/menu-cowboy-bebop.js" ] || fail "menu JS is missing"
[ -f "$ROOT/ucode/template/themes/cowboy-bebop/header.ut" ] || fail "header template is missing"
[ -f "$ROOT/ucode/template/themes/cowboy-bebop/footer.ut" ] || fail "footer template is missing"
[ -f "$ROOT/ucode/template/themes/cowboy-bebop/sysauth.ut" ] || fail "login template is missing"
[ -f "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" ] || fail "theme activation script is missing"
pass "all theme files exist"

grep -q '^PKG_RELEASE:=9$' "$ROOT/Makefile" || fail "expected theme release 9"
! grep -q '^  DEPENDS:=' "$ROOT/Makefile" || fail "theme must not force-build LuCI runtime dependencies"
pass "package metadata is correct"

HEADER="$ROOT/ucode/template/themes/cowboy-bebop/header.ut"
FOOTER="$ROOT/ucode/template/themes/cowboy-bebop/footer.ut"
AUTH="$ROOT/ucode/template/themes/cowboy-bebop/sysauth.ut"
CSS="$ROOT/htdocs/luci-static/cowboy-bebop/cascade.css"
MENU="$ROOT/htdocs/luci-static/resources/menu-cowboy-bebop.js"
LOGO="$ROOT/htdocs/luci-static/cowboy-bebop/logo.svg"

! grep -q 'boardinfo\.hostname' "$HEADER" || fail "private shell must not expose the system hostname"
! grep -q 'OpenWrt' "$HEADER" || fail "header must not expose OpenWrt branding"
! grep -q 'OpenWrt' "$FOOTER" || fail "footer must not expose OpenWrt branding"
! grep -q 'OpenWrt' "$AUTH" || fail "login page must not expose OpenWrt branding"
! grep -qi 'online' "$HEADER" || fail "status/online chrome must not be present in header"
! grep -qi 'online' "$FOOTER" || fail "status/online chrome must not be present in footer"
! grep -q 'cb-brand.*<img' "$HEADER" || fail "legacy left logo image must not be present"
grep -q 'COWBOY BEBOP' "$HEADER" || fail "Cowboy Bebop header branding missing"
grep -q 'COWBOY BEBOP MANAGER' "$AUTH" || fail "Cowboy Bebop login branding missing"
grep -q 'aria-label="Cowboy Bebop"' "$LOGO" || fail "Cowboy Bebop logo asset is missing"
! grep -q 'M24 25h48v10H35' "$LOGO" || fail "old E logo is still present"
for number in '+20175555667' '+20 1009823007'; do
  grep -q "$number" "$HEADER" || fail "support number missing from header: $number"
  grep -q "$number" "$FOOTER" || fail "support number missing from footer: $number"
  grep -q "$number" "$AUTH" || fail "support number missing from login: $number"
done
pass "private branding, logo and support numbers are preserved"

grep -q -- '--cb-bg:#f2f4f7' "$CSS" || fail "workspace palette missing"
grep -q -- '--cb-surface:#fff' "$CSS" || fail "surface palette missing"
grep -q -- '--cb-sidebar:#0d1420' "$CSS" || fail "graphite navigation palette missing"
grep -q -- '--cb-primary:#2563eb' "$CSS" || fail "blue primary palette missing"
grep -q -- '--cb-accent:#e0a354' "$CSS" || fail "accent palette missing"
grep -q 'cb-empty-value' "$CSS" || fail "empty-value presentation rule missing"
pass "cohesive network UI palette and empty-data handling are present"

grep -q "ui\.menu\.load()" "$MENU" || fail "native LuCI menu loader missing"
grep -q "ui\.menu\.getChildren(child)" "$MENU" || fail "menu recursion is missing"
grep -q "this\.renderLevel(child, submenu" "$MENU" || fail "nested native menu rendering is missing"
grep -q "cb-nav-group-heading" "$MENU" || fail "permanently expanded navigation headings are missing"
grep -q "L\.url(url, child\.name)" "$MENU" || fail "native LuCI URL generation is missing"
grep -q "renderTabs" "$MENU" || fail "native tab rendering is missing"
grep -q "enhanceContent" "$MENU" || fail "content presentation enhancer is missing"
grep -q "cb-empty-value" "$MENU" || fail "empty native values are not filtered"
! grep -q "cb-nav-chevron" "$MENU" || fail "dropdown chevrons must not be present"
! grep -q "cb-nav-group-toggle" "$MENU" || fail "dropdown group toggles must not be present"
grep -q "Menu unavailable" "$MENU" || fail "menu failure fallback is missing"
pass "native LuCI navigation and tabs are preserved and permanently expanded"

grep -q 'themes\.CowboyBebop /luci-static/cowboy-bebop' "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" || fail "theme registration missing"
grep -q 'main\.mediaurlbase /luci-static/cowboy-bebop' "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" || fail "theme activation missing"
pass "theme activation is configured"

sh -n "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop"
if command -v node >/dev/null 2>&1; then
  node --check "$MENU"
  pass "menu JavaScript syntax check"
else
  echo "TEST SKIP: node is not installed; JavaScript syntax check skipped"
fi

echo "ALL THEME TESTS PASSED"
