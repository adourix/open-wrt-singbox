#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail(){ echo "TEST FAIL: $*" >&2; exit 1; }
pass(){ echo "TEST PASS: $*"; }
[ -f "$ROOT/Makefile" ] || fail "theme Makefile is missing"
[ -f "$ROOT/htdocs/luci-static/cowboy-bebop/cascade.css" ] || fail "legacy theme assets missing"
[ -f "$ROOT/htdocs/luci-static/resources/menu-cowboy-bebop.js" ] || fail "legacy menu asset missing"
grep -q '^PKG_RELEASE:=10$' "$ROOT/Makefile" || fail "expected theme release 10"
grep -q 'does not activate itself' "$ROOT/Makefile" || fail "theme must remain optional"
! grep -q 'main.mediaurlbase /luci-static/cowboy-bebop' "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" || fail "default LuCI theme must not be replaced"
grep -q 'themes.CowboyBebop=/luci-static/cowboy-bebop' "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" || fail "optional theme registration missing"
JS="$ROOT/../luci-app-cowboy-bebop/htdocs/luci-static/resources/view/cowboy-bebop/overview.js"
[ -f "$JS" ] || fail "manager overview missing"
for feature in "Connection profile" "Save & Apply" "ON / Start" "OFF / Stop" "Logs & diagnostics" "Run recovery" "Confirm configuration"; do grep -q "$feature" "$JS" || fail "missing UI feature: $feature"; done
CSS="$ROOT/../luci-app-cowboy-bebop/htdocs/luci-static/resources/view/cowboy-bebop/overview.css"
[ -f "$CSS" ] || fail "manager-scoped CSS missing"
grep -q 'cb-manager-page' "$CSS" || fail "styles are not scoped to manager page"
echo "ALL PHASE C TESTS PASSED"
