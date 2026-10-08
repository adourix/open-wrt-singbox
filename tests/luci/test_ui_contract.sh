#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
UI="$ROOT/openwrt/luci-app-singbox/htdocs/luci-static/resources/view/singbox/overview.js"
RPC="$ROOT/openwrt/luci-app-singbox/root/usr/libexec/rpcd/luci.singbox"
ACL="$ROOT/openwrt/luci-app-singbox/root/usr/share/rpcd/acl.d/luci-app-singbox.json"

# The UI must expose explicit Start/Stop actions and never rely on a toggle.
grep -F "method: 'start'" "$UI" >/dev/null
grep -F "method: 'stop'" "$UI" >/dev/null
! grep -F "method: 'set_enabled'" "$UI" >/dev/null

# Refreshes must not delete the primary action buttons.
! grep -F 'actionBox.innerHTML' "$UI" >/dev/null
grep -F 'confirmBox.innerHTML' "$UI" >/dev/null

# The generic LuCI Save/Reset footer must stay hidden; Cowboy Bebop owns its action bar.
grep -F 'singbox-hide-generic-actions' "$UI" >/dev/null
grep -F '.cbi-page-actions:not(.singbox-primary-actions)' "$UI" >/dev/null

grep -F 'actionBox.appendChild(preview)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(startButton)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(apply)' "$UI" >/dev/null
grep -F 'actionBox.appendChild(stopButton)' "$UI" >/dev/null

# These settings are fixed to 1 and must not be exposed as UI controls.
! grep -F 'Allow insecure TLS' "$UI" >/dev/null
! grep -F 'Auto Start' "$UI" >/dev/null
! grep -F 'allowInsecure' "$UI" >/dev/null
! grep -F 'var auto =' "$UI" >/dev/null

grep -F '"start"' "$RPC" >/dev/null
grep -F '"stop"' "$RPC" >/dev/null
grep -F 'SINGBOX_AUTO_START=1' "$RPC" >/dev/null
grep -F 'SINGBOX_ALLOW_INSECURE=1' "$RPC" >/dev/null
grep -F 'REDACTED-URL' "$RPC" >/dev/null
grep -F '"start"' "$ACL" >/dev/null
grep -F '"stop"' "$ACL" >/dev/null
grep -F 'luci.cowboy_bebop' "$RPC" >/dev/null
grep -F 'luci.cowboy_bebop' "$ACL" >/dev/null

printf '%s\n' 'LuCI UI contract tests: PASS'
