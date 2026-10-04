# OpenWrt

Current development target: OpenWrt 25.12.x x86_64.

The development VM uses the OpenWrt feed's sing-box package. The manager must
not overwrite or co-enable the feed package's own integration.

Project-specific paths:

- UCI: /etc/config/singbox
- config: /etc/singbox/
- init: /etc/init.d/singbox

The exact sing-box configuration syntax is pinned to the installed version.
