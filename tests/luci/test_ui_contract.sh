#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
UI="$ROOT/openwrt/luci-app-cowboy-bebop/htdocs/luci-static/resources/view/cowboy-bebop/overview.js"
RPC="$ROOT/openwrt/luci-app-cowboy-bebop/root/usr/libexec/rpcd/luci.cowboy_bebop"
MAKEFILE="$ROOT/openwrt/luci-app-cowboy-bebop/Makefile"

grep -F "method: 'start'" "$UI" >/dev/null
grep -F "method: 'stop'" "$UI" >/dev/null
! grep -F "method: 'set_enabled'" "$UI" >/dev/null

! grep -F 'actionBox.innerHTML' "$UI" >/dev/null
grep -F 'confirmBox.innerHTML' "$UI" >/dev/null
grep -F 'actionBox.appendChild(preview)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(startButton)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(apply)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(stopButton)' "$UI" >/dev/null

grep -F 'cbi-page-actions' "$UI" >/dev/null
grep -F 'cb-manager-page' "$UI" >/dev/null
grep -F 'cb-config-card' "$UI" >/dev/null

! grep -F 'Allow insecure TLS' "$UI" >/dev/null
! grep -F 'Auto Start' "$UI" >/dev/null
! grep -F 'allowInsecure' "$UI" >/dev/null
! grep -F 'var auto =' "$UI" >/dev/null

grep -F '"start"' "$RPC" >/dev/null
grep -F '"stop"' "$RPC" >/dev/null
grep -F 'SINGBOX_AUTO_START=1' "$RPC" >/dev/null
grep -F 'SINGBOX_ALLOW_INSECURE=1' "$RPC" >/dev/null
grep -F 'REDACTED-URL' "$RPC" >/dev/null

grep -F 'usr/share/rpcd/acl.d' "$MAKEFILE" >/dev/null
grep -F 'luci.cowboy_bebop' "$MAKEFILE" >/dev/null
grep -F '"start", "stop"' "$MAKEFILE" >/dev/null

grep -F 'luci.cowboy_bebop' "$RPC" >/dev/null

printf '%s\n' 'LuCI UI contract tests: PASS'
