#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail(){ echo "TEST FAIL: $*" >&2; exit 1; }
pass(){ echo "TEST PASS: $*"; }
[ -f "$ROOT/Makefile" ] || fail "theme Makefile is missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/cascade.css" ] || fail "base theme assets missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/reference.css" ] || fail "reference UI layer missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/sidebar.css" ] || fail "sidebar polish stylesheet missing"
[ -f "$ROOT/htdocs/luci-static/resources/menu-cowboy-bebop.js" ] || fail "menu asset missing"
grep -q '^PKG_RELEASE:=12$' "$ROOT/Makefile" || fail "expected theme release 12"
grep -q 'Full LuCI visual theme' "$ROOT/Makefile" || fail "theme must be a full LuCI theme"
grep -q 'reference.css' "$ROOT/Makefile" || fail "reference CSS must be packaged"
grep -q 'sidebar.css' "$ROOT/Makefile" || fail "sidebar CSS must be packaged"
grep -q 'main.mediaurlbase=/luci-static/cowboy-bebop' "$ROOT/Makefile" || fail "theme postinst must activate full LuCI theme"
grep -q 'themes.CowboyBebop=/luci-static/cowboy-bebop' "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" || fail "theme registration missing"
HEADER="$ROOT/ucode/template/themes/cowboy-bebop/header.ut"
grep -q 'reference.css' "$HEADER" || fail "reference CSS must load in theme header"
grep -q 'sidebar.css' "$HEADER" || fail "sidebar CSS must load in theme header"
MENU="$ROOT/htdocs/luci-static/resources/menu-cowboy-bebop.js"
grep -q 'cb-nav-section-heading' "$MENU" || fail "collapsible section heading missing"
grep -q 'closeSiblingGroups' "$MENU" || fail "sidebar accordion behavior missing"
JS="$ROOT/../luci-app-cowboy-bebop/htdocs/luci-static/resources/view/cowboy-bebop/overview.js"
[ -f "$JS" ] || fail "manager overview missing"
for feature in "Connection profile" "Save & Apply" "ON / Start" "OFF / Stop" "Recent logs" "Run recovery" "Confirm configuration"; do grep -q "$feature" "$JS" || fail "missing UI feature: $feature"; done
CSS="$ROOT/../luci-app-cowboy-bebop/htdocs/luci-static/resources/view/cowboy-bebop/overview.css"
[ -f "$CSS" ] || fail "manager-scoped CSS missing"
grep -q 'cb-manager-page' "$CSS" || fail "styles are not scoped to manager page"
echo "ALL PHASE C TESTS PASSED"
