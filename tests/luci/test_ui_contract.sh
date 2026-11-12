#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
UI="$ROOT/openwrt/luci-app-cowboy-bebop/htdocs/luci-static/resources/view/cowboy-bebop/overview.js"
RPC="$ROOT/openwrt/luci-app-cowboy-bebop/root/usr/libexec/rpcd/luci.cowboy_bebop"
MAKEFILE="$ROOT/openwrt/luci-app-cowboy-bebop/Makefile"

grep -F "method: 'start'" "$UI" >/dev/null
grep -F "method: 'stop'" "$UI" >/dev/null
grep -F 'actionBox.appendChild(preview)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(startButton)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(apply)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(stopButton)' "$UI" >/dev/null
grep -F 'cb-manager-page' "$UI" >/dev/null
grep -F 'cb-config-card' "$UI" >/dev/null

# The primary action surface is Start/Stop/Apply; there is no legacy UI toggle.
! grep -F "method: 'set_enabled'" "$UI" >/dev/null

grep -F 'SINGBOX_AUTO_START=1' "$RPC" >/dev/null
grep -F 'SINGBOX_ALLOW_INSECURE=1' "$RPC" >/dev/null
grep -F 'REDACTED-URL' "$RPC" >/dev/null

grep -F 'usr/share/rpcd/acl.d' "$MAKEFILE" >/dev/null
grep -F 'luci.cowboy_bebop' "$MAKEFILE" >/dev/null
grep -F '"start", "stop"' "$MAKEFILE" >/dev/null

grep -F 'luci.cowboy_bebop' "$RPC" >/dev/null

# Status wording (PROJECT.md 65.4): literal labels.
for label in 'Tunnel up' 'Tunnel down' 'Checking configuration' 'Confirm within 60 s' 'Reverted to last good config' 'Safe mode'; do
    grep -F "$label" "$UI" >/dev/null || { echo "missing label: $label" >&2; exit 1; }
done
# The page styles itself and needs no custom theme package.
grep -F 'PAGE_CSS' "$UI" >/dev/null
grep -F '"title": "Cowboy Bebop"' "$MAKEFILE" >/dev/null
grep -F 'admin/services/cowboy-bebop' "$MAKEFILE" >/dev/null
# The saved URL/UUID is never returned to the browser.
! grep -E 'proxy_url:\$|uuid' "$RPC" | grep -vE 'REDACTED|never returns|\.proxy_url \| strings|proxy_url=\$|proxy_url"|main\.proxy_url' >/dev/null

printf '%s\n' 'LuCI UI contract tests: PASS'
