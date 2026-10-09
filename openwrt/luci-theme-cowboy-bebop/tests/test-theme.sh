#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail(){ echo "TEST FAIL: $*" >&2; exit 1; }
pass(){ echo "TEST PASS: $*"; }

[ -f "$ROOT/Makefile" ] || fail "theme Makefile is missing"
for asset in \
	"htdocs/luci-static/cowboy-bebop/cascade.css" \
	"htdocs/luci-static/cowboy-bebop/reference.css" \
	"htdocs/luci-static/cowboy-bebop/sidebar.css" \
	"htdocs/luci-static/cowboy-bebop/navigation-fix.css" \
	"htdocs/luci-static/cowboy-bebop/actions-fix.css" \
	"htdocs/luci-static/cowboy-bebop/controls-fix.css" \
	"htdocs/luci-static/cowboy-bebop/dashboard-fix.css" \
	"htdocs/luci-static/resources/menu-cowboy-bebop.js" \
	"htdocs/luci-static/resources/dashboard-fix.js"; do
	[ -f "$ROOT/$asset" ] || fail "missing theme asset: $asset"
done

grep -q '^PKG_RELEASE:=16$' "$ROOT/Makefile" || fail "theme release is stale"
grep -q 'Full LuCI visual theme' "$ROOT/Makefile" || fail "theme must be a full LuCI theme"
for asset in reference.css sidebar.css navigation-fix.css actions-fix.css controls-fix.css dashboard-fix.css; do
	grep -q "$asset" "$ROOT/Makefile" || fail "$asset must be packaged"
done
grep -q 'main.mediaurlbase=/luci-static/cowboy-bebop' "$ROOT/Makefile" || fail "theme postinst must activate full LuCI theme"
grep -q 'themes.CowboyBebop=/luci-static/cowboy-bebop' "$ROOT/root/etc/uci-defaults/30_luci-theme-cowboy-bebop" || fail "theme registration missing"

HEADER="$ROOT/ucode/template/themes/cowboy-bebop/header.ut"
for asset in reference.css sidebar.css navigation-fix.css actions-fix.css controls-fix.css dashboard-fix.css; do
	grep -q "$asset" "$HEADER" || fail "$asset must load in theme header"
done

grep -q 'max-width: 854px' "$HEADER" || fail "mobile stylesheet must use viewport width"

grep -q 'cb-nav-chevron.*display: none' "$ROOT/htdocs/luci-static/cowboy-bebop/sidebar.css" || fail "sidebar arrows must be hidden"
grep -q 'cb-nav-group-heading::after.*display:none' "$ROOT/htdocs/luci-static/cowboy-bebop/sidebar.css" || fail "sidebar pseudo arrows must be hidden"

MENU="$ROOT/htdocs/luci-static/resources/menu-cowboy-bebop.js"
grep -q 'cb-nav-section-heading' "$MENU" || fail "collapsible section heading missing"
grep -q 'closeSiblingGroups' "$MENU" || fail "sidebar accordion behavior missing"
grep -q 'bindMobileSidebar' "$MENU" || fail "mobile sidebar behavior missing"

grep -q 'input\[type="checkbox"\]' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "checkbox normalization missing"
grep -q 'input\[type="radio"\]' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "radio normalization missing"
grep -q 'cbi-dropdown > ul {' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "collapsed dropdown shell missing"
grep -q 'cbi-dropdown > ul.dropdown {' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "dropdown popup shell missing"
grep -q 'display: none !important;' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "dropdown popup must be hidden by default"
grep -q 'cbi-dropdown\[open\] > ul.dropdown' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "dropdown popup open state missing"
grep -q 'cbi-dropdown > ul.dropdown > li > form' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "dropdown checkbox row layout missing"
grep -q 'cbi-dropdown > ul.dropdown .ifacebadge' "$ROOT/htdocs/luci-static/cowboy-bebop/controls-fix.css" || fail "interface badge normalization missing"
grep -q 'cbi-page-actions .cbi-dropdown.cbi-button' "$ROOT/htdocs/luci-static/cowboy-bebop/actions-fix.css" || fail "Save & Apply ComboButton normalization missing"

echo "THEME STATIC CHECKS PASSED"
